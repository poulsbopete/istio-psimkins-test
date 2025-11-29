# Customer Walkthrough: Istio + OpenTelemetry Collector on EKS

## Overview

This walkthrough will guide you through setting up a complete observability solution for your Kubernetes cluster running Istio service mesh, using OpenTelemetry Collector to collect metrics, traces, and logs, and sending them to Elastic Cloud.

### What You'll Achieve

By the end of this setup, you will have:
- ✅ **Prometheus metrics** scraped from Istio gateways and services
- ✅ **Kubernetes host-level metrics** collected
- ✅ **Istio service mesh metrics** (requests, duration, etc.)
- ✅ **Distributed traces** from Istio sidecars
- ✅ **Application logs** collected and forwarded
- ✅ **Secure credential management** using AWS Secrets Manager

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster (EKS)                 │
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐ │
│  │   App Pods   │    │   App Pods   │    │   App Pods   │ │
│  │ + Istio      │    │ + Istio      │    │ + Istio      │ │
│  │   Sidecars   │    │   Sidecars   │    │   Sidecars   │ │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘ │
│         │                   │                   │          │
│         └───────────────────┼───────────────────┘          │
│                              │                               │
│         ┌─────────────────────▼─────────────────────┐         │
│         │     Istio Ingress/Egress Gateways      │         │
│         │     (Prometheus metrics on :15090)     │         │
│         └─────────────────────┬───────────────────┘         │
│                               │                               │
│         ┌─────────────────────▼─────────────────────┐         │
│         │   OpenTelemetry Collector (DaemonSet)  │         │
│         │   - OTLP Receiver (traces/logs)        │         │
│         │   - Prometheus Receiver (metrics)       │         │
│         │   - K8s Attributes Processor            │         │
│         └─────────────────────┬───────────────────┘         │
│                               │                               │
└───────────────────────────────┼───────────────────────────────┘
                                │
                                │ (HTTPS with API Key)
                                ▼
                    ┌───────────────────────────┐
                    │    Elastic Cloud          │
                    │  (Observability Platform) │
                    └───────────────────────────┘
```

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS account with appropriate permissions
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] `kubectl` installed
- [ ] `eksctl` installed (for EKS cluster creation)
- [ ] Access to an EKS cluster OR ability to create one
- [ ] Elastic Cloud account with:
  - [ ] Deployment endpoint URL
  - [ ] API key with write permissions
- [ ] Istio installed in your cluster (or we'll install it)

## Step-by-Step Setup

### Step 1: Prepare Your Environment

#### 1.1 Clone or Download the Configuration

```bash
git clone git@github.com:poulsbopete/istio-psimkins-test.git
cd istio-psimkins-test
```

#### 1.2 Verify Prerequisites

```bash
# Check AWS CLI
aws --version
aws sts get-caller-identity

# Check kubectl
kubectl version --client

# Check eksctl (if creating cluster)
eksctl version
```

### Step 2: Create or Connect to EKS Cluster

#### Option A: Create New EKS Cluster

```bash
./create-eks-cluster.sh psimkins-test us-east-1
```

**What this does:**
- Creates EKS cluster with Kubernetes 1.29
- Sets up managed node groups (2x t3.medium instances)
- Enables OIDC provider (required for IRSA)
- Configures full ECR access

**Time:** 10-15 minutes

**Monitor progress:**
```bash
./check-cluster-status.sh psimkins-test
```

#### Option B: Use Existing Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --name YOUR_CLUSTER_NAME --region us-east-1

# Verify connection
kubectl get nodes
```

### Step 3: Install Istio (If Not Already Installed)

If Istio is not installed, install it:

```bash
# Download Istio (if not already present)
# The istioctl binary is in the bin/ directory
export PATH=$PATH:$(pwd)/bin

# Install Istio
istioctl install --set profile=default -y

# Verify installation
kubectl get pods -n istio-system
```

**Expected output:** You should see `istiod`, `istio-ingressgateway`, and `istio-egressgateway` pods running.

### Step 4: Set Up AWS Secrets Manager

