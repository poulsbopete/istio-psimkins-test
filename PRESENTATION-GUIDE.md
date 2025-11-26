# Presentation Guide: Explaining the Setup to Customers

## Quick Overview (2-minute pitch)

**Problem:** Customer needs comprehensive observability for their Kubernetes + Istio environment, but is missing:
- Prometheus metrics from Istio
- Kubernetes host-level metrics
- Distributed traces
- Secure credential management

**Solution:** OpenTelemetry Collector on EKS with AWS Secrets Manager integration, sending to Elastic Cloud.

**Key Benefits:**
- ✅ All telemetry in one place (Elastic Cloud)
- ✅ Secure (credentials in AWS Secrets Manager, not Git)
- ✅ Scalable (DaemonSet runs on every node)
- ✅ Production-ready (IRSA, proper RBAC, error handling)

## Presentation Structure

### 1. The Problem (5 minutes)

**What the customer is experiencing:**
- Missing Prometheus metrics (`istio_requests_total`, etc.)
- No Kubernetes host metrics
- Missing traces
- Security concerns with credentials in Git

**Why it matters:**
- Can't monitor service health
- Can't debug performance issues
- Can't trace requests across services
- Security risk with exposed credentials

### 2. The Solution Architecture (10 minutes)

**Show the architecture diagram** (from CUSTOMER-WALKTHROUGH.md)

**Key components:**
1. **OpenTelemetry Collector (DaemonSet)**
   - Runs on every node
   - Collects metrics, traces, logs
   - Uses init container to fetch secrets securely

2. **AWS Secrets Manager**
   - Stores Elastic endpoint and API key
   - Accessed via IRSA (no credentials in pods)
   - Rotatable and auditable

3. **Elastic Cloud**
   - Centralized observability platform
   - Dashboards, alerts, analysis
   - Single source of truth

**Data flow:**
```
Applications → Istio Sidecars → OTEL Collector → Elastic Cloud
                    ↓
            Prometheus Metrics
```

### 3. Security Highlights (5 minutes)

**Why this approach is secure:**
- ✅ No secrets in Git (all in AWS Secrets Manager)
- ✅ IRSA for authentication (no static credentials)
- ✅ Least privilege IAM policies
- ✅ Secrets fetched at runtime, not stored in pods

**Show the .gitignore file:**
- Demonstrates what we're NOT committing
- Shows security-first approach

### 4. Setup Process Overview (10 minutes)

**Walk through the key steps:**

1. **Prerequisites** (2 min)
   - AWS account, EKS cluster, Elastic Cloud
   - Tools: kubectl, eksctl, AWS CLI

2. **Create Secret** (1 min)
   ```bash
   export ELASTIC_ENDPOINT="..."
   export ELASTIC_API_KEY="..."
   ./setup-aws-secrets.sh
   ```

3. **Set Up IRSA** (2 min)
   ```bash
   ./setup-eks-deployment.sh
   ```
   - Creates IAM role
   - Annotates service account
   - No manual credential management

4. **Deploy Collector** (2 min)
   ```bash
   kubectl apply -f otel-rbac.yaml
   kubectl apply -f otel-collector-config.yaml
   kubectl apply -f otel-collector.yaml
   ```

5. **Verify** (3 min)
   - Check pods running
   - Verify secrets fetched
   - Confirm data in Elastic

### 5. Addressing Specific Issues (10 minutes)

#### Issue 1: Missing Prometheus Metrics

**Root cause:** Collector not configured to scrape Istio gateways

**Solution:**
- Update `otel-collector-config.yaml` with correct scrape targets
- Use Kubernetes service discovery (better than static IPs)
- Show the configuration snippet

**Demo:**
```bash
# Show current config
kubectl get configmap otel-collector-config -o yaml

# Show Istio gateway metrics endpoint
kubectl exec -it istio-ingressgateway-xxx -n istio-system -- curl localhost:15090/stats/prometheus | head
```

#### Issue 2: Missing Kubernetes Host Metrics

**Root cause:** Host metrics receiver not enabled

**Solution:**
- Add `hostmetrics` receiver to config
- Enable CPU, memory, disk, network scrapers
- Add to metrics pipeline

