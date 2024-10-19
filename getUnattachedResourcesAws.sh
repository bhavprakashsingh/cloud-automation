#!/bin/bash


#Author: Bhav
#Email: bhas@softwareag.com
#Creation Date: 17th Feb 2023
#Current date
date=$(date "+%Y-%m-%d-%H-%M")
#log path
#logpath="/home/centos/volumes_cleanup/"
#Log stdout & stderr to a file and no output to terminal even running in debug mode.
#exec > $logpath/volume-delete-"$date".log 2>&1
#tee $logpath/volume-delete-"$date".log 2>&1
#curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

aws --version
if [ $? -eq 0 ] ;
then
echo "AWS Cli is already Installed"
else
echo "AWS Cli is being Installed"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
fi



echo "Get Unattched Resources in AWS Unused Elastic IPs Unused Volumes Unused Snapshots Unused Network Interfaces and Unused Security Groups"

# Find all unattached Elastic IPs

unused_ips=$(aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].{Name: Tags[?Key==`Name`].Value | [0], IP: PublicIp}' --output text |wc -l)

echo -e "Unused Elastic IPs (Count: $unused_ips):"

echo -e "Unused Elastic IPs Details :"

aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].{Name: Tags[?Key==`Name`].Value | [0], IP: PublicIp}' --output text --output table


echo ""
echo ""
echo ""

# Find all unattached volumes
unused_volumes=$(aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[*].{VolumeId:VolumeId,AvailabilityZone:AvailabilityZone}' --output text|wc -l)

echo -e "Unused Volumes (Count: $unused_volumes):"

echo -e "Unused Volumes Details ):"

aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[*].[VolumeId, AvailabilityZone, Size, VolumeType, Tags[?Key==`Name`].Value|[0]]' --output table


echo ""
echo ""
echo ""
# Find all unattached snapshots
unused_snapshots=$(aws ec2 describe-snapshots   --owner-ids self --filters "Name=status,Values=completed" --query "Snapshots[?StartTime<='$(date --date='-60 days' +%Y-%m-%dT%H:%M:%S.%NZ)'].{SnapshotId:SnapshotId, VolumeId:VolumeId, StartTime:StartTime}" --output text|wc -l)

echo -e "60 days older Snapshots (Count: $unused_snapshots)"

echo -e "60 days older Snapshots Details:"

aws ec2 describe-snapshots   --owner-ids self --filters "Name=status,Values=completed" --query "Snapshots[?StartTime<='$(date --date='-60 days' +%Y-%m-%dT%H:%M:%S.%NZ)'].{SnapshotId:SnapshotId, VolumeId:VolumeId, StartTime:StartTime , Name:Tags[?Key=='Name'].Value}"  --output table

echo ""
echo ""
echo ""

# Find all unattached network interfaces
unused_network_interfaces=$(aws ec2 describe-network-interfaces --filters Name=status,Values=available --query 'NetworkInterfaces[*].{NetworkInterfaceId:NetworkInterfaceId,SubnetId:SubnetId,AvailabilityZone:AvailabilityZone}' --output text|wc -l)

echo -e "Unused Network Interfaces (Count: $unused_network_interfaces):"

echo -e "Unused Network Interfaces Details:"

aws ec2 describe-network-interfaces --filters Name=status,Values=available --query 'NetworkInterfaces[*].{NetworkInterfaceId:NetworkInterfaceId,SubnetId:SubnetId,AvailabilityZone:AvailabilityZone}' --output table

echo ""
echo ""
echo ""

# Find all unattached security groups
unused_security_groups=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=* --query 'SecurityGroups[*].{GroupName:GroupName,GroupId:GroupId}' --output text | awk '!/launch-wizard/ && !/sg-/ {print $0}'|wc -l)

#echo -e "Unused Security Groups (Count: $unused_security_groups):"

#echo -e "Unused Security Groups Details:"

aws ec2 describe-security-groups --filters Name=vpc-id,Values=* --query 'SecurityGroups[*].{GroupName:GroupName,GroupId:GroupId}' --output text | awk '!/launch-wizard/ && !/sg-/ {print $0}'



# Find all 30 days  older Manual  created db snsapshot 

var=$(date -d "$x -30days" +%Y-%m-%d)

snapshots=$(aws rds describe-db-snapshots   --snapshot-type manual --query "DBSnapshots[?SnapshotCreateTime<='$var'].DBSnapshotIdentifier" --output text|wc -w)

echo -e " 30 days  older Manually  created db snsapshot (Count: $snapshots):"

echo -e "30 days  older Manually  created db snsapshot Details:"
aws rds describe-db-snapshots   --snapshot-type manual --query "DBSnapshots[?SnapshotCreateTime<='$var'].DBSnapshotIdentifier" --output table
# Find all BUCKET has not been used in the last 365 days


echo "Find all BUCKETs that have not been used in the last 365 days and those without lifecycle policies"
count=0
count_no_lifecycle=0
while read BUCKET; do
  MODIFIED=$(aws s3 ls s3://$BUCKET | sort | tail -n 1 | awk '{print $1}')
  if [[ -n "$MODIFIED" && $MODIFIED =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
    if [[ $(date -d "$MODIFIED" +%s) -le $(date -d '365 days ago' +%s) ]]; then
      echo "S3 Bucket : $BUCKET has not been used in the last 365 days"
      ((count++))
    fi
  fi
  # Check if lifecycle configuration exists for the bucket
  lifecycle=$(aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET" 2>&1)
  
  if echo "$lifecycle" | grep -q 'NoSuchLifecycleConfiguration'; then
    echo "S3 Bucket: $BUCKET does not have a lifecycle policy"
    ((count_no_lifecycle++))
  fi  
done < <(aws s3api list-buckets | jq -r '.Buckets[].Name')


# print the counts
echo -e "Unused Elastic IPs (Count: $unused_ips):"
echo -e "Unused Volumes (Count: $unused_volumes):"
echo -e "60 days older volume Snapshots (Count: $unused_snapshots)"
echo -e "Unused Network Interfaces (Count: $unused_network_interfaces):"
#echo -e "Unused Security Groups (Count: $unused_security_groups):"
echo -e "30 days older Manually  created db snsapshot (Count: $snapshots):"
echo -e "Total S3 BUCKET has not been used in the last 365 days (Count: $count):"
echo -e "Total S3 buckets without lifecycle policies (Count: $count_no_lifecycle)"
