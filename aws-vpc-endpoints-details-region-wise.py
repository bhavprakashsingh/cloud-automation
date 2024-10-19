import boto3
from tabulate import tabulate
import argparse

#Email: bhas@softwareag.com
#Creation Date: 27th March 2024


#${{ secrets.PROD_AWS_ACCESS_KEY_ID }} ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }}  ${{ github.event.inputs.region  }} 

#python3 script.py --aws_user ${{ secrets.PROD_AWS_ACCESS_KEY_ID }} --aws_pass ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }} --aws_region ${{ github.event.inputs.region  }} 

# Create an argument parser to accept command-line arguments
parser = argparse.ArgumentParser(description="AWS VPC Endpoint Management")
parser.add_argument('--aws_user', required=True, help='AWS access key ID')
parser.add_argument('--aws_pass', required=True, help='AWS secret access key')
parser.add_argument('--aws_region', required=True, help='AWS secret access key')

args = parser.parse_args()

aws_user = args.aws_user
aws_pass = args.aws_pass

target_region = args.aws_region

session = boto3.Session(
    aws_access_key_id=aws_user,
    aws_secret_access_key=aws_pass,
    region_name=target_region

)


def get_vpc_endpoint_details():
    # Initialize the Boto3 client for EC2
    ec2_client = session.client('ec2')

    # Retrieve all VPC endpoints
    response = ec2_client.describe_vpc_endpoints()

    # Extract relevant details and format into a table
    endpoint_details = []
    for endpoint in response['VpcEndpoints']:
        endpoint_id = endpoint['VpcEndpointId']
        service_name = endpoint['ServiceName']
        vpc_id = endpoint['VpcId']
        availability_zones = ', '.join(endpoint.get('AvailabilityZones', []))
        private_dns_enabled = endpoint['PrivateDnsEnabled']
        security_group_ids = ', '.join(group['GroupId'] for group in endpoint['Groups'])

        # Get tags associated with the VPC endpoint
        tags = ec2_client.describe_tags(
            Filters=[
                {
                    'Name': 'resource-id',
                    'Values': [endpoint_id],
                },
            ]
        )

        # Extract the name tag
        name_tag = next((tag['Value'] for tag in tags['Tags'] if tag['Key'] == 'Name'), None)

        # Extract the customer name tag
        customer_name_tag = next((tag['Value'] for tag in tags['Tags'] if tag['Key'] == 'Customer'), None)

        endpoint_details.append(
            [customer_name_tag, name_tag, endpoint_id, service_name, vpc_id, private_dns_enabled])

    # Print the details in tabular form
    print(tabulate(endpoint_details,
                   headers=['Customer Name', 'Endpoint Name', 'Endpoint ID', 'VPC Service Name', 'VPC ID',
                            'Private DNS Enabled',
                            ]))


if __name__ == "__main__":
    get_vpc_endpoint_details()
