#!/bin/bash

#Author: Mahesh Singh
#Email: mahsi@softwareag.com
#Creation Date: 08th June 2023
#Example to run script,
#./script_name {repository_name}

#Repository Name & pass date before which you need to delete the images.
REPO_NAME=$1
DATE="2022-12-31"

image_digests=$(aws ecr describe-images --repository-name $REPO_NAME --filter "tagStatus=UNTAGGED" --query "imageDetails[?imagePushedAt<\`$DATET00:00:00Z\`].imageDigest" --output text)

ecr_images=`echo $image_digests | tr ' ' '\n'`


for digest in $ecr_images; do
    echo $digest
    aws ecr batch-delete-image --repository-name $REPO_NAME --image-ids imageDigest=$digest
done
