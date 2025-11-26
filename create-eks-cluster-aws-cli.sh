#!/bin/bash
# Script to create EKS cluster using AWS CLI (alternative to eksctl)
# Usage: ./create-eks-cluster-aws-cli.sh <cluster-name> [region]

set -e

CLUSTER_NAME="${1:-psimkins-test}"
AWS_REGION="${2:-us-east-1}"

echo "Creating EKS cluster: $CLUSTER_NAME in region: $AWS_REGION"
echo ""
echo "NOTE: This script creates a basic cluster. For production, consider using eksctl or AWS Console."
echo ""

# Check if cluster already exists
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo "Cluster $CLUSTER_NAME already exists!"
    exit 1
fi

# Get default VPC and subnets
echo "Getting VPC and subnet information..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region "$AWS_REGION" --query 'Vpcs[0].VpcId' --output text)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region "$AWS_REGION" --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    echo "Error: Could not find default VPC. Please create a VPC first or use eksctl."
    exit 1
fi

echo "Using VPC: $VPC_ID"
echo "Using Subnets: $SUBNET_IDS"
echo ""

# Create IAM role for EKS cluster
CLUSTER_ROLE_NAME="${CLUSTER_NAME}-cluster-role"
echo "Creating IAM role for EKS cluster..."

# Create trust policy for EKS service
cat > /tmp/eks-cluster-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role if it doesn't exist
if ! aws iam get-role --role-name "$CLUSTER_ROLE_NAME" &>/dev/null; then
    aws iam create-role \
        --role-name "$CLUSTER_ROLE_NAME" \
        --assume-role-policy-document file:///tmp/eks-cluster-trust-policy.json
    
    # Attach required policies
    aws iam attach-role-policy \
        --role-name "$CLUSTER_ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
fi

CLUSTER_ROLE_ARN=$(aws iam get-role --role-name "$CLUSTER_ROLE_NAME" --query 'Role.Arn' --output text)
echo "Cluster role ARN: $CLUSTER_ROLE_ARN"

# Create cluster
echo "Creating EKS cluster (this may take 10-15 minutes)..."
aws eks create-cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --role-arn "$CLUSTER_ROLE_ARN" \
    --resources-vpc-config subnetIds="$SUBNET_IDS" \
    --version "1.28"

echo ""
echo "Cluster creation initiated. Waiting for cluster to become active..."
aws eks wait cluster-active --name "$CLUSTER_NAME" --region "$AWS_REGION"

echo ""
echo "✓ Cluster created successfully!"
echo ""
echo "Next steps:"
echo "1. Associate OIDC provider (required for IRSA):"
echo "   eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $AWS_REGION --approve"
echo "   OR use AWS CLI (see README-AWS-SECRETS.md)"
echo ""
echo "2. Set up IRSA for OpenTelemetry Collector:"
echo "   ./setup-eks-deployment.sh $CLUSTER_NAME $AWS_REGION"
echo ""
echo "3. Create the secret in AWS Secrets Manager:"
echo "   ./setup-aws-secrets.sh istio/otel-collector/elastic $AWS_REGION"
echo ""
echo "4. Deploy the resources:"
echo "   kubectl apply -f otel-rbac.yaml"
echo "   kubectl apply -f otel-collector-config.yaml"
echo "   kubectl apply -f otel-collector.yaml"

# Cleanup
rm -f /tmp/eks-cluster-trust-policy.json

