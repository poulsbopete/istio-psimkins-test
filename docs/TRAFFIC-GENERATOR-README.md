# Istio Traffic Generator Workflows

## Overview

These One Workflow files generate HTTP traffic to your Istio ingress gateway to populate dashboards with metrics. The workflows make periodic HTTP requests that are tracked by Prometheus and visible in your Istio dashboards.

## Workflows

### 1. `generate-istio-traffic-workflow.yaml` (Simple)

**Description**: Makes 10 HTTP requests per execution to various endpoints.

**Schedule**: Runs every 30 seconds

**Features**:
- 10 different HTTP requests per execution
- Mix of GET and POST requests
- Various endpoints to generate diverse metrics
- Ignores errors (404s are fine - we just want metrics)

### 2. `generate-istio-traffic-continuous.yaml` (Continuous)

**Description**: Generates 20 requests per execution in a loop with delays.

**Schedule**: Runs every minute

**Features**:
- 20 requests per execution
- 2-second delay between requests
- Rotates through different endpoints
- More sustained traffic pattern

## Configuration

### Gateway Endpoint

Both workflows use the discovered Istio ingress gateway endpoint:
```
a34e57a1901f042e8a7cf2383a4beeec-1559479130.us-east-1.elb.amazonaws.com
```

To update the endpoint:
1. Get your gateway endpoint:
   ```bash
   kubectl get svc istio-ingressgateway -n istio-system \
     -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

2. Update the `url` fields in the workflow YAML files

### Schedule Configuration

**Simple Workflow** (every 30 seconds):
```yaml
schedule: "*/30 * * * * *"  # Cron format with seconds
```

**Continuous Workflow** (every minute):
```yaml
schedule: "*/1 * * * *"  # Standard cron format
```

## Deployment

### Option 1: Import to One Workflow

1. Copy the workflow YAML content
2. Go to your One Workflow interface
3. Create a new workflow
4. Paste the YAML content
5. Save and enable the workflow

### Option 2: Use One Workflow CLI (if available)

```bash
# Import the workflow
one-workflow import generate-istio-traffic-workflow.yaml

# Or for continuous version
one-workflow import generate-istio-traffic-continuous.yaml
```

## Expected Results

After deploying the workflow, you should see:

1. **In Prometheus Metrics** (via OpenTelemetry Collector):
   - `envoy_cluster_upstream_rq_total` increasing
   - `envoy_cluster_upstream_cx_active` showing connections
   - Request rate metrics

2. **In Your Istio Dashboard**:
   - Request Rate chart showing traffic
   - Active Connections metric showing values
   - Error rates (if any)
   - Bytes transferred

3. **Timeline**:
   - Metrics appear within 1-2 minutes
   - Data updates every scrape interval (15 seconds in your config)

## Troubleshooting

### No Traffic Appearing

1. **Check workflow execution**:
   - Verify the workflow is running
   - Check workflow execution logs
   - Ensure the schedule trigger is enabled

2. **Verify gateway endpoint**:
   ```bash
   kubectl get svc istio-ingressgateway -n istio-system
   ```

3. **Test manually**:
   ```bash
   curl -H "Host: istio-gateway.local" \
     https://a34e57a1901f042e8a7cf2383a4beeec-1559479130.us-east-1.elb.amazonaws.com
   ```

4. **Check Prometheus scraping**:
   ```bash
   kubectl logs -l app=otel-collector -n default | grep -i prometheus
   ```

### Too Much/Little Traffic

**Reduce traffic**:
- Increase schedule interval (e.g., every 5 minutes)
- Reduce request count in continuous workflow

**Increase traffic**:
- Decrease schedule interval (e.g., every 10 seconds)
- Increase request count in continuous workflow
- Use both workflows simultaneously

## Alternative: Deploy a Test Service

If you want more realistic traffic, deploy a test service behind the gateway:

```bash
# Deploy httpbin (test service)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/master/samples/httpbin/httpbin.yaml

# Create Gateway and VirtualService
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
  - "*"
  gateways:
  - httpbin-gateway
  http:
  - match:
    - uri:
        prefix: /status
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```

Then update the workflow to use `/status/200` endpoint.

## Monitoring

After deploying, monitor:

1. **Workflow executions**: Check One Workflow dashboard
2. **Gateway metrics**: Check Istio dashboard
3. **Prometheus metrics**: Check OpenTelemetry Collector logs
4. **Elastic metrics**: Query `metrics-apm.app.istio_gateways-default`

## Notes

- The workflows ignore HTTP errors (404s, etc.) - we just need to generate metrics
- Traffic generation starts immediately after deployment
- Metrics appear in dashboards within 1-2 minutes
- The gateway endpoint may change if you recreate the service - update workflows accordingly

