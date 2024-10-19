import boto3
import sys
from datetime import datetime, timedelta
#Author: Bhav
#Email: bhas@softwareag.com
#Creation Date: 22th April 2023
# Define AWS region and service clients


arg1 = sys.argv[1]
arg2 = sys.argv[2]
arg3 = sys.argv[3]

session = boto3.Session(
    aws_access_key_id=arg1,
    aws_secret_access_key=arg2,
    region_name=arg3
)
#region = 'us-west-2' # Change this to your preferred region
ec2_client = session.client('ec2')
rds_client = session.client('rds')
elb_client = session.client('elbv2')
cloudwatch_client = session.client('cloudwatch')

# Define time range for checking underutilized resources
now = datetime.utcnow()
one_day_ago = now - timedelta(days=15)  # Change this to your preferred time range
#print(one_day_ago)


# Define function to get resource utilization metrics
def get_utilization_metrics(client, resource_type, resource_id):
    response = client.get_metric_statistics(
        Namespace='AWS/' + resource_type,
        MetricName='CPUUtilization',
        Dimensions=[
            {
                'Name': 'InstanceId' if resource_type == 'EC2' else 'DBInstanceIdentifier' if resource_type == 'RDS' else 'LoadBalancer',
                'Value': resource_id
            },
        ],
        StartTime=one_day_ago,
        EndTime=now,
        Period=3600,
        Statistics=[
            'Average'
        ]
    )
    return response['Datapoints']


# Define function to check if resource is underutilized
def is_underutilized(metrics):
    if not metrics:
#        print(f"Average CPU Utilization of below Resource for last 15 days : 0 or resource is stopped ")
        return True  # No metrics found, assume underutilized
    avg_utilization = sum([m['Average'] for m in metrics]) / len(metrics)
#    print(f"Average CPU Utilization of below Resource for last 15 days : {avg_utilization}")
    if avg_utilization < 5.0:
        return True  # Average utilization of below Resourceis less than 5%, assume underutilized
    return False

# Define variables to keep count of underutilized resources
ec2_count = 0
rds_count = 0
elb_count = 0
print("Underutilized Resources EC2  AnD RDS Where Resource's CPU Average Utilization is less than 5% for  last 15 days :")

#Check EC2 instances
ec2_instances = ec2_client.describe_instances()
print(" ")
print("Underutilized EC2 :")
for reservation in ec2_instances['Reservations']:
    #print(reservation)
    for instance in reservation['Instances']:
        metrics = get_utilization_metrics(cloudwatch_client, 'EC2', instance['InstanceId'])
        #print(metrics)
        if is_underutilized(metrics):
            print(f"EC2 instance {instance['InstanceId']} is underutilized")
            ec2_count += 1

# Check RDS instances
rds_instances = rds_client.describe_db_instances()
print(" ")
print("Underutilized RDS :")
for instance in rds_instances['DBInstances']:
    metrics = get_utilization_metrics(cloudwatch_client, 'RDS', instance['DBInstanceIdentifier'])
    if is_underutilized(metrics):
         print(f"RDS instance {instance['DBInstanceIdentifier']} is underutilized")
         rds_count += 1


print(" ")
print("Print the count of underutilized resources: ")
print(f"Underutilized EC2 instances count: {ec2_count}")
print(f"Underutilized RDS instances count: {rds_count}")
# print(f"Underutilized ELB instances count: {elb_count}")
