# Elastic Universal Profiling (eBPF) Integration Guide

## Overview

This guide explains how to integrate Elastic's Universal Profiling agent (eBPF-based) into your Istio observability setup. The profiling agent provides continuous, whole-system profiling without code instrumentation.

## What is Elastic Universal Profiling?

Elastic Universal Profiling uses eBPF (extended Berkeley Packet Filter) to:
- **Profile every line of code** running on a machine
- **Zero instrumentation** - no code changes required
- **Low overhead** - minimal CPU and memory impact
- **Complete visibility** - application code, kernel, and third-party libraries
- **Multi-language support** - C/C++, Rust, Go, Java, Python, .NET

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Node                       │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Istio Proxy  │  │  App Pods    │  │  System      │ │
│  │  (Envoy)     │  │              │  │  Processes   │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                  │                  │         │
│         └──────────────────┼──────────────────┘         │
│                            │                            │
│                            ▼                            │
│         ┌──────────────────────────────────┐           │
│         │  Elastic Profiling Agent (eBPF)  │           │
│         │  - Attaches to kernel functions  │           │
│         │  - Profiles all processes        │           │
│         │  - Collects stack traces         │           │
│         └──────────────┬───────────────────┘           │
│                        │                                 │
└────────────────────────┼─────────────────────────────────┘
                         │ HTTPS
                         ▼
         ┌──────────────────────────────────┐
         │      Elastic Cloud               │
         │  - Universal Profiling UI        │
         │  - Performance insights          │
         │  - Flame graphs                  │
         └──────────────────────────────────┘
```

## Prerequisites

1. **Kubernetes cluster** with nodes running Linux (eBPF requires Linux kernel 4.9+)
2. **Elastic Cloud deployment** with Universal Profiling enabled
3. **AWS Secrets Manager** secret with Elastic credentials (same as OpenTelemetry Collector)
4. **Privileged access** - eBPF requires privileged containers or specific capabilities

## Deployment

### Step 1: Deploy RBAC

```bash
kubectl apply -f elastic-profiling-rbac.yaml
```

This creates:
- ServiceAccount for the profiling agent
- ClusterRole with necessary permissions
- ClusterRoleBinding to grant permissions

### Step 2: Deploy Profiling Agent

```bash
kubectl apply -f elastic-profiling-agent.yaml
```

The DaemonSet will:
- Deploy one profiling agent per node
- Fetch Elastic credentials from AWS Secrets Manager
- Start profiling all processes on each node

### Step 3: Verify Deployment

```bash
# Check pods are running
kubectl get pods -l app=elastic-profiling-agent -n default

# Check logs
kubectl logs -l app=elastic-profiling-agent -n default --tail=50

# Verify agent is connecting to Elastic
kubectl logs -l app=elastic-profiling-agent -n default | grep -i "connected\|error"
```

## Configuration

### Environment Variables

The profiling agent uses these environment variables (from ConfigMap):

- `ELASTIC_ENDPOINT`: Your Elastic Cloud endpoint
- `ELASTIC_API_KEY`: Your Elastic API key
- `PROJECT_ID`: Project ID (default: "1")
- `PROFILING_LOG_LEVEL`: Log level (default: "info")
- `PROFILING_ENABLED`: Enable/disable profiling (default: "true")

### Security Context

The agent runs with `privileged: true` to access kernel functions. For production, consider:

1. **Using specific capabilities** instead of privileged:
   ```yaml
   capabilities:
     add:
       - SYS_ADMIN
       - SYS_RESOURCE
       - NET_ADMIN
       - BPF
       - PERFMON
   ```

2. **Pod Security Policies** or **Pod Security Standards**:
   - Configure your cluster to allow privileged containers
   - Or use a namespace with relaxed security policies

3. **Node selection**:
   - Use node selectors to run only on specific nodes
   - Consider dedicated profiling nodes

## What Gets Profiled

The eBPF agent automatically profiles:

1. **Istio Envoy Proxies** - Sidecar and gateway proxies
2. **Application Pods** - All containers in your cluster
3. **System Processes** - Kernel and system-level processes
4. **Third-party Libraries** - Libraries used by applications

### Filtering (Optional)

To profile only specific processes, you can configure filters in the agent. However, the default behavior profiles everything with minimal overhead.

## Viewing Profiling Data

### In Elastic Cloud

1. Navigate to **Observability > Universal Profiling**
2. View **Flame Graphs** for CPU usage
3. Analyze **Top Functions** consuming CPU
4. Compare profiles over time
5. Filter by:
   - Service/namespace
   - Process name
   - Time range

### Key Metrics

- **CPU Usage**: Which functions consume the most CPU
- **Stack Traces**: Complete call stacks
- **Hot Paths**: Most frequently executed code paths
- **Memory Allocations**: Memory allocation patterns

## Integration with Existing Setup

### Complementing Prometheus Metrics

The profiling agent complements your existing Prometheus metrics:

- **Prometheus**: System-level metrics (CPU, memory, network)
- **Profiling**: Code-level performance (which functions, why slow)

Together, they provide:
1. **What** is slow (Prometheus metrics)
2. **Why** it's slow (Profiling stack traces)

### Example Workflow

1. **Prometheus alert** shows high CPU usage on Istio gateway
2. **Profiling data** shows which Envoy functions are consuming CPU
3. **Identify** specific code paths causing the issue
4. **Optimize** based on profiling insights

## Troubleshooting

### Agent Not Starting

**Issue**: Pods in `CrashLoopBackOff` or `Error`

**Solutions**:
```bash
# Check logs
kubectl logs -l app=elastic-profiling-agent -n default

