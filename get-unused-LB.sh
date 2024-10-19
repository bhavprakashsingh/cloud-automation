#!/bin/bash

echo "  "
echo "  "
echo "Get a list of all unused NLB AND ALB"
ALB_LIST=$(aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" --output text)

# Check if each ALB is in use or not
for ALB_ARN in $ALB_LIST
do
    # Get a list of all target groups for the ALB
    TARGET_GROUP_LIST=$(aws elbv2 describe-target-groups --load-balancer-arn $ALB_ARN --query "TargetGroups[].TargetGroupArn" --output text)

    # Iterate through each target group and check if any targets are registered
    IN_USE=false
    for TARGET_GROUP_ARN in $TARGET_GROUP_LIST
    do
        TARGET_HEALTH=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --query 'TargetHealthDescriptions[].TargetHealth.State' --output text)

        if [ ! -z "$TARGET_HEALTH" ]; then
            IN_USE=true
            break
        fi
    done

    if [ "$IN_USE" = false ]; then
        echo "LB $ALB_ARN is not in use"
    fi
done