#### 4.1 Create the Secret

You'll need your Elastic Cloud endpoint and API key. Store them securely:

```bash
# Set your Elastic credentials as environment variables
export ELASTIC_ENDPOINT="https://your-deployment.ingest.us-east-1.aws.elastic.cloud:443"
export ELASTIC_API_KEY="your-api-key-here"

# Create the secret in AWS Secrets Manager
./setup-aws-secrets.sh istio/otel-collector/elastic us-east-1
```

**What this does:**
- Creates a secret in AWS Secrets Manager
- Stores endpoint and API key in JSON format
- Makes it accessible to the OpenTelemetry Collector via IRSA

**Security Note:** Never commit these values to Git. They're stored securely in AWS Secrets Manager.

#### 4.2 Verify Secret Creation

```bash
aws secretsmanager describe-secret \
  --secret-id istio/otel-collector/elastic \
  --region us-east-1
```

### Step 5: Set Up IAM Roles for Service Accounts (IRSA)

This allows the OpenTelemetry Collector to access AWS Secrets Manager without storing credentials.

```bash
./setup-eks-deployment.sh psimkins-test us-east-1
```

**What this does:**
1. Creates IAM policy for Secrets Manager access
2. Creates IAM role with trust relationship for the service account
3. Annotates the service account with the IAM role ARN

**Verify:**
```bash
kubectl get serviceaccount otel-collector -n default -o yaml | grep eks.amazonaws.com/role-arn
```

You should see the IAM role ARN annotation.

### Step 6: Configure Prometheus Scraping

#### 6.1 Update Istio Gateway Targets

The OpenTelemetry Collector needs to know where to scrape Prometheus metrics from Istio gateways.

**Find your Istio gateway pod IPs:**

```bash
# Get ingress gateway pod IP
INGRESS_IP=$(kubectl get pod -n istio-system -l app=istio-ingressgateway -o jsonpath='{.items[0].status.podIP}')
echo "Ingress Gateway IP: $INGRESS_IP"

# Get egress gateway pod IP (if exists)
EGRESS_IP=$(kubectl get pod -n istio-system -l app=istio-egressgateway -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || echo "")
echo "Egress Gateway IP: $EGRESS_IP"
```

#### 6.2 Update Collector Configuration

Edit `otel-collector-config.yaml` and update the Prometheus scrape targets:

```yaml
prometheus:
  config:
    scrape_configs:
      - job_name: 'istio-gateways'
        static_configs:
          - targets:
              - "${INGRESS_IP}:15090"   # Replace with your ingress gateway IP
              - "${EGRESS_IP}:15090"    # Replace with your egress gateway IP (if exists)
        metrics_path: /stats/prometheus
```

**Better approach:** Use Kubernetes service discovery instead of static IPs:

```yaml
prometheus:
  config:
    scrape_configs:
      - job_name: 'istio-ingressgateway'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - istio-system
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: istio-ingressgateway
          - source_labels: [__meta_kubernetes_pod_ip]
            action: replace
            target_label: __address__
            replacement: ${1}:15090
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: instance
        metrics_path: /stats/prometheus
      
      - job_name: 'istio-egressgateway'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - istio-system
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: istio-egressgateway
          - source_labels: [__meta_kubernetes_pod_ip]
            action: replace
            target_label: __address__
            replacement: ${1}:15090
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: instance
        metrics_path: /stats/prometheus
```

### Step 7: Deploy OpenTelemetry Collector

#### 7.1 Apply RBAC Configuration

```bash
kubectl apply -f otel-rbac.yaml
```

**What this creates:**
- Service account with IRSA annotation
- ClusterRole with permissions to read pods, nodes, endpoints
- ClusterRoleBinding linking service account to role

#### 7.2 Apply Collector Configuration

```bash
kubectl apply -f otel-collector-config.yaml
```

**What this creates:**
- ConfigMap with OpenTelemetry Collector configuration
- Defines receivers, processors, and exporters

#### 7.3 Deploy the Collector

