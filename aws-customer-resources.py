import boto3

from tabulate import tabulate
from collections import defaultdict

import argparse

#Email: bhas@softwareag.com
#Creation Date: 27th March 2024


#${{ secrets.PROD_AWS_ACCESS_KEY_ID }} ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }}  ${{ github.event.inputs.region  }} 

#python3 script.py --aws_user ${{ secrets.PROD_AWS_ACCESS_KEY_ID }} --aws_pass ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }} --aws_region ${{ github.event.inputs.region  }} 

# Create an argument parser to accept command-line arguments
parser = argparse.ArgumentParser(description="AWS Resource Management")
parser.add_argument('--aws_user', required=True, help='AWS access key ID')
parser.add_argument('--aws_pass', required=True, help='AWS secret access key')
parser.add_argument('--aws_region', required=True, help='AWS secret access key')
parser.add_argument('--tag_name', required=True, help='AWS secret access key')
parser.add_argument('--tag_value', required=True, help='AWS secret access key')
parser.add_argument('--start_date', required=True, help='AWS secret access key')
parser.add_argument('--end_date', required=True, help='AWS secret access key')

args = parser.parse_args()

aws_user = args.aws_user
aws_pass = args.aws_pass
target_region = args.aws_region
tag_key = args.tag_name
tag_value = args.tag_value
start_date = args.start_date
end_date = args.end_date

session = boto3.Session(
    aws_access_key_id=aws_user,
    aws_secret_access_key=aws_pass,
    region_name=target_region

)


def get_cost_for_tagged_resources(tag_key, tag_value, start_date, end_date,target_region):
    ce_client = session.client('ce')

    granularity = 'MONTHLY'
    # Query cost and usage data for resources with the specified tag
    result = ce_client.get_cost_and_usage(
        TimePeriod={'Start': start_date, 'End': end_date},
        Granularity=granularity,
        Metrics=['UnblendedCost'],
        GroupBy=[{'Type': 'DIMENSION', 'Key': 'REGION'}, {'Type': 'DIMENSION', 'Key': 'SERVICE'}],
        Filter={
            'Tags': {
                'Key': tag_key,
                'Values': [tag_value]
            }
        }
    )

    # Create a dictionary to store aggregated costs by region and service
    costs = defaultdict(lambda: defaultdict(float))
    total_cost = 0.0
    # Parse and aggregate the results
    for group in result['ResultsByTime']:
        for item in group['Groups']:
            region_name = item['Keys'][0]
            service_name = item['Keys'][1]
            cost = float(item['Metrics']['UnblendedCost']['Amount'])

            # Aggregate costs for the same service within a region
            costs[region_name][service_name] += cost




    aggregated_results = []
    total_cost = 0.0

    # Iterate over costs dictionary and accumulate results
    for region_name, service_costs in costs.items():
        if region_name == target_region:
            for service_name, cost in service_costs.items():
                total_cost += cost
                aggregated_results.append({'Service': service_name, 'Region': region_name, 'Cost': cost})

    # Print the aggregated results using tabulate

    print(f"\nAggregated Costs for Tagged Resources: {start_date} to {end_date} for TAG {tag_key}={tag_value} ")

    print(tabulate(aggregated_results, headers="keys", tablefmt="grid"))

    # Print total cost for the specified period and tag
    print(f"\nTotal Cost for period {start_date} to {end_date} for TAG {tag_key}={tag_value} : ${total_cost:.2f}")



def get_resources_with_tag(tag_key, tag_value):
    client = session.client('resourcegroupstaggingapi')
    paginator = client.get_paginator('get_resources')

    resources = []
    for page in paginator.paginate(TagFilters=[{'Key': tag_key, 'Values': [tag_value]}]):
        for resource in page['ResourceTagMappingList']:
            resources.append(resource['ResourceARN'])

    return resources

def main():

    print(f"Fetching resources with tag {tag_key}={tag_value}...")
    resources = get_resources_with_tag(tag_key, tag_value)

    if not resources:
        print(f"No resources found with the tag {tag_key}={tag_value}.")
    else:
        print(f"Resources found with the tag {tag_key}={tag_value}:")

        # Create a dictionary to count unique resource types
        resource_counts = defaultdict(int)
        for resource in resources:
            service, resource_type = extract_service_and_resource_type(resource)
            resource_counts[(service, resource_type)] += 1

        # Prepare detailed resource table
        detailed_resource_table = [[resource] for resource in resources]
        # Prepare summary table
        summary_table = [[f"{service}/{rtype}", count] for (service, rtype), count in resource_counts.items()]

        # Print summary table
        print(f"\nSummary of resource counts by type for TAG {tag_key}={tag_value}")
        print(tabulate(summary_table, headers=["Service/Resource Type", "Count"], tablefmt="grid"))

        # Call the function to retrieve and display costs
        get_cost_for_tagged_resources(tag_key, tag_value, start_date, end_date,target_region)   

        # Print detailed resource table
        print(f"\nDetailed resource table for TAG {tag_key}={tag_value}")
        print(tabulate(detailed_resource_table, headers=["Resource ARN"], tablefmt="grid"))




def extract_service_and_resource_type(resource_arn):
    parts = resource_arn.split(':')
    if len(parts) > 5:
        service = parts[2]
        resource_type = parts[5].split('/')[0] if '/' in parts[5] else parts[5]
        return service, resource_type
    return "Unknown", "Unknown"

if __name__ == '__main__':
    main()
