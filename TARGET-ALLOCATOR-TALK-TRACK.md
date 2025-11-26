# Target Allocator + EDOT Collector: A Real Challenge
## Talk Track for Demo Presentation

---

## 🎯 **Opening: Setting the Context**

### What We Have Working Today

**"Let me show you what we've successfully deployed today..."**

- **Standalone OpenTelemetry Collector** running as a DaemonSet
- Successfully scraping **Istio Prometheus metrics** from ingress gateways
- Metrics flowing into **Elastic Cloud** via OTLP HTTP
- Dashboard visualizations showing real-time Istio gateway metrics

**Demo Points:**
```bash
# Show the current working setup
kubectl get daemonset otel-collector -n default
kubectl logs -l app=otel-collector -n default --tail=20

# Show metrics in Elastic
# Navigate to Kibana and show the dashboard we created
```

**Key Configuration:**
- **Mode**: DaemonSet (one collector per node)
- **Scraping**: Static Prometheus configuration
- **Target**: `istio-ingressgateway:15090`
- **Metrics Path**: `/stats/prometheus`

---

## 🚀 **The Evolution: Why Target Allocator?**

### Current Limitations

**"But here's the challenge with our current approach..."**

1. **Static Configuration**: We hardcode scrape targets
   - Every time we add a new service, we need to update the collector config
   - Requires ConfigMap updates and pod restarts
   - Doesn't scale well with dynamic Kubernetes workloads

2. **Resource Duplication**: Each collector pod scrapes the same targets
   - Multiple collectors hitting the same Prometheus endpoints
   - Wasted network bandwidth and CPU
   - Potential for rate limiting

3. **Manual Service Discovery**: We manually discover and configure targets
   - No automatic discovery of new PodMonitors or ServiceMonitors
   - Requires operational overhead

### The Target Allocator Solution

**"This is where Target Allocator comes in..."**

**Target Allocator Benefits:**
- ✅ **Automatic Discovery**: Discovers Prometheus CRs (PodMonitor, ServiceMonitor)
- ✅ **Target Distribution**: Intelligently distributes scrape targets across collector instances
- ✅ **Dynamic Updates**: No need to restart collectors when targets change
- ✅ **Reduced Duplication**: Each target scraped by only one collector instance
- ✅ **Better Scaling**: Add collectors without reconfiguring targets

**How It Works:**
1. Target Allocator watches for Prometheus CRs (PodMonitor/ServiceMonitor)
2. Discovers scrape targets from these CRs
3. Distributes targets across available collector instances
4. Collectors query Target Allocator for their assigned targets
5. Collectors scrape only their assigned targets

---

## ✅ **What Works: Standalone Collector + Alloy + Target Allocator**

**"The good news is, we've successfully gotten this working with Alloy..."**

### Success Story

