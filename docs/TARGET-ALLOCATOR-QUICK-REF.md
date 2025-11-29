# Target Allocator + EDOT: Quick Reference

## 🎯 The Challenge

**Working:** Alloy + Target Allocator ✅  
**Working:** Standalone OTel Collector + Target Allocator ✅  
**Challenging:** EDOT Collector + Target Allocator ❌

---

## 🔍 Issue #1: Collector Mode Conflict

**Error:**
```
The OpenTelemetry Collector mode is set to deployment, which does not support modification.
```

**Problem:**
- Configured `mode: daemonset` but actual mode is `deployment`
- Deployment mode doesn't support Target Allocator modifications

**Quick Checks:**
```bash
# Check actual collector mode
kubectl get opentelemetrycollector -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.mode}{"\n"}{end}'

# Check for conflicting resources
kubectl get opentelemetrycollector -A

# Review operator logs
kubectl logs -n opentelemetry-operator-system -l app.kubernetes.io/name=opentelemetry-operator --tail=50
```

---

## 🔍 Issue #2: Missing Prometheus Configuration

**Error:**
```
no prometheus available as part of the configuration
```

**Problem:**
- Target Allocator can't find ServiceMonitor/PodMonitor resources
- Even with empty selectors `{}`, if no CRs exist, error occurs

**Quick Checks:**
```bash
# Check for ServiceMonitors
kubectl get servicemonitors -A

# Check for PodMonitors
kubectl get podmonitors -A

# Check Target Allocator logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=opentelemetry-targetallocator --tail=50
```

**Example PodMonitor for Istio:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: istio-gateways
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  podMetricsEndpoints:
    - port: http-monitoring
      path: /stats/prometheus
      interval: 15s
```

---

## 📋 Support Checklist

### Information to Gather

1. **OpenTelemetryCollector YAML**
   ```bash
   kubectl get opentelemetrycollector <name> -n <namespace> -o yaml
   ```

2. **ServiceMonitor/PodMonitor Resources**
   ```bash
   kubectl get servicemonitors -A -o yaml
   kubectl get podmonitors -A -o yaml
   ```

3. **Target Allocator Logs**
   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=opentelemetry-targetallocator --tail=100
   ```

4. **Operator Logs**
   ```bash
   kubectl logs -n opentelemetry-operator-system -l app.kubernetes.io/name=opentelemetry-operator --tail=100
   ```

---

## 🎯 Expected Configuration

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: elastic-otel-collector
spec:
  mode: daemonset  # or statefulset
  targetAllocator:
    enabled: true
    prometheusCR:
      enabled: true
      podMonitorSelector: {}
      serviceMonitorSelector: {}
```

---

## ✅ Current Working Setup (DaemonSet)

**What we're using today:**
- Manual DaemonSet deployment
- Static Prometheus scrape config
- Works but requires manual updates

**Files:**
- `otel-collector.yaml` - DaemonSet manifest
- `otel-collector-config.yaml` - Static Prometheus config

---

## 🔧 Next Steps

1. Verify collector mode matches configuration
2. Create PodMonitor/ServiceMonitor for Istio
3. Check RBAC permissions for cross-namespace discovery
4. Review operator version compatibility
5. Test with single namespace first, then expand

---

## 📚 Key Resources

- [Target Allocator Docs](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/targetallocator.md)
- [Prometheus CR Discovery](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/targetallocator.md#prometheus-cr-discovery)
- [Troubleshooting Guide](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/targetallocator.md#troubleshooting)

