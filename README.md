# Istio with OpenTelemetry Collector on EKS

This repository contains the configuration for deploying Istio service mesh with OpenTelemetry Collector on Amazon EKS, integrated with Elastic Cloud for observability.

## Overview

This setup provides:
- **Istio Service Mesh** for traffic management, security, and observability
- **OpenTelemetry Collector** for collecting traces, metrics, and logs
- **AWS Secrets Manager Integration** for secure credential management
- **Elastic Cloud Integration** for centralized observability

## Architecture

```
┌─────────────────┐
│   Applications   │
│  (Istio-enabled) │
└────────┬─────────┘
         │
         ▼
┌─────────────────┐
│  Istio Sidecars │
└────────┬─────────┘
         │
         ▼
┌─────────────────┐     ┌──────────────────┐
│  OTEL Collector │────▶│  Elastic Cloud   │
│   (DaemonSet)   │     │  (Observability)  │
└─────────────────┘     └──────────────────┘
         │
         ▼
┌─────────────────┐
│ AWS Secrets Mgr │
│  (Credentials)  │
└─────────────────┘
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- `kubectl` installed and configured
- `eksctl` installed (for EKS cluster creation)
- Access to an EKS cluster or ability to create one
- Elastic Cloud account with API key

## Quick Start

### 1. Create EKS Cluster

```bash
./create-eks-cluster.sh psimkins-test us-east-1
```

This will create an EKS cluster with:
- Kubernetes version 1.29
- Managed node groups (t3.medium instances)
- OIDC provider enabled (for IRSA)
- Full ECR access

**Note:** Cluster creation takes 10-15 minutes.

### 2. Set Up AWS Secrets Manager Integration

#### Create the Secret in AWS Secrets Manager

```bash
./setup-aws-secrets.sh istio/otel-collector/elastic us-east-1
```

Or manually:

```bash
aws secretsmanager create-secret \
  --name istio/otel-collector/elastic \
  --description "OpenTelemetry Collector Elastic endpoint and API key" \
  --secret-string '{"endpoint":"https://your-endpoint.ingest.us-east-1.aws.elastic.cloud:443","apiKey":"your-api-key-here"}' \
  --region us-east-1
```

#### Set Up IRSA (IAM Roles for Service Accounts)

For EKS clusters, set up IRSA to allow the OpenTelemetry Collector to access AWS Secrets Manager:

```bash
./setup-eks-deployment.sh psimkins-test us-east-1
```

This script will:
- Create an IAM policy for Secrets Manager access
- Create an IAM role with trust relationship for the service account
- Annotate the service account with the IAM role ARN

### 3. Deploy OpenTelemetry Collector

```bash
# Apply RBAC configuration
kubectl apply -f otel-rbac.yaml

# Apply ConfigMap (contains collector configuration)
kubectl apply -f otel-collector-config.yaml

# Deploy the collector DaemonSet
kubectl apply -f otel-collector.yaml
```

### 4. Verify Deployment

```bash
# Check pod status
kubectl get pods -l app=otel-collector

# Check init container logs (should show successful secret fetch)
kubectl logs -l app=otel-collector -c fetch-secrets