```bash
kubectl apply -f otel-collector.yaml
```

**What this creates:**
- DaemonSet that runs one collector pod per node
- Init container that fetches secrets from AWS Secrets Manager
- Main container that runs the collector

### Step 8: Verify Deployment

#### 8.1 Check Pod Status

```bash
kubectl get pods -l app=otel-collector
```

**Expected output:**
```
NAME                   READY   STATUS    RESTARTS   AGE
otel-collector-xxxxx   1/1     Running   0          2m
```

#### 8.2 Check Init Container Logs

```bash
kubectl logs -l app=otel-collector -c fetch-secrets
```

**Expected output:**
```
Fetching secret from AWS Secrets Manager: istio/otel-collector/elastic
Secrets fetched and written successfully
```

#### 8.3 Check Collector Logs

```bash
kubectl logs -l app=otel-collector -c otel-collector --tail=50
```

**Look for:**
- No error messages
- "Everything is ready. Begin running and processing data."
- Export logs showing data being sent to Elastic

#### 8.4 Verify Environment Variables

```bash
kubectl exec -it $(kubectl get pod -l app=otel-collector -o jsonpath='{.items[0].metadata.name}') -- env | grep ELASTIC
```

**Expected output:**
```
ELASTIC_ENDPOINT=https://your-endpoint.ingest.us-east-1.aws.elastic.cloud:443
ELASTIC_API_KEY=your-api-key
```

### Step 9: Configure Istio Telemetry

To ensure Istio sends traces and metrics to the OpenTelemetry Collector, configure Istio's Telemetry API:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: otel-collector
  namespace: istio-system
spec:
  providers:
    - name: otel
EOF
```

**For application-level telemetry:**

```bash
cat <<EOF | kubectl apply -f -
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

### Step 10: Enable Prometheus Annotations (Optional)

If you want to scrape additional Prometheus metrics from your application pods, add annotations:

