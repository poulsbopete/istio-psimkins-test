# Target Allocator Troubleshooting Checklist

## 🔍 Issue #1: Collector Mode Conflict

### Symptoms
- Error: "The OpenTelemetry Collector mode is set to deployment, which does not support modification"
- Target Allocator webhook fails to patch collector
- Collector remains in deployment mode despite daemonset configuration

### Diagnostic Steps

#### Step 1: Verify Actual Collector Mode
```bash
# List all OpenTelemetryCollector resources
kubectl get opentelemetrycollector -A

# Get detailed mode information
kubectl get opentelemetrycollector <name> -n <namespace> -o jsonpath='{.spec.mode}'

# Compare with all collectors
kubectl get opentelemetrycollector -A -o custom-columns=NAME:.metadata.name,NAMESPACE:.metadata.namespace,MODE:.spec.mode
```

#### Step 2: Check for Conflicting Resources
```bash
# Check if multiple collectors exist in same namespace
kubectl get opentelemetrycollector -n <namespace>

# Check for default or system collectors
kubectl get opentelemetrycollector -A | grep -E "default|system"
```

#### Step 3: Review Full Collector Configuration
```bash
# Export full YAML
kubectl get opentelemetrycollector <name> -n <namespace> -o yaml > collector-cr.yaml

# Check for:
# - spec.mode field
# - spec.targetAllocator configuration
# - Any annotations or labels that might override mode
# - spec.upgradeStrategy (might affect mode)
```

#### Step 4: Check Operator Webhook Activity
```bash
# Check operator logs for webhook errors
kubectl logs -n opentelemetry-operator-system \
  -l app.kubernetes.io/name=opentelemetry-operator \
  --tail=100 | grep -i "webhook\|patch\|mode\|deployment"

# Check for admission webhook errors
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | grep -i "opentelemetry"
```

#### Step 5: Verify Operator Version
```bash
# Check operator version
kubectl get deployment -n opentelemetry-operator-system \
  -l app.kubernetes.io/name=opentelemetry-operator \
  -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'

# Check for known issues in operator release notes
```

### Resolution Steps

1. **Ensure Single Collector Resource**
   - Remove any duplicate or conflicting OpenTelemetryCollector resources
   - Use unique names per namespace

2. **Explicitly Set Mode**
   ```yaml
   spec:
     mode: daemonset  # Be explicit, not relying on defaults
   ```

3. **Check Operator Defaults**
   - Review operator configuration for default mode settings
   - May need to set via operator config or CR annotations

4. **Try StatefulSet Mode**
   - Some examples use statefulset instead of daemonset
   - Test if statefulset resolves the issue

5. **Upgrade Operator**
   - Check if newer operator version fixes mode handling
   - Review changelog for mode-related fixes

---

## 🔍 Issue #2: Missing Prometheus Configuration

### Symptoms
- Error: "no prometheus available as part of the configuration"
- Target Allocator enabled but can't discover targets
- Empty target list in Target Allocator

### Diagnostic Steps

#### Step 1: Verify Prometheus CRs Exist
```bash
# Check for ServiceMonitors
kubectl get servicemonitors -A

# Check for PodMonitors
kubectl get podmonitors -A

# If none exist, that's the problem!
```

#### Step 2: Check Target Allocator Configuration
```bash
# Get Target Allocator config from collector CR
kubectl get opentelemetrycollector <name> -n <namespace> -o yaml | grep -A 10 targetAllocator

# Verify prometheusCR is enabled
# Verify selectors are configured (even if empty {})
```

#### Step 3: Check Target Allocator Logs
```bash
# Get Target Allocator pod name
kubectl get pods -n <namespace> -l app.kubernetes.io/name=opentelemetry-targetallocator

# Check logs for discovery messages
kubectl logs -n <namespace> <target-allocator-pod> --tail=100

# Look for:
# - "discovering targets"
# - "no targets found"
# - "targets discovered: X"
# - "prometheus configuration"
```

#### Step 4: Verify CR Labels and Selectors
```bash
# If CRs exist, check their labels
kubectl get servicemonitors -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels}{"\n"}{end}'
kubectl get podmonitors -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels}{"\n"}{end}'

# Check if Target Allocator selectors match
kubectl get opentelemetrycollector <name> -n <namespace> -o jsonpath='{.spec.targetAllocator.prometheusCR}'
```

#### Step 5: Check Namespace Permissions
```bash
# Verify Target Allocator can access other namespaces
kubectl get clusterrolebinding -o yaml | grep -i targetallocator

# Check if RBAC allows cross-namespace discovery
kubectl auth can-i get servicemonitors --all-namespaces \
  --as=system:serviceaccount:<namespace>:opentelemetry-targetallocator

kubectl auth can-i get podmonitors --all-namespaces \
  --as=system:serviceaccount:<namespace>:opentelemetry-targetallocator
```

#### Step 6: Test with Same Namespace First
```bash
# Create a test PodMonitor in the same namespace as collector
# Verify it gets discovered
# Then test cross-namespace
```

### Resolution Steps

1. **Create Required Prometheus CRs**
   ```yaml
   # Example PodMonitor for Istio
   apiVersion: monitoring.coreos.com/v1
   kind: PodMonitor
   metadata:
     name: istio-gateways
     namespace: istio-system
     labels:
       app: istio-gateway
   spec:
     selector:
       matchLabels:
         istio: ingressgateway
     podMetricsEndpoints:
       - port: http-monitoring
         path: /stats/prometheus
         interval: 15s
   ```

