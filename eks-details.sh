#!/bin/bash

# Get a list of EKS clusters
clusters=$(aws eks list-clusters --region us-west-2 --query 'clusters' --output json)

# Iterate over each cluster and get information about its node groups
for cluster in $(echo "${clusters}" | jq -r '.[]'); do
    cluster_name=$cluster

    # Get a list of node groups for the current cluster
    nodegroups=$(aws eks list-nodegroups --cluster-name "${cluster_name}" --region us-west-2 --query 'nodegroups' --output json)

    # Iterate over each node group and print the desired information
    for nodegroup in $(echo "${nodegroups}" | jq -r '.[]'); do
        # Get instance details for the current node group
        instance_info=$(aws ec2 describe-instances --region us-west-2 --filters "Name=tag:eks:nodegroup-name,Values=${nodegroup}" --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,Placement.AvailabilityZone]' --output json)

        echo "Cluster: ${cluster_name}, Nodegroup: ${nodegroup}, InstanceInfo: ${instance_info}"
    done
done
