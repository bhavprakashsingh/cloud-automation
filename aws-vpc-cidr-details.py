import boto3
from tabulate import tabulate
import argparse

#Email: bhas@softwareag.com
#Creation Date: 27th March 2024


#${{ secrets.PROD_AWS_ACCESS_KEY_ID }} ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }}  ${{ github.event.inputs.region  }} 

#python3 script.py --aws_user ${{ secrets.PROD_AWS_ACCESS_KEY_ID }} --aws_pass ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }} --aws_region ${{ github.event.inputs.region  }} 

# Create an argument parser to accept command-line arguments
parser = argparse.ArgumentParser(description="AWS VPC  Management")
parser.add_argument('--aws_user', required=True, help='AWS access key ID')
parser.add_argument('--aws_pass', required=True, help='AWS secret access key')
parser.add_argument('--aws_region', required=True, help='AWS secret access key')

args = parser.parse_args()

aws_user = args.aws_user
aws_pass = args.aws_pass

target_region = args.aws_region

boto3 = boto3.Session(
    aws_access_key_id=aws_user,
    aws_secret_access_key=aws_pass,
    region_name=target_region

)


def get_vpc_and_subnet_details(region):
    # Initialize the Boto3 client for EC2 in the specified region
    ec2_client = boto3.client('ec2', region_name=region)

    # Retrieve all VPCs
    vpcs_response = ec2_client.describe_vpcs()
    vpcs = vpcs_response['Vpcs']

    # Initialize list to store VPC details
    vpc_details = []

    for vpc in vpcs:
        vpc_id = vpc['VpcId']
        cidr_block = vpc['CidrBlock']

        # Get tags associated with the VPC
        tags = vpc.get('Tags', [])
        name_tag = next((tag['Value'] for tag in tags if tag['Key'] == 'Name'), None)
        customer_name_tag = next((tag['Value'] for tag in tags if tag['Key'] == 'Customer'), None)

        # Retrieve all subnets for the current VPC
        # subnets_response = ec2_client.describe_subnets(
        #     Filters=[
        #         {
        #             'Name': 'vpc-id',
        #             'Values': [vpc_id],
        #         },
        #     ]
        # )
        # subnets = subnets_response['Subnets']
        #
        # for subnet in subnets:
        #     subnet_id = subnet['SubnetId']
        #     subnet_cidr = subnet['CidrBlock']
        #
        #     # Get tags associated with the subnet
        #     subnet_tags = subnet.get('Tags', [])
        #     subnet_name_tag = next((tag['Value'] for tag in subnet_tags if tag['Key'] == 'Name'), None)
        #     subnet_customer_name_tag = next((tag['Value'] for tag in subnet_tags if tag['Key'] == 'Customer'), None)

            # Append VPC and subnet details to the list
        vpc_details.append(
                [customer_name_tag, name_tag, vpc_id, cidr_block,region]
            )

    return vpc_details

def main():
    # List of regions to iterate over
    REGIONS = ["us-west-2", "eu-central-1", "ap-southeast-2", "eu-west-1"]

    # Initialize a list to store details from all regions
    all_vpc_details = []

    for region in REGIONS:
        vpc_details = get_vpc_and_subnet_details(region)
        all_vpc_details.extend(vpc_details)

    # Print the details in tabular form
    print(tabulate(all_vpc_details,
                   headers=['VPC Customer Name', 'VPC Name', 'VPC ID', 'CIDR ','Region']))

if __name__ == "__main__":
    main()
