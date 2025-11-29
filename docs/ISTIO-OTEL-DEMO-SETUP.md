# Istio + OpenTelemetry Demo Setup

## Current Status

✅ **Istio sidecar injection enabled** for `otel-demo` namespace  
✅ **Istio Gateway created** to expose frontend through ingress gateway  
✅ **OpenTelemetry Collector updated** to automatically discover and scrape all Istio sidecars  
⚠️ **Resource constraints**: Cluster memory is at 99% - some demo pods are pending

## What's Configured

### 1. Istio Integration

- **Namespace labeled**: `otel-demo` has `istio-injection=enabled`
- **Gateway**: `otel-demo-gateway` exposes services through Istio ingress gateway
- **VirtualService**: Routes traffic to `frontend` service on port 8080

### 2. Prometheus Metrics Collection

The OpenTelemetry Collector is now configured to:

1. **Scrape Istio Ingress Gateway** (istio-system namespace)
2. **Auto-discover all Istio sidecars** in:
   - `default` namespace
   - `otel-demo` namespace

**How it works:**
- Uses Kubernetes service discovery (`kubernetes_sd_configs`)
- Automatically finds pods with Istio sidecars (port 15090)
- Scrapes `/stats/prometheus` endpoint from each sidecar
- Adds labels: `namespace`, `pod_name`, `service_name`

### 3. Access the Demo

Once pods are running, access the frontend via Istio ingress gateway:

```bash
# Get the gateway URL
GATEWAY_URL=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Access the frontend
curl http://$GATEWAY_URL
```

Or use the ELB directly:
```
http://a34e57a1901f042e8a7cf2383a4beeec-1559479130.us-east-1.elb.amazonaws.com
```

## Resource Constraints

The cluster is currently at **99% memory allocation**. To free up resources:

### Option 1: Scale Down Other Workloads
```bash
# Check what's using resources
kubectl top pods --all-namespaces --sort-by=memory

# Scale down if needed
kubectl scale deployment <name> --replicas=0 -n <namespace>
```

### Option 2: Scale Down Demo Components
```bash
# Scale down heavy components
kubectl scale deployment grafana --replicas=0 -n otel-demo
kubectl scale deployment prometheus --replicas=0 -n otel-demo
kubectl scale statefulset opensearch --replicas=0 -n otel-demo
```

### Option 3: Add More Nodes
```bash
# Add nodes to your EKS cluster
eksctl scale nodegroup --cluster=psimkins-test --name=<nodegroup-name> --nodes=3
```

## Verify Metrics Collection

Once services are running with Istio sidecars:

```bash
# Check collector logs for discovered targets
kubectl logs -l app=otel-collector -n default | grep -i "target\|scrape"

# Check if metrics are flowing to Elastic
# Use MCP to query: metrics-apm.app.istio_gateways-default
# You should see metrics from:
# - istio-system namespace (gateway)
# - otel-demo namespace (demo services)
# - default namespace (any other services)
```

## Expected Services

Once the demo is fully running, you should see these services with Istio sidecars:

- `frontend` - Main UI
- `frontend-proxy` - Frontend proxy
- `product-catalog` - Product catalog service
- `cart` - Shopping cart
- `checkout` - Checkout service
- `payment` - Payment service
- `shipping` - Shipping service
- `recommendation` - Recommendation service
- `ad` - Ad service
- `email` - Email service
- `currency` - Currency conversion
- `quote` - Quote service
- `fraud-detection` - Fraud detection
- `load-generator` - Load generator

Each will have an Istio sidecar (Envoy proxy) that exposes Prometheus metrics on port 15090.

## Next Steps

1. **Wait for pods to start** (may need to free up resources first)
2. **Verify sidecars are injected**: `kubectl get pods -n otel-demo -o jsonpath='{.items[*].spec.containers[*].name}'`
3. **Check metrics in Elastic**: Query `metrics-apm.app.istio_gateways-default` data stream
4. **Access the frontend**: Use the Istio ingress gateway URL
5. **Generate traffic**: Use the load-generator or the traffic generator workflow

## Troubleshooting

### Pods Not Starting
```bash
# Check why pods are pending
kubectl describe pod <pod-name> -n otel-demo

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### No Metrics Appearing
```bash
# Verify sidecars are running
kubectl get pods -n otel-demo -o jsonpath='{.items[*].spec.containers[*].name}'

# Check collector is discovering targets
kubectl logs -l app=otel-collector -n default | grep -i "kubernetes\|target"

# Test sidecar metrics endpoint
kubectl exec -n otel-demo <pod-name> -c istio-proxy -- curl localhost:15090/stats/prometheus | head
```

### Gateway Not Accessible
```bash
# Check gateway status
kubectl get gateway -n otel-demo
kubectl get virtualservice -n otel-demo

# Test gateway connectivity
curl -v http://<gateway-url>/
```