**Show the config change:**
```yaml
receivers:
  hostmetrics:
    collection_interval: 10s
    scrapers:
      cpu:
      memory:
      disk:
      network:
```

#### Issue 3: Missing Traces

**Root cause:** Istio not configured to send traces to collector

**Solution:**
- Create Telemetry API resource
- Configure OTLP provider
- Verify sidecar injection

**Show the Telemetry resource:**
```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
spec:
  providers:
    - name: otel
```

### 6. Troubleshooting Guide (5 minutes)

**Common issues and quick fixes:**

1. **Init container fails**
   - Check IAM role annotation
   - Verify secret exists
   - Check OIDC provider

2. **No metrics in Elastic**
   - Verify endpoint/API key
   - Check collector logs
   - Test connectivity

3. **Missing Istio metrics**
   - Verify gateways running
   - Check scrape config
   - Test metrics endpoint

**Show troubleshooting commands:**
```bash
# Quick health check script
kubectl get pods -l app=otel-collector
kubectl logs -l app=otel-collector -c fetch-secrets
kubectl logs -l app=otel-collector -c otel-collector --tail=50
```

### 7. Q&A Preparation

**Anticipated questions:**

**Q: How do we rotate the API key?**
A: Update the secret in AWS Secrets Manager, collector will pick it up on next restart (or use secret rotation)

**Q: What about performance impact?**
A: Collector is lightweight, runs as DaemonSet, resource limits configured

**Q: Can we use this for other clusters?**
A: Yes, same setup works for any EKS cluster, just update cluster name

**Q: What if we're not on EKS?**
A: Use `otel-collector-non-eks.yaml` and create AWS credentials secret

**Q: How do we add more scrape targets?**
A: Update Prometheus receiver config in `otel-collector-config.yaml`

**Q: Can we filter or transform data?**
A: Yes, add processors in the pipeline (filter, transform, etc.)

## Demo Script (15 minutes)

### Pre-demo Setup
1. Have EKS cluster ready
2. Have Elastic Cloud credentials ready
3. Have Istio installed
4. Pre-run setup scripts (or show they're ready)

### Demo Flow

1. **Show current state** (2 min)
   ```bash
   # Show no collector running
   kubectl get pods -l app=otel-collector
   
   # Show missing metrics in Elastic (if possible)
   ```

2. **Run setup** (5 min)
   ```bash
   # Create secret
   ./setup-aws-secrets.sh
   
   # Set up IRSA
   ./setup-eks-deployment.sh
   
   # Deploy
   kubectl apply -f otel-*.yaml
   ```

3. **Verify** (3 min)
   ```bash
   # Show pods running
   kubectl get pods -l app=otel-collector
   
   # Show logs
   kubectl logs -l app=otel-collector -c fetch-secrets
   kubectl logs -l app=otel-collector -c otel-collector
   ```

4. **Show results** (5 min)
   - Show metrics appearing in Elastic
   - Show traces in Elastic
   - Show logs in Elastic
   - Show dashboards

## Key Talking Points

### Security
- "We never store credentials in Git - everything goes through AWS Secrets Manager"
- "IRSA means no static credentials in pods - authentication happens automatically"
- "IAM policies follow least privilege - only access to the specific secret needed"

### Scalability
- "DaemonSet means one collector per node - automatically scales with your cluster"
- "Resource limits prevent collector from impacting workloads"
- "Batch processing reduces overhead"

### Maintainability
- "All configuration in Git (except secrets)"
- "Easy to update - just modify YAML and apply"
- "Scripts automate common tasks"

### Observability
- "Single collector handles metrics, traces, and logs"
- "Kubernetes attributes automatically added to all telemetry"
- "Elastic provides unified view across all data"

## Closing

**Summary:**
- Secure, scalable observability solution
- Production-ready with proper security practices
- Addresses all the issues you mentioned
- Easy to maintain and extend

**Next steps:**
1. Review the walkthrough document
2. Try the setup in your environment
3. Customize configuration for your needs
4. Set up dashboards and alerts

**Resources:**
- Full walkthrough: `CUSTOMER-WALKTHROUGH.md`
- Repository: https://github.com/poulsbopete/istio-psimkins-test
- Support: [Your contact information]