# Check collector logs
kubectl logs -l app=otel-collector -c otel-collector
```

## Configuration Files

### `otel-collector-config.yaml`
ConfigMap containing the OpenTelemetry Collector configuration:
- **Receivers**: OTLP (HTTP/gRPC) and Prometheus
- **Processors**: Memory limiter, Kubernetes attributes, batch
- **Exporters**: Elastic Cloud (endpoint and API key from environment variables)

### `otel-collector.yaml`
DaemonSet deployment with:
- **Init Container**: Fetches secrets from AWS Secrets Manager
- **Main Container**: OpenTelemetry Collector with environment variables from secrets

### `otel-rbac.yaml`
Service account, ClusterRole, and ClusterRoleBinding for the collector with IRSA annotation.

## Security

### Secrets Management

All sensitive information (Elastic endpoint and API key) is stored in AWS Secrets Manager, not in Git. The configuration files use environment variables that are populated at runtime.

### IAM Permissions

The IAM role created by `setup-eks-deployment.sh` has minimal permissions:
- `secretsmanager:GetSecretValue` on the specific secret
- `secretsmanager:DescribeSecret` on the specific secret

### For Non-EKS Clusters

If you're not using EKS, you can provide AWS credentials via a Kubernetes secret:

```bash
./create-aws-credentials-secret.sh
```

Then the DaemonSet will use these credentials instead of IRSA.

## Monitoring and Troubleshooting

### Check Cluster Status

```bash
./check-cluster-status.sh psimkins-test
```

### Common Issues

#### Init Container Fails to Fetch Secrets

1. Verify IAM role permissions:
   ```bash
   aws iam get-role-policy --role-name otel-collector-secrets-role --policy-name OtelCollectorSecretsPolicy
   ```

2. Check if secret exists:
   ```bash
   aws secretsmanager describe-secret --secret-id istio/otel-collector/elastic
   ```

3. Verify OIDC provider is associated:
   ```bash
   aws eks describe-cluster --name psimkins-test --query 'cluster.identity.oidc.issuer'
   ```

#### Collector Can't Read Environment Variables

1. Check if secrets were written to the volume:
   ```bash
   kubectl exec -it $(kubectl get pod -l app=otel-collector -o jsonpath='{.items[0].metadata.name}') -c fetch-secrets -- cat /secrets/ELASTIC_ENDPOINT
   ```

2. Verify collector logs:
   ```bash
   kubectl logs -l app=otel-collector -c otel-collector
   ```

## Prometheus Integration

The OpenTelemetry Collector is configured to scrape Prometheus metrics from Istio gateways:

```yaml
prometheus:
  config:
    scrape_configs:
      - job_name: 'istio-gateways'
        static_configs:
          - targets:
              - "istio-ingressgateway:15090"
              - "istio-egressgateway:15090"
        metrics_path: /stats/prometheus
```

**Note:** Update the target IPs in `otel-collector-config.yaml` to match your Istio gateway pod IPs, or use service names if DNS is configured.

## Istio Integration

To enable Istio telemetry collection:

1. Ensure Istio is installed in your cluster
2. The OpenTelemetry Collector will automatically collect:
   - **Traces**: Via OTLP receiver from Istio sidecars
   - **Metrics**: Via Prometheus receiver from Istio gateways
   - **Logs**: Via OTLP receiver

3. Configure Istio to send telemetry to the collector:
   ```yaml
   # In your Istio Telemetry API configuration
   apiVersion: telemetry.istio.io/v1alpha1
   kind: Telemetry
   metadata:
     name: otel-collector
   spec:
     providers:
       - name: otel
   ```

## Scripts Reference

- `create-eks-cluster.sh` - Creates a new EKS cluster
- `setup-eks-deployment.sh` - Sets up IRSA for EKS cluster
- `setup-aws-secrets.sh` - Creates/updates secret in AWS Secrets Manager
- `create-aws-credentials-secret.sh` - Creates Kubernetes secret with AWS credentials (for non-EKS)
- `check-cluster-status.sh` - Checks EKS cluster status

## Additional Documentation

- [AWS Secrets Manager Setup Guide](README-AWS-SECRETS.md)
- [Istio Documentation](https://istio.io/latest/docs/)
- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)

## Contributing

This is a public repository. Please ensure:
- No secrets or credentials are committed
- All sensitive values use environment variables or AWS Secrets Manager
- Configuration files are safe for public viewing

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues related to:
- **Istio**: [Istio GitHub Issues](https://github.com/istio/istio/issues)
- **OpenTelemetry**: [OpenTelemetry GitHub Issues](https://github.com/open-telemetry/opentelemetry-collector/issues)
- **AWS EKS**: [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
