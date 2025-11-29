# Elastic eBPF Universal Profiling Integration

## Overview

This directory contains the integration for Elastic's Universal Profiling agent, which uses eBPF to provide continuous, zero-instrumentation profiling of all processes in your Kubernetes cluster, including Istio proxies.

## Files

- **`elastic-profiling-rbac.yaml`** - RBAC resources (ServiceAccount, ClusterRole, ClusterRoleBinding)
- **`elastic-profiling-agent.yaml`** - DaemonSet deployment for the profiling agent
- **`deploy-elastic-profiling.sh`** - Deployment script
- **`ELASTIC-EBPF-INTEGRATION.md`** - Complete integration guide
- **`ELASTIC-EBPF-QUICK-START.md`** - Quick start guide

## Quick Start

```bash
# Deploy the profiling agent
./deploy-elastic-profiling.sh

# Verify deployment
kubectl get pods -l app=elastic-profiling-agent

# View logs
kubectl logs -l app=elastic-profiling-agent -n default
```

## What It Does

The profiling agent:
- ✅ Profiles **all processes** on each node (including Istio Envoy proxies)
- ✅ Requires **zero code instrumentation**
- ✅ Has **minimal overhead** (< 1% CPU per node)
- ✅ Provides **flame graphs** and performance insights in Elastic Cloud
- ✅ Works alongside your existing Prometheus metrics

## Prerequisites

1. **Kubernetes cluster** with Linux nodes (kernel 4.9+)
2. **Elastic Cloud** deployment with Universal Profiling enabled
3. **AWS Secrets Manager** secret (same as OpenTelemetry Collector)
4. **Privileged access** (required for eBPF)

## Image Note

The profiling agent image may vary depending on your Elastic version. Options:

1. **Elastic Universal Profiling Agent** (if available):
   ```yaml
   image: docker.elastic.co/observability/profiling-agent:latest
   ```

2. **Elastic Agent** (with profiling enabled):
   ```yaml
   image: docker.elastic.co/beats/elastic-agent:latest
   ```

3. **OpenTelemetry Profiling Agent** (contributed by Elastic):
   ```yaml
   image: otel/profiling-agent:latest
   ```

Check Elastic documentation for the correct image for your deployment.

## Integration with Existing Setup

This complements your existing observability stack:

```
┌─────────────────────────────────────────┐
│         Your Current Setup              │
│                                         │
│  Prometheus Metrics (OTel Collector)   │
│  └─> System metrics (CPU, memory, etc.) │
│                                         │
│  + NEW: eBPF Profiling                  │
│  └─> Code-level performance (functions) │
└─────────────────────────────────────────┘
```

Together, you get:
- **What** is slow (Prometheus metrics)
- **Why** it's slow (Profiling stack traces)

## Accessing Profiling Data

1. Navigate to **Elastic Cloud** > **Observability** > **Universal Profiling**
2. View flame graphs for CPU usage
3. Analyze top functions consuming CPU
4. Filter by namespace, service, or process

## Security

The agent runs with `privileged: true` to access kernel functions. For production:
- Consider dedicated profiling nodes
- Use Pod Security Policies
- Monitor agent behavior
- Restrict network egress if needed

## Troubleshooting

See `ELASTIC-EBPF-INTEGRATION.md` for detailed troubleshooting steps.

Common issues:
- Pods not starting → Check logs and kernel version
- No data in Elastic → Verify credentials and connectivity
- High resource usage → Adjust resource limits

## More Information

- [Elastic Universal Profiling Docs](https://www.elastic.co/guide/en/observability/current/universal-profiling.html)
- [eBPF Overview](https://ebpf.io/)
- [OpenTelemetry Profiling](https://opentelemetry.io/blog/2024/elastic-contributes-continuous-profiling-agent/)

