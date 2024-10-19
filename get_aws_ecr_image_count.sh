#!/bin/bash

#Author: Mahesh Singh
#Email: mahsi@softwareag.com
#Creation Date: 30th May 2023
#Example to run script, 
#./script_name us-west-2


region=$1
total_image_count=0

# Get a list of all repository names
repositories=$(aws ecr describe-repositories --query "repositories[].[repositoryName]" --output text --no-cli-pager --region $region )


# Loop through each repository and get the image count
for repository in $repositories; do
    image_count=$(aws ecr list-images --repository-name $repository --region $region | jq '.imageIds | unique_by(.imageDigest) | length')
    echo "Repository: $repository, Image Count: $image_count"
    total_image_count=$((total_image_count + image_count))  
done

echo "Total Image Count: $total_image_count"
