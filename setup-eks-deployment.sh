#!/bin/bash
# Script to set up and deploy OpenTelemetry Collector to EKS with IRSA
# Usage: ./setup-eks-deployment.sh <cluster-name> <region> [account-id]

set -e

CLUSTER_NAME="${1}"
AWS_REGION="${2:-us-east-1}"
ACCOUNT_ID="${3}"

if [ -z "$CLUSTER_NAME" ]; then
    echo "Available EKS clusters:"
    aws eks list-clusters --region "$AWS_REGION" --output json | jq -r '.clusters[]'
    echo ""
    echo "Usage: $0 <cluster-name> [region] [account-id]"
    exit 1
fi

echo "Setting up deployment to EKS cluster: $CLUSTER_NAME in region: $AWS_REGION"

# Get account ID if not provided
if [ -z "$ACCOUNT_ID" ]; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "Detected AWS Account ID: $ACCOUNT_ID"
fi

# Update kubeconfig
echo "Updating kubeconfig for cluster $CLUSTER_NAME..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

# Get OIDC issuer URL
echo "Getting OIDC issuer URL..."
OIDC_ISSUER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')
echo "OIDC Issuer: $OIDC_ISSUER"

if [ -z "$OIDC_ISSUER" ] || [ "$OIDC_ISSUER" == "None" ]; then
    echo "Error: Could not get OIDC issuer. The cluster may not have an OIDC provider."
    echo "You may need to associate an OIDC provider first:"
    echo "  eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $AWS_REGION --approve"
    exit 1
fi

# Create IAM policy if it doesn't exist
POLICY_NAME="OtelCollectorSecretsPolicy"
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "Checking if IAM policy exists..."
if ! aws iam get-policy --policy-arn "$POLICY_ARN" &>/dev/null; then
    echo "Creating IAM policy..."
    aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document file://otel-iam-policy.json \
        --description "Policy for OpenTelemetry Collector to access AWS Secrets Manager"
    echo "Policy created: $POLICY_ARN"
else
    echo "Policy already exists: $POLICY_ARN"
fi

# Create trust policy
TRUST_POLICY_FILE=$(mktemp)
cat > "$TRUST_POLICY_FILE" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_ISSUER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_ISSUER}:sub": "system:serviceaccount:default:otel-collector",
          "${OIDC_ISSUER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Create IAM role
ROLE_NAME="otel-collector-secrets-role"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

echo "Checking if IAM role exists..."
if ! aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    echo "Creating IAM role..."
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document "file://${TRUST_POLICY_FILE}"
    echo "Role created: $ROLE_ARN"
else
    echo "Updating trust policy for existing role..."
    aws iam update-assume-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-document "file://${TRUST_POLICY_FILE}"
    echo "Role updated: $ROLE_ARN"
fi

# Attach policy to role
echo "Attaching policy to role..."
aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$POLICY_ARN" || echo "Policy may already be attached"

# Update service account with role ARN
echo "Updating service account with IAM role ARN..."
kubectl annotate serviceaccount otel-collector \
    -n default \
    eks.amazonaws.com/role-arn="$ROLE_ARN" \
    --overwrite

echo ""
echo "✓ IRSA setup complete!"
echo ""
echo "Role ARN: $ROLE_ARN"
echo "Policy ARN: $POLICY_ARN"
echo ""
echo "Next steps:"
echo "1. Ensure the secret exists in AWS Secrets Manager:"
echo "   ./setup-aws-secrets.sh istio/otel-collector/elastic $AWS_REGION"
echo ""
echo "2. Deploy the resources:"
echo "   kubectl apply -f otel-rbac.yaml"
echo "   kubectl apply -f otel-collector-config.yaml"
echo "   kubectl apply -f otel-collector.yaml"
echo ""
echo "3. Check pod status:"
echo "   kubectl get pods -l app=otel-collector"

# Cleanup
rm -f "$TRUST_POLICY_FILE"