- **Alloy** (Grafana's distribution) + Target Allocator = ✅ Working
- **Standalone OpenTelemetry Collector** + Target Allocator = ✅ Working
- Dynamic target discovery and distribution functioning correctly

**Why It Works:**
- Alloy and standalone collector support the Target Allocator's HTTP endpoint
- Can query Target Allocator for assigned scrape targets
- Properly handle dynamic configuration updates

---

## ❌ **The Challenge: EDOT Collector + Target Allocator**

**"But here's where we hit a wall..."**

### The Problem Statement

**"Making Target Allocator run alongside EDOT (Elastic Distribution of OpenTelemetry) collector is still a real challenge."**

We've been working with Elastic Support to get to the bottom of this, and they've identified **two critical issues**:

---

## 🔍 **Issue #1: Collector Mode Conflict**

### The Error

```
The OpenTelemetry Collector mode is set to deployment, which does not support modification.
```

### The Problem

**"Even though we've set `mode: daemonset` in our configuration..."**

- The OpenTelemetry Operator webhook is trying to patch the collector
- The error indicates the collector's mode is `deployment`, not `daemonset`
- Deployment mode doesn't support the modifications Target Allocator needs

### Root Cause Analysis

**"This suggests a potential conflict or incorrect application of the daemonset mode."**

Possible causes:
1. **Conflicting Resources**: Another OpenTelemetryCollector CR in deployment mode
2. **Operator Defaults**: Operator applying default deployment mode
3. **Webhook Timing**: Webhook trying to patch before mode is properly set
4. **Configuration Override**: Something overriding the daemonset mode

### Troubleshooting Steps

**"Here's what Support asked us to verify..."**

```bash
# 1. Check all OpenTelemetryCollector resources
kubectl get opentelemetrycollector -A

# 2. Verify the actual mode of the collector
kubectl get opentelemetrycollector <name> -n <namespace> -o yaml | grep -A 5 "mode:"

# 3. Check for conflicting resources
kubectl get opentelemetrycollector -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.mode}{"\n"}{end}'

# 4. Review operator logs for webhook activity
kubectl logs -n opentelemetry-operator-system -l app.kubernetes.io/name=opentelemetry-operator --tail=50
```

### Expected Configuration

**"According to the documentation, Target Allocator examples often use statefulset mode..."**

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-collector
  namespace: default
spec:
  mode: daemonset  # or statefulset
  targetAllocator:
    enabled: true
    prometheusCR:
      enabled: true
      podMonitorSelector: {}
      serviceMonitorSelector: {}
```

**"But the error suggests the actual deployed mode is different from what we configured."**

---

## 🔍 **Issue #2: Missing Prometheus Configuration**

### The Error

```
no prometheus available as part of the configuration
```

### The Problem

**"This error is often misleading..."**

- We've correctly configured `prometheusCR: enabled: true`
- We've set empty selectors `{}` to match all monitors
- But Target Allocator still can't find any Prometheus CRs

### Root Cause Analysis

**"The error typically means one of three things..."**

1. **No CRs Exist**: No ServiceMonitor or PodMonitor resources deployed
2. **Namespace Mismatch**: CRs exist but in different namespaces
3. **Selector Mismatch**: CRs exist but labels don't match selectors

### Troubleshooting Steps

**"Support asked us to validate these specific things..."**

```bash
# 1. Check if ServiceMonitors exist
kubectl get servicemonitors -A

# 2. Check if PodMonitors exist
kubectl get podmonitors -A

# 3. If none exist, we need to create them
# For Istio, we'd need a PodMonitor like:
```

**Example PodMonitor for Istio:**
```yaml
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

**"But wait - even with empty selectors `{}`, if no CRs exist, we'll get this error."**

### Cross-Namespace Considerations

**"If CRs are in different namespaces..."**

- Target Allocator needs RBAC permissions to discover across namespaces
- May need to configure namespace selectors
- Check Target Allocator pod logs for discovery messages

```bash
# Check Target Allocator logs
kubectl logs -n default -l app.kubernetes.io/name=opentelemetry-targetallocator --tail=50

# Look for messages like:
# - "discovering targets"
# - "no targets found"
# - "targets discovered"
```

---

## 📋 **Support's Requested Information**

**"To help troubleshoot, Support asked us to provide..."**

### 1. Full OpenTelemetryCollector YAML

```bash
kubectl get opentelemetrycollector <name> -n <namespace> -o yaml > collector-cr.yaml
```

**What to look for:**
- Actual `mode` field value
- `targetAllocator` configuration
- Any conflicting or overriding settings

### 2. ServiceMonitor/PodMonitor Resources

```bash
kubectl get servicemonitors -A -o yaml > servicemonitors.yaml
kubectl get podmonitors -A -o yaml > podmonitors.yaml
```

**What to look for:**
- Do they exist?
- What labels do they have?
- What namespaces are they in?
- Do their selectors match actual pods/services?

### 3. Target Allocator Logs

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=opentelemetry-targetallocator --tail=100
```

**What to look for:**
- Target discovery messages
- Prometheus configuration errors
- Webhook or API errors

### 4. Operator Logs

```bash
kubectl logs -n opentelemetry-operator-system -l app.kubernetes.io/name=opentelemetry-operator --tail=100
```

**What to look for:**
- Webhook patching attempts
- Mode conflicts
- Resource creation/update errors

---

## 🎯 **Current State: Our Demo**

### What We're Using Today

**"In our current demo, we're using a manual DaemonSet approach..."**

```yaml
# otel-collector.yaml - DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-collector
spec:
  template:
    spec:
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector-contrib:0.100.0
```

**With static Prometheus configuration:**
```yaml
# otel-collector-config.yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: 'istio-gateways'
          static_configs:
            - targets: ["192.168.23.0:15090"]
```

**"This works, but it's not dynamic. Every new service requires a config update."**

### The Goal: EDOT + Target Allocator

**"What we want is..."**

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: elastic-otel-collector
spec:
  mode: daemonset
  targetAllocator:
    enabled: true
    prometheusCR:
      enabled: true
      podMonitorSelector: {}
      serviceMonitorSelector: {}
```

**"But we're hitting these two issues that prevent it from working."**

---

## 🔧 **Next Steps & Resolution Path**

### Immediate Actions

1. **Verify Collector Mode**
   - Confirm actual deployed mode matches configuration
   - Check for conflicting OpenTelemetryCollector resources
   - Review operator webhook behavior

2. **Create Prometheus CRs**
   - Deploy PodMonitor for Istio gateways
   - Verify labels and selectors match
   - Test discovery in same namespace first

3. **Check RBAC Permissions**
   - Ensure Target Allocator can discover CRs
   - Verify cross-namespace permissions if needed
   - Check operator permissions

4. **Review Operator Version**
   - Ensure compatible operator version
   - Check for known issues or bugs
   - Consider operator upgrade if needed

### Long-term Solution

**"Once we resolve these issues, we'll have..."**

- ✅ Dynamic target discovery via Prometheus CRs
- ✅ Automatic target distribution across collectors
- ✅ No manual configuration updates needed
- ✅ Better resource utilization
- ✅ Scalable architecture

---

## 💡 **Key Takeaways**

### For the Audience

1. **Target Allocator is powerful** - Works great with Alloy and standalone collector
2. **EDOT integration is challenging** - Two specific issues blocking progress
3. **Configuration matters** - Mode conflicts and missing CRs are common pitfalls
4. **Support is engaged** - Working through systematic troubleshooting
5. **Solution is close** - Once these issues are resolved, we'll have a robust setup

### For the Demo

**"What we can show today:"**
- ✅ Working Istio metrics collection
- ✅ Elastic Cloud integration
- ✅ Real-time dashboard visualizations
- ✅ Manual DaemonSet approach

**"What we're working towards:"**
- 🔄 Dynamic target discovery
- 🔄 Automatic scaling
- 🔄 Zero-touch configuration
- 🔄 Production-ready architecture

---

## 📝 **Demo Script**

### Opening (2 minutes)

1. **Show current dashboard** - "Here's what we have working"
2. **Explain the setup** - "DaemonSet with static config"
3. **Show metrics flowing** - "Real-time Istio gateway metrics"

### The Challenge (3 minutes)

1. **Explain limitations** - "But we need dynamic discovery"
2. **Introduce Target Allocator** - "This is the solution"
3. **Show what works** - "Alloy + Target Allocator = ✅"
4. **Show the gap** - "EDOT + Target Allocator = ❌"

### Deep Dive (5 minutes)

1. **Issue #1: Mode Conflict**
   - Show the error
   - Explain the problem
   - Show troubleshooting commands
   
2. **Issue #2: Missing Prometheus CRs**
   - Show the error
   - Explain the problem
   - Show what we need to create

### Resolution Path (2 minutes)

1. **Next steps** - What we're doing to fix it
2. **Expected outcome** - What we'll have when it works
3. **Timeline** - When we expect resolution

### Q&A (3 minutes)

- Address questions about Target Allocator
- Discuss alternative approaches
- Share lessons learned

---

## 🎬 **Visual Aids**

### Slide 1: Current Architecture
```
┌─────────────┐
│   Istio     │
│  Gateways   │
└──────┬──────┘
       │ :15090
       │ /stats/prometheus
       ▼
┌─────────────────┐
│  OTel Collector │
│   (DaemonSet)   │
│  Static Config  │
└────────┬────────┘
         │ OTLP HTTP
         ▼
┌─────────────────┐
│  Elastic Cloud  │
└─────────────────┘
```

### Slide 2: Target Allocator Architecture (Goal)
```
┌─────────────┐
│   Istio     │
│  Gateways   │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│ PodMonitor/      │
│ ServiceMonitor   │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Target Allocator │
│  (Discovers &    │
│   Distributes)   │
└──────┬───────────┘
       │
       ▼
┌─────────────────┐      ┌─────────────────┐
│  OTel Collector│      │  OTel Collector │
│   Instance 1   │      │   Instance 2    │
│  (Assigned     │      │  (Assigned      │
│   Targets)     │      │   Targets)      │
└────────┬────────┘      └────────┬────────┘
         │                        │
         └──────────┬─────────────┘
                    │ OTLP HTTP
                    ▼
         ┌─────────────────┐
         │  Elastic Cloud  │
         └─────────────────┘
```

### Slide 3: The Two Issues
```
Issue #1: Mode Conflict
├─ Configured: daemonset
├─ Actual: deployment
└─ Error: "does not support modification"

Issue #2: Missing Prometheus CRs
├─ Target Allocator: enabled
├─ Prometheus CR: enabled
├─ Selectors: {} (match all)
└─ Error: "no prometheus available"
```

---

## 📚 **References**

- [OpenTelemetry Operator Documentation](https://github.com/open-telemetry/opentelemetry-operator)
- [Target Allocator Overview](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/targetallocator.md)
- [Target Allocator Scaling Guide](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/targetallocator-scaling.md)
- [Prometheus CR Discovery](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/targetallocator.md#prometheus-cr-discovery)
- [Cross-Namespace Monitoring](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/targetallocator.md#cross-namespace-monitoring)

---

## 🎤 **Speaker Notes**

### Tone & Delivery

- **Confident but honest** - We have a working solution, but acknowledge the challenge
- **Technical but accessible** - Explain concepts clearly without dumbing down
- **Solution-focused** - Emphasize we're working towards resolution
- **Engaging** - Use the demo to show real value

### Key Phrases

- "This is a real challenge we're working through"
- "Support has been incredibly helpful in identifying the root causes"
- "The good news is we know exactly what the issues are"
- "Once resolved, we'll have a production-ready, scalable solution"
- "The architecture is sound, we just need to work through these configuration issues"

### Handling Questions

**Q: Why not just use Alloy?**
A: "Alloy works great, but EDOT provides Elastic-specific optimizations and integrations that are valuable for our use case."

**Q: Is this a blocker for production?**
A: "Not necessarily - our current DaemonSet approach works, but Target Allocator would give us better scalability and operational simplicity."

**Q: When do you expect this to be resolved?**
A: "We're actively working with Support. The issues are well-defined, so we're optimistic about a near-term resolution."

---

**End of Talk Track**