# Common issues:
# 1. Missing Elastic credentials
kubectl get configmap elastic-profiling-env -n default

# 2. Kernel version too old (need 4.9+)
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kernelVersion}'

# 3. Privileged access denied
# Check Pod Security Policies or Security Context constraints
```

### No Profiling Data in Elastic

**Issue**: Agent running but no data in Elastic Cloud

**Solutions**:
1. **Verify endpoint**: Check `ELASTIC_ENDPOINT` is correct
2. **Check API key**: Ensure API key has profiling permissions
3. **Network connectivity**: Verify agent can reach Elastic Cloud
4. **Check logs**: Look for connection errors

```bash
# Test connectivity from agent pod
kubectl exec -it $(kubectl get pod -l app=elastic-profiling-agent -o jsonpath='{.items[0].metadata.name}') -- \
  curl -v -H "Authorization: ApiKey $ELASTIC_API_KEY" $ELASTIC_ENDPOINT
```

### High Resource Usage

**Issue**: Profiling agent consuming too much CPU/memory

**Solutions**:
1. **Adjust resource limits** in the DaemonSet
2. **Reduce profiling frequency** (if configurable)
3. **Filter processes** to profile only specific ones
4. **Use node selectors** to run on fewer nodes

## Security Considerations

### eBPF Security

- eBPF programs are verified by the kernel before execution
- Programs cannot access arbitrary memory
- Kernel enforces resource limits

### Container Security

- The agent runs with privileged access (required for eBPF)
- Consider running on dedicated nodes
- Use network policies to restrict egress
- Monitor agent behavior

### Data Privacy

- Profiling data may contain sensitive information
- Stack traces can reveal code structure
- Ensure compliance with data privacy policies
- Consider filtering sensitive processes

## Performance Impact

### Expected Overhead

- **CPU**: < 1% per node
- **Memory**: ~100-200MB per node
- **Network**: Minimal (profiling data is compressed)

### Best Practices

1. **Start with one node** to measure impact
2. **Monitor resource usage** after deployment
3. **Adjust as needed** based on your workload
4. **Use during business hours** if overhead is a concern

## Advanced Configuration

### Custom Project ID

If you have multiple projects in Elastic:

```yaml
env:
  - name: PROJECT_ID
    value: "2"  # Your project ID
```

### Profiling Specific Processes

You can configure the agent to profile only specific processes, but this requires custom configuration. The default behavior (profile everything) is recommended for most use cases.

### Integration with Elastic Agent

If you're using Elastic Agent, you can enable profiling through the Elastic Agent integration instead of a standalone DaemonSet. This provides better integration but requires Elastic Agent deployment.

## Next Steps

1. **Deploy the agent** using the provided manifests
2. **Verify data** is flowing to Elastic Cloud
3. **Explore the UI** to understand profiling insights
4. **Correlate** with Prometheus metrics
5. **Optimize** based on profiling findings

## Resources

- [Elastic Universal Profiling Documentation](https://www.elastic.co/guide/en/observability/current/universal-profiling.html)
- [eBPF Overview](https://ebpf.io/)
- [OpenTelemetry Profiling Contribution](https://opentelemetry.io/blog/2024/elastic-contributes-continuous-profiling-agent/)

## Support

For issues or questions:
1. Check agent logs: `kubectl logs -l app=elastic-profiling-agent`
2. Review Elastic Cloud Universal Profiling UI
3. Consult Elastic documentation
4. Contact Elastic support if needed

---

**Note**: This integration uses Elastic's Universal Profiling agent, which Elastic contributed to OpenTelemetry. The agent is production-ready and actively maintained.

