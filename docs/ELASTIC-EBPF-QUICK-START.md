# Elastic eBPF Profiling - Quick Start

## What You Get

- **Zero-instrumentation profiling** of all processes (including Istio proxies)
- **Low overhead** (< 1% CPU per node)
- **Complete visibility** into code-level performance
- **Flame graphs** and performance insights in Elastic Cloud

## Quick Deploy

```bash
# 1. Deploy everything
./deploy-elastic-profiling.sh

# 2. Check status
kubectl get pods -l app=elastic-profiling-agent

# 3. View logs
kubectl logs -l app=elastic-profiling-agent -n default --tail=50
```

## Verify It's Working

```bash
# Check pods are running
kubectl get pods -l app=elastic-profiling-agent -n default

# Should see: Running (1/1)
```

## Access Profiling Data

1. Go to **Elastic Cloud** > **Observability** > **Universal Profiling**
2. View flame graphs and performance metrics
3. Filter by namespace, service, or process

## What Gets Profiled

✅ Istio Envoy proxies (sidecars and gateways)  
✅ All application pods  
✅ System processes  
✅ Third-party libraries  

## Troubleshooting

### Pods Not Starting

```bash
# Check logs
kubectl logs -l app=elastic-profiling-agent -n default

# Common issues:
# - Missing credentials: Check ConfigMap
kubectl get configmap elastic-profiling-env -n default

# - Kernel too old: Need Linux 4.9+
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kernelVersion}'
```

### No Data in Elastic

```bash
# Verify credentials
kubectl get configmap elastic-profiling-env -n default -o yaml

# Check connectivity
kubectl exec -it $(kubectl get pod -l app=elastic-profiling-agent -o jsonpath='{.items[0].metadata.name}') -- \
  env | grep ELASTIC
```

## Configuration

Uses the same AWS Secrets Manager secret as OpenTelemetry Collector:
- **Secret**: `istio/otel-collector/elastic`
- **Region**: `us-east-1`

## Resource Usage

- **CPU**: < 1% per node
- **Memory**: ~100-200MB per node
- **Network**: Minimal

## Security Note

The agent runs with `privileged: true` to access kernel functions. This is required for eBPF. For production:
- Consider dedicated profiling nodes
- Use Pod Security Policies
- Monitor agent behavior

## More Info

See `ELASTIC-EBPF-INTEGRATION.md` for detailed documentation.

