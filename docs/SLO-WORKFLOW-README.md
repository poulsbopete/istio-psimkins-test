# SLO Management Workflow - AWS Secrets Manager Integration

This workflow has been adapted from the original Vault-based template to use AWS Secrets Manager.

## AWS Secrets Manager Configuration

The workflow expects to retrieve Elastic Cloud credentials from AWS Secrets Manager secret:
- **Secret Name**: `istio/otel-collector/elastic`
- **Secret Format**: JSON with `endpoint` and `apiKey` fields
- **Region**: `us-east-1`

## Integration Options

Since One Workflow's capabilities for AWS integration may vary, here are three approaches:

### Option 1: AWS CLI Script Step (Recommended if supported)

If One Workflow supports script steps with AWS CLI:

```yaml
- name: get-elastic-secrets-from-aws
  type: script
  with:
    script: |
      #!/bin/bash
      SECRET=$(aws secretsmanager get-secret-value \
        --secret-id istio/otel-collector/elastic \
        --region us-east-1 \
        --query SecretString \
        --output text)
      
      # Parse JSON and extract values
      ENDPOINT=$(echo $SECRET | jq -r '.endpoint')
      API_KEY=$(echo $SECRET | jq -r '.apiKey')
      
      # Output as JSON for workflow to use
      echo "{\"endpoint\":\"$ENDPOINT\",\"apiKey\":\"$API_KEY\"}"
```

### Option 2: Workflow Variables/Secrets

If One Workflow supports environment variables or secrets:

1. Configure workflow secrets with:
   - `ELASTIC_ENDPOINT`: `https://a5630c65c43f4f299288c392af0c2f45.ingest.us-east-1.aws.elastic.cloud:443`
   - `ELASTIC_API_KEY`: `M2YwQXdab0JGRjA4aVVzRkhmWjQ6OFNheEFOM3FhM05vcEV6bGQ0RVFTQQ==`

2. Update workflow steps to use:
   ```yaml
   url: '{{ env.ELASTIC_ENDPOINT }}/api/observability/slos'
   Authorization: 'ApiKey {{ env.ELASTIC_API_KEY }}'
   ```

### Option 3: Lambda Function (Most Flexible)

Create an AWS Lambda function that retrieves the secret and expose it via API Gateway:

1. Lambda function retrieves secret from AWS Secrets Manager
2. API Gateway exposes it as a simple HTTP endpoint
3. Workflow calls the API Gateway endpoint

## Current Implementation

The current workflow file (`slo-management-workflow.yaml`) uses hardcoded values for testing. To make it production-ready:

1. **Replace hardcoded endpoint** in all HTTP steps:
   - Current: `https://a5630c65c43f4f299288c392af0c2f45.ingest.us-east-1.aws.elastic.cloud`
   - Should be: `{{ steps.get-elastic-secrets-from-aws.output.parsed.endpoint }}`

2. **Replace hardcoded API key** in all Authorization headers:
   - Current: `M2YwQXdab0JGRjA4aVVzRkhmWjQ6OFNheEFOM3FhM05vcEV6bGQ0RVFTQQ==`
   - Should be: `{{ steps.get-elastic-secrets-from-aws.output.parsed.apiKey }}`

## AWS IAM Permissions Required

If using AWS CLI or direct AWS API calls, the workflow execution role needs:

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

## Testing the Workflow

1. Ensure AWS credentials are configured in One Workflow
2. Verify the secret exists: `aws secretsmanager describe-secret --secret-id istio/otel-collector/elastic --region us-east-1`
3. Test the workflow manually first before enabling scheduled execution
4. Check workflow logs to verify secret retrieval is working

## Notes

- The workflow is idempotent - it checks for existing SLOs before creating new ones
- All SLOs are grouped by service.name or monitor.name for automatic instance management
- The workflow runs every 24 hours by default
- Manual triggers are also supported