2. **Verify Selectors Match**
   - If using label selectors, ensure CR labels match
   - Start with empty selectors `{}` to match all
   - Then refine with specific labels

3. **Check Namespace Configuration**
   - If CRs are in different namespaces, configure namespace selectors
   - Or ensure Target Allocator has cross-namespace permissions

4. **Verify CR Selectors Match Pods/Services**
   - PodMonitor `selector.matchLabels` must match pod labels
   - ServiceMonitor `selector.matchLabels` must match service labels
   - Check actual pod/service labels:
     ```bash
     kubectl get pods -n istio-system --show-labels | grep ingressgateway
     kubectl get services -n istio-system --show-labels
     ```

5. **Test Target Allocator API**
   ```bash
   # Port-forward to Target Allocator
   kubectl port-forward -n <namespace> svc/<target-allocator-service> 8080:8080
   
   # Query targets endpoint
   curl http://localhost:8080/jobs
   curl http://localhost:8080/jobs/<job-name>/targets
   ```

---

## 🔧 General Troubleshooting

### Check Collector Status
```bash
# Check collector pods
kubectl get pods -n <namespace> -l app.kubernetes.io/name=opentelemetry-collector

# Check collector logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=opentelemetry-collector --tail=50

# Check for configuration errors
kubectl logs -n <namespace> -l app.kubernetes.io/name=opentelemetry-collector | grep -i error
```

### Check Target Allocator Status
```bash
# Check Target Allocator pods
kubectl get pods -n <namespace> -l app.kubernetes.io/name=opentelemetry-targetallocator

# Check Target Allocator service
kubectl get svc -n <namespace> -l app.kubernetes.io/name=opentelemetry-targetallocator

# Check Target Allocator logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=opentelemetry-targetallocator --tail=100
```

### Verify Network Connectivity
```bash
# From collector pod, test Target Allocator connectivity
kubectl exec -n <namespace> <collector-pod> -- wget -O- http://<target-allocator-service>:8080/jobs

# Check if collector can reach Target Allocator service
kubectl exec -n <namespace> <collector-pod> -- nslookup <target-allocator-service>
```

### Check Prometheus Receiver Configuration
```bash
# Verify collector config includes prometheus receiver
kubectl get configmap -n <namespace> <collector-config> -o yaml | grep -A 20 prometheus

# Check if using Target Allocator endpoint
# Should see something like:
# receivers:
#   prometheus:
#     config:
#       scrape_configs:
#         - job_name: 'targetallocator'
#           http_sd_configs:
#             - url: 'http://target-allocator:8080/jobs'
```

---

## 📋 Information to Share with Support

### Required Information

1. **OpenTelemetryCollector CR YAML**
   ```bash
   kubectl get opentelemetrycollector <name> -n <namespace> -o yaml > collector-cr.yaml
   ```

2. **All ServiceMonitor/PodMonitor Resources**
   ```bash
   kubectl get servicemonitors -A -o yaml > servicemonitors.yaml
   kubectl get podmonitors -A -o yaml > podmonitors.yaml
   ```

3. **Target Allocator Logs**
   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=opentelemetry-targetallocator > targetallocator-logs.txt
   ```

4. **Operator Logs**
   ```bash
   kubectl logs -n opentelemetry-operator-system -l app.kubernetes.io/name=opentelemetry-operator > operator-logs.txt
   ```

5. **Collector Logs**
   ```bash
   kubectl logs -n <namespace> -l app.kubernetes.io/name=opentelemetry-collector > collector-logs.txt
   ```

6. **Operator Version**
   ```bash
   kubectl get deployment -n opentelemetry-operator-system \
     -l app.kubernetes.io/name=opentelemetry-operator \
     -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'
   ```

7. **Kubernetes Version**
   ```bash
   kubectl version --short
   ```

8. **Events**
   ```bash
   kubectl get events -n <namespace> --sort-by='.lastTimestamp' > events.txt
   ```

---

## ✅ Success Criteria

### Target Allocator Working When:

1. ✅ Target Allocator pod is running
2. ✅ Target Allocator service is accessible
3. ✅ `/jobs` endpoint returns discovered jobs
4. ✅ `/jobs/<job>/targets` returns target list
5. ✅ Collector pods query Target Allocator successfully
6. ✅ Collector pods scrape assigned targets
7. ✅ Metrics appear in Elastic Cloud
8. ✅ No errors in Target Allocator logs
9. ✅ No errors in Collector logs

### Verification Commands

```bash
# 1. Check Target Allocator is running
kubectl get pods -l app.kubernetes.io/name=opentelemetry-targetallocator

# 2. Check jobs are discovered
kubectl port-forward svc/<target-allocator> 8080:8080
curl http://localhost:8080/jobs

# 3. Check targets are assigned
curl http://localhost:8080/jobs/<job-name>/targets

# 4. Check collector is scraping
kubectl logs -l app.kubernetes.io/name=opentelemetry-collector | grep -i "scraping\|target"

# 5. Verify metrics in Elastic
# Use MCP or Kibana to query metrics
```

---

**End of Troubleshooting Guide**

