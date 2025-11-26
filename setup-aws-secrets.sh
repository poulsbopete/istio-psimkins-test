#!/bin/bash
# Script to create AWS Secrets Manager secret for OpenTelemetry Collector configuration
# Usage: ./setup-aws-secrets.sh <secret-name> <aws-region>

set -e

SECRET_NAME="${1:-istio/otel-collector/elastic}"
AWS_REGION="${2:-us-east-1}"

echo "Creating AWS Secrets Manager secret: $SECRET_NAME in region: $AWS_REGION"

# Read the current values (you can also pass these as environment variables)
ELASTIC_ENDPOINT="${ELASTIC_ENDPOINT:-https://a5630c65c43f4f299288c392af0c2f45.ingest.us-east-1.aws.elastic.cloud:443}"
ELASTIC_API_KEY="${ELASTIC_API_KEY:-ZGtVU1pKb0JIN2dNc1pZZE9TRHg6OWwzczNyT1ZMbjR0bkIwY09SY2MwQQ==}"

# Create JSON secret value
SECRET_VALUE=$(cat <<EOF
{
  "endpoint": "$ELASTIC_ENDPOINT",
  "apiKey": "$ELASTIC_API_KEY"
}
EOF
)

# Check if secret already exists
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" &>/dev/null; then
    echo "Secret $SECRET_NAME already exists. Updating..."
    aws secretsmanager update-secret \
        --secret-id "$SECRET_NAME" \
        --secret-string "$SECRET_VALUE" \
        --region "$AWS_REGION"
    echo "Secret updated successfully!"
else
    echo "Creating new secret $SECRET_NAME..."
    aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "OpenTelemetry Collector Elastic endpoint and API key" \
        --secret-string "$SECRET_VALUE" \
        --region "$AWS_REGION"
    echo "Secret created successfully!"
fi

# Get the secret ARN
SECRET_ARN=$(aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" --query 'ARN' --output text)
echo ""
echo "Secret ARN: $SECRET_ARN"
echo ""
echo "Next steps:"
echo "1. Create an IAM role with permission to access this secret"
echo "2. Annotate the otel-collector service account with the IAM role ARN"
echo "3. Apply the updated Kubernetes manifests"

