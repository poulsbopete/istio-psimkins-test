#!/bin/bash
# Quick script to check EKS cluster status
CLUSTER_NAME="${1:-psimkins-test}"
AWS_REGION="${2:-us-east-1}"

echo "Checking status of cluster: $CLUSTER_NAME"
aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.{Status:status,Version:version,Endpoint:endpoint,CreatedAt:createdAt}' --output table 2>&1

