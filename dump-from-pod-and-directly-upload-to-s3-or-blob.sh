#!/bin/bash

#Author: Bhav
#Email: bhas@softwareag.com
#Creation Date: 30th Sept 2023

#step to execute :
#The script will prompt you to enter the following information:


#set -x


# Get user input for namespace ,  pod name and cloud provide
read -p "Enter the namespace: " NAMESPACE
read -p "Enter the pod name: " POD_NAME
read -p "Enter cloud provide (e.g. aws, az) : " CLOUD_PROVIDER
read -p "Enter cloud region (e.g., us-west-2, eu-central-1 or ap-southeast-2) : " CLOUD_REGION 
read -p "Do you want to take a thread dump? (yes/no): " take_thread
read -p "Do you want to take a heap dump? (yes/no): "   take_heap
read -p "Do you want to take a Server logs? (yes/no): " take_server_logs
read -p "Enter the number of days logs you want : " NM_DAYS
read -p "Do you want to take a RIC Dump ? (yes/no): " take_ric_dump 


Logs_DATE=$(date -d "$NM_DAYS days ago" '+%Y-%m-%d')

#Azure SAS Token Expiry 48 hours
expiry=$(date -u -d '+48 hours' '+%Y-%m-%dT%H:%M:%SZ')

# Record the start time
start_time=$(date +%s)

# Display script start message
echo "Script started at $(date)"

# Execute pgrep command inside the pod to retrieve the Java PID
JAVA_PID=$(kubectl exec -n $NAMESPACE $POD_NAME -- pgrep java)

# Check if Java PID is found
if [ -z "$JAVA_PID" ]; then
  echo "Java process not found in the pod."
  exit 1
fi

echo "Java PID: $JAVA_PID"

# Function to take a thread dump :
take_thread_dump() {
   dump_num=$1
   dump_file="/tmp/$POD_NAME-$dump_num-$(date +"%Y-%m-%d-%H-%M-%S").txt"

   # Take a thread dump
   echo "Taking thread dump $dump_num..."
   kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "jstack $JAVA_PID > $dump_file"
   echo "Thread dump $dump_num saved as $dump_file"
}


# Take a single heap dump and delete the dump file
take_heap_dump() {
   dump_file="/tmp/heap-"$POD_NAME"-`date +"%Y-%m-%d-%H-%M-%S"`.hprof"

   # Take a heap dump
   echo "Taking heap dump..."
   kubectl exec -n $NAMESPACE $POD_NAME -- jmap -dump:format=b,file=$dump_file $JAVA_PID
   echo "Heap dump saved as $dump_file"


}

#Take n  days server logs
take_server_logs() {
   echo "Taking last $NM_DAYS days server logs"
   echo "/tmp/${POD_NAME}"
   kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "mkdir -p /tmp/${POD_NAME}/"
   #kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "find '/opt/softwareag/IntegrationServer/instances/default/logs/' -type f -name 'wrapper*' -newermt \$(date -d '3 days ago' '+%Y-%m-%d') -exec cp {} '/tmp/${POD_NAME}/' \;"
   kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "find '/opt/softwareag/IntegrationServer/instances/default/logs/' -type f -name 'wrapper*' -newermt $Logs_DATE -exec cp {} '/tmp/${POD_NAME}/' \;"
}

# Take a RIC  dump form UM pod

take_ric_dump() {

   dump_file="/tmp/heap-"$POD_NAME"-`date +"%Y-%m-%d-%H-%M-%S"`.hprof"

   # Take a RIC dump
   echo "Taking RIC dump..."
   kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "cd /opt/softwareag/UniversalMessaging/tools/runner; ./runUMTool.sh RealmInformationCollector -mode=live -instance=umserver -include=threaddump,psinfo -outputfile=/tmp/$POD_NAME-$dump_num-$(date +"%Y-%m-%d-%H-%M-%S").zip"


}

# Take three thread dumps
if [ "$take_thread" = "yes" ]; then
  for i in {1..3}; do
    take_thread_dump $i
    sleep 5
  done
else
  echo "No action performed."
fi

# Take a single heap dump
if [ "$take_heap" = "yes" ]; then
  take_heap_dump
else
  echo "No action performed."
fi

# Take a server logs
if [ "$take_server_logs" = "yes" ]; then
  take_server_logs
else
  echo "No action performed."
fi

if [ "$take_ric_dump" = "yes"]; then 
   take_ric_dump
else
  echo "No action performed."
fi 


function uploadDumps() {
  # Archive the copied files into a tar file
  kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c 'find /tmp -type f -name "*.tar.gz" -exec rm -f {} \;'
  archive_file="dumps-$POD_NAME-$(date +"%Y-%m-%d-%H-%M-%S")"
  echo "Creating archive $archive_file..."
  kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "tar -czvf /tmp/$archive_file.tar.gz /tmp/*$POD_NAME*"

  file_to_upload="$archive_file.tar.gz"
  echo "Archive created: $file_to_upload"
  
  echo $CLOUD_PROVIDER

  if [[ ${CLOUD_PROVIDER} == "aws" ]]; then
  
    echo "  "
	
	path=$(kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c 'echo s3://${LOGS_BKP_STORAGE_NAME}/${APP_NAME}/${LOGS_BKP_TENANT_ID}/${HOSTNAME}/')
	#echo $path
    kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "echo File: $file_to_upload is getting uploaded at: $path"
	
    kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "cd /tmp; aws s3 cp $file_to_upload $path"
    echo "Generating AWS S3 Presing url to download file"
    AWSS3_Presign=$(kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "aws s3 presign $path$file_to_upload --expires-in 172800 --region $CLOUD_REGION")
    echo "AWS S3 Presign URL: $AWSS3_Presign"

    
  else
    
    echo "  "
	  storage=$(kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c 'echo ${LOGS_BKP_STORAGE_NAME}')
	  path=$(kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c 'echo ${APP_NAME}/${LOGS_BKP_TENANT_ID}/${HOSTNAME}/')
	
    kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "echo File: $file_to_upload is getting uploaded at blob storage container : $storage  and path $path"
    kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "cd /tmp; az storage blob sync -c $storage -s /tmp  -d $path --delete-destination false --include-pattern *.tar.gz* |grep -i completed"
    account_name=$(kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c 'echo ${AZURE_STORAGE_ACCOUNT}')
    container_name=$(kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c 'echo ${LOGS_BKP_STORAGE_NAME}')
    echo "Generating sas token to download file"
    AZSAS=$(kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "az storage blob generate-sas --account-name ${account_name} --container-name ${container_name} --name $path$file_to_upload --permissions r --expiry $expiry --output tsv")
    echo "Constructing download url"
    download_url="https://$account_name.blob.core.windows.net/$container_name/$path$file_to_upload?$AZSAS"
    echo "Download URL: $download_url"
  fi


  # Delete the copied files from the local machine
  echo "Deleting files from pod..."
  kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c "rm -rf /tmp/*$POD_NAME*"
  kubectl exec -n $NAMESPACE $POD_NAME -- /bin/sh -c 'find /tmp -type f -name "*.tar.gz" -exec rm -f {} \;'

}

uploadDumps


# Record the end time
end_time=$(date +%s)

# Display script end message
echo "Script finished at $(date)"

# Calculate the total time in seconds
total_time=$((end_time - start_time))

# Convert the total time to a human-readable format (HH:MM:SS)
total_time_formatted=$(date -u -d @"$total_time" +'%H:%M:%S')

echo "Script took $total_time_formatted to run."
