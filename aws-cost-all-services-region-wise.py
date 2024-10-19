import boto3
import datetime
import pandas as pd
import argparse

#Email: bhas@softwareag.com
#Creation Date: 20th Sept 2023


#${{ secrets.PROD_AWS_ACCESS_KEY_ID }} ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }}  ${{ github.event.inputs.region  }} 

#python3 aws-cost-all-services-region-wise.py --aws_user ${{ secrets.PROD_AWS_ACCESS_KEY_ID }} --aws_pass ${{ secrets.PROD_AWS_SECRET_ACCESS_KEY }} --aws_region ${{ github.event.inputs.region  }} 

# Create an argument parser to accept command-line arguments
parser = argparse.ArgumentParser(description="AWS RDS Instance Management")
parser.add_argument('--aws_user', required=True, help='AWS access key ID')
parser.add_argument('--aws_pass', required=True, help='AWS secret access key')
parser.add_argument('--aws_region', required=True, help='AWS secret access key')

args = parser.parse_args()

aws_user = args.aws_user
aws_pass = args.aws_pass

target_region = args.aws_region


# Initialize the Cost Explorer client

session = boto3.Session(
    aws_access_key_id=aws_user,
    aws_secret_access_key=aws_pass

)



ce_client = session.client('ce')
#ce_client = boto3.client('ce', aws_access_key_id=aws_access_key_id, aws_secret_access_key=aws_secret_access_key, region_name='us-east-1')

# Define the time period for the cost data (e.g., one month)
start_date = (datetime.datetime.now() - datetime.timedelta(days=30)).strftime('%Y-%m-%d')
end_date = datetime.datetime.now().strftime('%Y-%m-%d')

# Define the granularity of the data (e.g., DAILY, MONTHLY)
granularity = 'MONTHLY'


# Query cost and usage data for all services grouped by region and service
result = ce_client.get_cost_and_usage(
    TimePeriod={'Start': start_date, 'End': end_date},
    Granularity=granularity,
    Metrics=['UnblendedCost'],
    GroupBy=[{'Type': 'DIMENSION', 'Key': 'REGION'}, {'Type': 'DIMENSION', 'Key': 'SERVICE'}]
)

# Create a dictionary to store aggregated costs by region and service
costs = {}



aggregated_results = []

# Parse and aggregate the results
for group in result['ResultsByTime']:
    for item in group['Groups']:
        region_name = item['Keys'][0]
        service_name = item['Keys'][1]
        cost = float(item['Metrics']['UnblendedCost']['Amount'])

        # Aggregate costs for the same service within a region
        if region_name in costs:
            if service_name in costs[region_name]:
                costs[region_name][service_name] += cost
            else:
                costs[region_name][service_name] = cost
        else:
            costs[region_name] = {service_name: cost}

for region_name, service_costs in costs.items():
    for service_name, cost in service_costs.items():
      if region_name == target_region:
         aggregated_results.append({'Service': service_name, 'Region': region_name, 'Cost': cost})





# Create a DataFrame from the aggregated results
df = pd.DataFrame(aggregated_results)

# Print the DataFrame in tabular format
print(df.to_string(index=False))

# ...
