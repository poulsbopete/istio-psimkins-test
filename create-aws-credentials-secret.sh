#!/bin/bash
# Script to create Kubernetes secret with AWS credentials
# Usage: ./create-aws-credentials-secret.sh

set -e

echo "This script will create a Kubernetes secret with AWS credentials."
echo "WARNING: This stores credentials in plain text in Kubernetes. Use with caution!"
echo ""
read -p "Enter AWS Access Key ID: " AWS_ACCESS_KEY_ID
read -sp "Enter AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo ""
read -p "Enter AWS Session Token (optional, press Enter to skip): " AWS_SESSION_TOKEN

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Error: Access Key ID and Secret Access Key are required"
    exit 1
fi

# Create secret
kubectl create secret generic aws-credentials \
  --from-literal=aws-access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=aws-secret-access-key="$AWS_SECRET_ACCESS_KEY" \
  ${AWS_SESSION_TOKEN:+--from-literal=aws-session-token="$AWS_SESSION_TOKEN"} \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Secret 'aws-credentials' created/updated successfully!"
echo ""
echo "Note: For production, consider using:"
echo "  - IAM instance profiles (if running on EC2)"
echo "  - IRSA (if using EKS)"
echo "  - AWS Secrets Store CSI Driver"

