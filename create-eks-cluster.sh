#!/bin/bash
# Script to create a new EKS cluster
# Usage: ./create-eks-cluster.sh <cluster-name> [region] [node-type] [node-count]

set -e

CLUSTER_NAME="${1:-psimkins-test}"
AWS_REGION="${2:-us-east-1}"
NODE_TYPE="${3:-t3.medium}"
NODE_COUNT="${4:-2}"

echo "Creating EKS cluster: $CLUSTER_NAME in region: $AWS_REGION"
echo "Node type: $NODE_TYPE, Node count: $NODE_COUNT"
echo ""

# Check if eksctl is installed
if ! command -v eksctl &> /dev/null; then
    echo "eksctl is not installed. Installing..."
    echo "Please install eksctl first:"
    echo "  For macOS: brew install eksctl"
    echo "  For Linux: https://github.com/weaveworks/eksctl#installation"
    echo ""
    echo "Or create the cluster manually using AWS Console or AWS CLI"
    exit 1
fi

# Check if cluster already exists
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo "Cluster $CLUSTER_NAME already exists!"
    exit 1
fi

echo "Creating cluster with eksctl..."
eksctl create cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --node-type "$NODE_TYPE" \
    --nodes "$NODE_COUNT" \
    --nodes-min 1 \
    --nodes-max 3 \
    --managed \
    --with-oidc \
    --full-ecr-access \
    --version 1.29

echo ""
echo "✓ Cluster created successfully!"
echo ""
echo "Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

echo ""
echo "Next steps:"
echo "1. Set up IRSA for OpenTelemetry Collector:"
echo "   ./setup-eks-deployment.sh $CLUSTER_NAME $AWS_REGION"
echo ""
echo "2. Create the secret in AWS Secrets Manager:"
echo "   ./setup-aws-secrets.sh istio/otel-collector/elastic $AWS_REGION"
echo ""
echo "3. Deploy the resources:"
echo "   kubectl apply -f otel-rbac.yaml"
echo "   kubectl apply -f otel-collector-config.yaml"
echo "   kubectl apply -f otel-collector.yaml"

