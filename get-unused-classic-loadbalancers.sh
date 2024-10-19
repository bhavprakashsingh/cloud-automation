#!/bin/bash

# Use the AWS CLI to describe all Classic Load Balancers in your account
load_balancer_output=$(aws elb describe-load-balancers)
 echo "LIST of Unused classic load balancers"
# Loop through each load balancer and check if it's in use
for load_balancer in $(echo $load_balancer_output | jq -r '.LoadBalancerDescriptions[].LoadBalancerName'); do
    # Use the AWS CLI to describe the instances associated with the load balancer
    instance_health_output=$(aws elb describe-instance-health --load-balancer-name $load_balancer)

    # Check if there are any registered instances

    if [[ $(echo $instance_health_output | jq '.InstanceStates | length') -eq 0 ]]; then
        echo "The load balancer $load_balancer is not  in use."
    fi
done
