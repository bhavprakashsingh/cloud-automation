#Author: Bhav
#Email: bhas@softwareag.com
#Creation Date: 30th March 2023
import boto3

# Replace the values below with your own RDS instance details

instance_identifiers = ['wmic-preprod-pre-lip-use1-svpc-rds-instance-2020-10-05-blue']

# Create an RDS client
session = boto3.Session(
    aws_access_key_id='',
    aws_secret_access_key='',
    region_name='us-east-1'

    
)

# Check if the RDS instance is running

rds_client = session.client('rds')

# Stop each RDS instance if it is currently running
for instance_identifier in instance_identifiers:
    response = rds_client.describe_db_instances(DBInstanceIdentifier=instance_identifier)
    status = response['DBInstances'][0]['DBInstanceStatus']
    print("The status of RDS instance " + instance_identifier + " is " + status)

    if status == 'available':
        print("Stopping RDS instance " + instance_identifier + "...")
        # rds_client.stop_db_instance(DBInstanceIdentifier=instance_identifier)
    else:
        print("RDS instance " + instance_identifier + " is not running, cannot stop it.")
