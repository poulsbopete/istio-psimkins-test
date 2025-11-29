# AWS Secrets Manager Integration for OpenTelemetry Collector

This setup allows you to store sensitive configuration (Elastic endpoint and API key) in AWS Secrets Manager instead of hardcoding them in your Git repository.

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Kubernetes cluster (EKS recommended for IRSA support)
3. IAM permissions to create secrets and IAM roles

## Setup Instructions

### 1. Create the Secret in AWS Secrets Manager

Run the setup script to create the secret:

```bash
chmod +x setup-aws-secrets.sh
./setup-aws-secrets.sh istio/otel-collector/elastic us-east-1
```

Or manually create the secret:

```bash
aws secretsmanager create-secret \
  --name istio/otel-collector/elastic \
  --description "OpenTelemetry Collector Elastic endpoint and API key" \
  --secret-string '{"endpoint":"https://your-endpoint.ingest.us-east-1.aws.elastic.cloud:443","apiKey":"your-api-key-here"}' \
  --region us-east-1
```

### 2. Create IAM Role for Service Account (EKS with IRSA)

If you're using Amazon EKS, create an IAM role that can be assumed by the service account:

#### a. Create IAM Policy

```bash
aws iam create-policy \
  --policy-name OtelCollectorSecretsPolicy \
  --policy-document file://otel-iam-policy.json
```

Note the policy ARN from the output.

#### b. Create IAM Role

```bash
# Get your cluster OIDC issuer URL
OIDC_ISSUER=$(aws eks describe-cluster --name YOUR_CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')

# Create trust policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/${OIDC_ISSUER}"
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

# Create the role
aws iam create-role \
  --role-name otel-collector-secrets-role \
  --assume-role-policy-document file://trust-policy.json

# Attach the policy
aws iam attach-role-policy \
  --role-name otel-collector-secrets-role \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/OtelCollectorSecretsPolicy
```

#### c. Update Service Account

Update `otel-rbac.yaml` with the IAM role ARN:

```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::YOUR_ACCOUNT_ID:role/otel-collector-secrets-role
```

### 3. For Non-EKS Clusters

If you're not using EKS, you'll need to provide AWS credentials via one of these methods:

- **Option A**: Mount AWS credentials as a secret
- **Option B**: Use AWS IAM instance profile (if running on EC2)
- **Option C**: Use kube2iam or similar tool

Example for Option A (not recommended for production):

```bash
kubectl create secret generic aws-credentials \
  --from-literal=aws-access-key-id=YOUR_ACCESS_KEY \
  --from-literal=aws-secret-access-key=YOUR_SECRET_KEY \
  --namespace default
```

Then update `otel-collector.yaml` init container to mount this secret:

```yaml
env:
  - name: AWS_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef:
        name: aws-credentials
        key: aws-access-key-id
  - name: AWS_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: aws-credentials
        key: aws-secret-access-key
```

### 4. Deploy

Apply the updated manifests:

```bash
kubectl apply -f otel-rbac.yaml
kubectl apply -f otel-collector-config.yaml
kubectl apply -f otel-collector.yaml
```

### 5. Verify

Check that the init container successfully fetches secrets:

```bash
kubectl logs -l app=otel-collector -c fetch-secrets
```

Check that the main container has the environment variables:

```bash
kubectl exec -it $(kubectl get pod -l app=otel-collector -o jsonpath='{.items[0].metadata.name}') -- env | grep ELASTIC
```

## Configuration

You can customize the secret name and region by setting environment variables in the DaemonSet:

- `AWS_SECRET_NAME`: Name of the secret in AWS Secrets Manager (default: `istio/otel-collector/elastic`)
- `AWS_REGION`: AWS region where the secret is stored (default: `us-east-1`)

## Security Notes

1. **Never commit secrets to Git**: The configuration files now use environment variables, making them safe for public repositories.

2. **IAM Permissions**: The IAM role should have minimal permissions - only access to the specific secret needed.

3. **Secret Rotation**: Consider setting up automatic secret rotation in AWS Secrets Manager for the API key.

4. **Network Policies**: Ensure your pods can reach AWS Secrets Manager endpoints.

## Troubleshooting

### Init container fails to fetch secrets

1. Check IAM role permissions:
   ```bash
   aws iam get-role-policy --role-name otel-collector-secrets-role --policy-name OtelCollectorSecretsPolicy
   ```

2. Verify the secret exists:
   ```bash
   aws secretsmanager describe-secret --secret-id istio/otel-collector/elastic
   ```

3. Check init container logs:
   ```bash
   kubectl logs -l app=otel-collector -c fetch-secrets
   ```

### Collector can't read environment variables

1. Verify secrets are written to the volume:
   ```bash
   kubectl exec -it $(kubectl get pod -l app=otel-collector -o jsonpath='{.items[0].metadata.name}') -c fetch-secrets -- cat /secrets/ELASTIC_ENDPOINT
   ```

2. Check collector logs:
   ```bash
   kubectl logs -l app=otel-collector -c otel-collector
   ```

