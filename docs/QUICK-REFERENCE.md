# Quick Reference Card

## Setup Commands (Copy-Paste Ready)

### 1. Create AWS Secret
```bash
export ELASTIC_ENDPOINT="https://your-deployment.ingest.us-east-1.aws.elastic.cloud:443"
export ELASTIC_API_KEY="your-api-key"
./setup-aws-secrets.sh istio/otel-collector/elastic us-east-1
```

### 2. Set Up IRSA
```bash
./setup-eks-deployment.sh YOUR_CLUSTER_NAME us-east-1
```

### 3. Deploy Collector
```bash
kubectl apply -f otel-rbac.yaml
kubectl apply -f otel-collector-config.yaml
kubectl apply -f otel-collector.yaml
```

### 4. Verify
```bash
kubectl get pods -l app=otel-collector
kubectl logs -l app=otel-collector -c fetch-secrets
kubectl logs -l app=otel-collector -c otel-collector --tail=50
```

## Troubleshooting Commands

### Check Pod Status
```bash
kubectl get pods -l app=otel-collector -o wide
kubectl describe pod -l app=otel-collector
```

### Check Logs
```bash
# Init container
kubectl logs -l app=otel-collector -c fetch-secrets

# Main container
kubectl logs -l app=otel-collector -c otel-collector

# Follow logs
kubectl logs -f -l app=otel-collector -c otel-collector
```

### Verify Secrets
```bash
# Check environment variables
kubectl exec -it $(kubectl get pod -l app=otel-collector -o jsonpath='{.items[0].metadata.name}') -- env | grep ELASTIC

# Check IAM role
kubectl get serviceaccount otel-collector -o yaml | grep eks.amazonaws.com/role-arn

# Check AWS secret
aws secretsmanager describe-secret --secret-id istio/otel-collector/elastic
```

### Test Connectivity
```bash
# Test Istio gateway metrics
kubectl exec -it -n istio-system $(kubectl get pod -n istio-system -l app=istio-ingressgateway -o jsonpath='{.items[0].metadata.name}') -- curl localhost:15090/stats/prometheus | head

# Test Elastic connectivity
kubectl exec -it $(kubectl get pod -l app=otel-collector -o jsonpath='{.items[0].metadata.name}') -- sh -c 'curl -v -H "Authorization: ApiKey $ELASTIC_API_KEY" $ELASTIC_ENDPOINT'
```

## Configuration Updates

### Update Prometheus Targets
```bash
# Edit config
kubectl edit configmap otel-collector-config

# Restart collector
kubectl rollout restart daemonset/otel-collector
```

### Enable Host Metrics
Add to `otel-collector-config.yaml`:
```yaml
receivers:
  hostmetrics:
    collection_interval: 10s
    scrapers:
      cpu: {}
      memory: {}
      disk: {}
      network: {}
```

### Configure Istio Telemetry
```bash
kubectl apply -f - <<EOF
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: otel-collector
  namespace: default
spec:
  providers:
    - name: otel
EOF
```

## Common Issues & Fixes

| Issue | Quick Fix |
|-------|-----------|
| Pod stuck in Init | Check IAM role annotation, verify secret exists |
| No metrics | Verify Prometheus scrape config, check gateway IPs |
| No traces | Create Telemetry resource, verify Istio config |
| Connection errors | Check endpoint/API key, verify Elastic access |
| High CPU/Memory | Adjust resource limits in DaemonSet |

## File Locations

- **Config:** `otel-collector-config.yaml`
- **Deployment:** `otel-collector.yaml`
- **RBAC:** `otel-rbac.yaml`
- **IAM Policy:** `otel-iam-policy.json`
- **Setup Scripts:** `setup-*.sh`, `create-*.sh`

## Useful Links

- Repository: https://github.com/poulsbopete/istio-psimkins-test
- Full Walkthrough: See `CUSTOMER-WALKTHROUGH.md`
- Presentation Guide: See `PRESENTATION-GUIDE.md`
- AWS Secrets: https://console.aws.amazon.com/secretsmanager
- Elastic Cloud: https://cloud.elastic.co