```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

The OpenTelemetry Collector's Prometheus receiver can discover these automatically with Kubernetes service discovery.

## Troubleshooting Common Issues

### Issue 1: Missing Prometheus Metrics from Istio

**Symptoms:**
- No `istio_requests_total` metrics
- No `istio_request_duration_milliseconds_*` metrics

**Solutions:**

1. **Verify Istio gateways are running:**
   ```bash
   kubectl get pods -n istio-system
   ```

2. **Check if metrics endpoint is accessible:**
   ```bash
   kubectl exec -it -n istio-system $(kubectl get pod -n istio-system -l app=istio-ingressgateway -o jsonpath='{.items[0].metadata.name}') -- curl localhost:15090/stats/prometheus | head -20
   ```

3. **Verify Prometheus receiver configuration:**
   - Check `otel-collector-config.yaml` has correct scrape targets
   - Ensure service discovery is configured correctly

4. **Check collector logs for scraping errors:**
   ```bash
   kubectl logs -l app=otel-collector -c otel-collector | grep -i prometheus
   ```

### Issue 2: Missing Kubernetes Host-Level Metrics

**Symptoms:**
- No node CPU/memory metrics
- No pod resource usage metrics

**Solutions:**

1. **Enable host metrics receiver:**
   Add to `otel-collector-config.yaml`:
   ```yaml
   receivers:
     hostmetrics:
       collection_interval: 10s
       scrapers:
         cpu:
         disk:
         load:
         filesystem:
         memory:
         network:
         paging:
         process:
   ```

2. **Add to metrics pipeline:**
   ```yaml
   service:
     pipelines:
       metrics:
         receivers: [prometheus, hostmetrics, otlp]
         processors: [memory_limiter, k8sattributes, batch]
         exporters: [otlphttp/elastic]
   ```

3. **Redeploy:**
   ```bash
   kubectl apply -f otel-collector-config.yaml
   kubectl rollout restart daemonset/otel-collector
   ```

### Issue 3: Missing Traces

**Symptoms:**
- No traces appearing in Elastic
- Traces not being collected

**Solutions:**

1. **Verify Istio telemetry configuration:**
   ```bash
   kubectl get telemetry -A
   ```

2. **Check if applications are instrumented:**
   - Ensure applications send traces via OTLP
   - Verify Istio sidecars are injecting traces

3. **Verify OTLP receiver:**
   ```bash
   kubectl logs -l app=otel-collector -c otel-collector | grep -i otlp
   ```

4. **Test trace generation:**
   ```bash
   # Send a test request through Istio
   kubectl exec -it -n default $(kubectl get pod -n default -l app=sleep -o jsonpath='{.items[0].metadata.name}') -- curl http://httpbin.default:8000/headers
   ```

### Issue 4: Init Container Fails

**Symptoms:**
- Pod stuck in `Init:0/1` status
- Init container logs show authentication errors

**Solutions:**

1. **Verify IAM role annotation:**
   ```bash
   kubectl get serviceaccount otel-collector -o yaml | grep eks.amazonaws.com/role-arn
   ```

2. **Check IAM role permissions:**
   ```bash
   aws iam get-role-policy --role-name otel-collector-secrets-role --policy-name OtelCollectorSecretsPolicy
   ```

3. **Verify secret exists:**
   ```bash
   aws secretsmanager describe-secret --secret-id istio/otel-collector/elastic
   ```

4. **Check OIDC provider:**
   ```bash
   aws eks describe-cluster --name psimkins-test --query 'cluster.identity.oidc.issuer'
   ```

### Issue 5: Collector Can't Connect to Elastic

**Symptoms:**
- Collector logs show connection errors
- Data not appearing in Elastic

**Solutions:**

1. **Verify endpoint and API key:**
   ```bash
   kubectl exec -it $(kubectl get pod -l app=otel-collector -o jsonpath='{.items[0].metadata.name}') -- env | grep ELASTIC
   ```

2. **Test connectivity from collector pod:**
   ```bash
   kubectl exec -it $(kubectl get pod -l app=otel-collector -o jsonpath='{.items[0].metadata.name}') -- curl -v -H "Authorization: ApiKey $ELASTIC_API_KEY" $ELASTIC_ENDPOINT
   ```

3. **Check Elastic API key permissions:**
   - Ensure API key has write permissions
   - Verify API key hasn't expired

## Verification Checklist

After setup, verify everything is working:

- [ ] OpenTelemetry Collector pods are running
- [ ] Init container successfully fetched secrets
- [ ] Collector logs show no errors
- [ ] Environment variables are set correctly
- [ ] Istio gateways are running
- [ ] Prometheus metrics are being scraped
- [ ] Data appears in Elastic Cloud:
  - [ ] Metrics (check Metrics app in Kibana)
  - [ ] Traces (check APM app in Kibana)
  - [ ] Logs (check Logs app in Kibana)

## Next Steps

1. **Configure Dashboards:**
   - Import Elastic's OpenTelemetry dashboards
   - Create custom dashboards for your applications

2. **Set Up Alerts:**
   - Configure alerting rules in Elastic
   - Set up notifications for critical metrics

3. **Optimize Collection:**
   - Adjust scrape intervals based on needs
   - Configure sampling for traces if needed
   - Set up log filtering and processing

4. **Scale as Needed:**
   - Monitor collector resource usage
   - Adjust DaemonSet resource limits if needed

## Support and Resources

- **Repository:** https://github.com/poulsbopete/istio-psimkins-test
- **Istio Documentation:** https://istio.io/latest/docs/
- **OpenTelemetry Documentation:** https://opentelemetry.io/docs/
- **Elastic OpenTelemetry Guide:** https://www.elastic.co/guide/en/observability/current/ingest-opentelemetry.html

## Summary

You've successfully set up:
- ✅ OpenTelemetry Collector collecting from Istio
- ✅ Prometheus metrics scraping from Istio gateways
- ✅ Secure credential management via AWS Secrets Manager
- ✅ Integration with Elastic Cloud for observability

Your observability pipeline is now complete and ready to collect metrics, traces, and logs from your Istio-enabled Kubernetes cluster!

