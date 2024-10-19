# Author: Bhav
# Email: bhas@softwareag.com
# Creation Date: 7th May 2023
import boto3

access_key_id = ''
secret_access_key = ''
region_name = 'us-west-2'

session = boto3.Session(
    aws_access_key_id=access_key_id,
    aws_secret_access_key=secret_access_key,
    region_name=region_name
)

#Target Security Group id
GROUP_ID = 'sg-08e0c87f883f2f192'
#Source Security Group id
SOURCE_GROUP_ID = 'sg-07b8d50b554b01707'
PORTS = [7443, 9000, 9200, 5555]
DESCRIPTION = 'Allow access from source security group'

ec2 = session.client('ec2')

for port in PORTS:
    ec2.authorize_security_group_ingress(
        GroupId=GROUP_ID,
        IpPermissions=[
            {
                'IpProtocol': 'tcp',
                'FromPort': port,
                'ToPort': port,
                'UserIdGroupPairs': [
                    {
                        'GroupId': SOURCE_GROUP_ID,
                        'Description': DESCRIPTION
                    }
                ]
            }
        ]
    )
