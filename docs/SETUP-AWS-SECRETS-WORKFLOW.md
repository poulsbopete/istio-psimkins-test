# Setting Up AWS Secrets Manager for One Workflow

## Prerequisites

Before using this workflow, you need to configure AWS credentials in One Workflow to access AWS Secrets Manager.

## AWS Secrets Manager Secret

The workflow expects a secret named `istio/otel-collector/elastic` in AWS Secrets Manager (us-east-1) with the following JSON format:

```json
{
  "endpoint": "https://a5630c65c43f4f299288c392af0c2f45.ingest.us-east-1.aws.elastic.cloud:443",
  "apiKey": "M2YwQXdab0JGRjA4aVVzRkhmWjQ6OFNheEFOM3FhM05vcEV6bGQ0RVFTQQ=="
}
```

## Configuring AWS Credentials in One Workflow

### Option 1: AWS Access Keys (if supported)

1. Go to One Workflow settings
2. Find AWS credentials configuration
3. Enter:
   - **AWS Access Key ID**: Your AWS access key
   - **AWS Secret Access Key**: Your AWS secret key
   - **Region**: `us-east-1`

### Option 2: IAM Role (if One Workflow runs on AWS)

If One Workflow runs on AWS infrastructure (EC2, ECS, Lambda, etc.):
1. Attach an IAM role to the execution environment
2. The role needs permission to access Secrets Manager:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "secretsmanager:GetSecretValue",
           "secretsmanager:DescribeSecret"
         ],
         "Resource": "arn:aws:secretsmanager:us-east-1:461485115270:secret:istio/otel-collector/elastic-*"
       }
     ]
   }
   ```

### Option 3: AWS Signature V4 Signing

If One Workflow supports custom HTTP request signing:
- The workflow HTTP step to AWS Secrets Manager requires AWS Signature Version 4
- Configure AWS credentials in One Workflow's HTTP request settings
- Or use a pre-signed request if supported

## Testing the Configuration

1. Run the workflow manually
2. Check the `parse-aws-secrets-response` step output
3. Verify the status is 200 and SecretString contains the JSON with endpoint and apiKey
4. If it fails, check:
   - AWS credentials are configured correctly
   - The secret exists in AWS Secrets Manager
   - The IAM permissions are correct
   - The region is set to us-east-1

## Troubleshooting

### Error: "Access Denied" or 403
- Check IAM permissions for Secrets Manager
- Verify the secret ARN matches your account

### Error: "Secret not found" or 404
- Verify the secret name: `istio/otel-collector/elastic`
- Check the region: `us-east-1`
- Ensure the secret exists in your AWS account

### Error: "Invalid signature" or 401
- AWS Signature V4 signing is required
- Verify AWS credentials are configured in One Workflow
- Check if One Workflow supports AWS request signing

### JSON Parsing Issues
- Verify the SecretString is valid JSON
- Check the parse-aws-secrets-response step output
- Ensure the JSON has `endpoint` and `apiKey` fields

## Alternative: Use One Workflow Secrets

If AWS Secrets Manager integration is not available, you can:
1. Store the endpoint and API key as One Workflow secrets/variables
2. Update the workflow to reference those variables instead
3. This keeps credentials out of the workflow file but requires One Workflow's secret management

