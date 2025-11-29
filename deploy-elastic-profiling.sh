#!/bin/bash
# Script to deploy Elastic Universal Profiling (eBPF) agent
# Usage: ./deploy-elastic-profiling.sh

set -e

echo "🚀 Deploying Elastic Universal Profiling (eBPF) Agent"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Kubernetes cluster connection verified"
echo ""

# Deploy RBAC
echo "📋 Deploying RBAC resources..."
kubectl apply -f elastic-profiling-rbac.yaml
echo "✅ RBAC resources deployed"
echo ""

# Wait a moment for ServiceAccount to be ready
sleep 2

# Deploy Profiling Agent
echo "📦 Deploying Elastic Profiling Agent DaemonSet..."
kubectl apply -f elastic-profiling-agent.yaml
echo "✅ Profiling Agent DaemonSet deployed"
echo ""

# Wait for pods to start
echo "⏳ Waiting for pods to start..."
sleep 5

# Check pod status
echo "📊 Checking pod status..."
kubectl get pods -l app=elastic-profiling-agent -n default

echo ""
echo "🔍 Checking pod logs (last 20 lines)..."
POD_NAME=$(kubectl get pods -l app=elastic-profiling-agent -n default -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$POD_NAME" ]; then
    echo "Pod: $POD_NAME"
    kubectl logs "$POD_NAME" -n default --tail=20 || echo "⚠️  Could not retrieve logs yet"
else
    echo "⚠️  No pods found yet. They may still be starting."
fi

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Check pod status: kubectl get pods -l app=elastic-profiling-agent"
echo "   2. View logs: kubectl logs -l app=elastic-profiling-agent -n default"
echo "   3. Access Elastic Cloud > Observability > Universal Profiling"
echo ""
echo "🔗 Useful commands:"
echo "   # View all profiling agent pods"
echo "   kubectl get pods -l app=elastic-profiling-agent -A"
echo ""
echo "   # Check logs for errors"
echo "   kubectl logs -l app=elastic-profiling-agent -n default | grep -i error"
echo ""
echo "   # Verify ConfigMap with credentials"
echo "   kubectl get configmap elastic-profiling-env -n default"
echo ""

