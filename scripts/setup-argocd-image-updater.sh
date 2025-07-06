#!/bin/bash
set -e

# Script to set up ArgoCD Image Updater authentication
# This script needs to be run after deploying ArgoCD and the Image Updater

echo "======================================"
echo "ArgoCD Image Updater Setup Script"
echo "======================================"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if argocd CLI is available
if ! command -v argocd &> /dev/null; then
    echo "❌ argocd CLI is not installed."
    echo "📦 Install with: brew install argocd"
    exit 1
fi

# Check if we're connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Not connected to a Kubernetes cluster. Please configure kubectl."
    exit 1
fi

# Check if ArgoCD is installed
if ! kubectl get deployment argocd-server -n argocd &> /dev/null; then
    echo "❌ ArgoCD server not found. Please deploy ArgoCD first."
    exit 1
fi

# Check if image updater is installed
if ! kubectl get deployment argocd-image-updater -n argocd &> /dev/null; then
    echo "❌ ArgoCD Image Updater not found. Please deploy it first."
    exit 1
fi

# Check if token already exists
if kubectl get secret argocd-image-updater-secret -n argocd &> /dev/null; then
    EXISTING_TOKEN=$(kubectl get secret argocd-image-updater-secret -n argocd -o jsonpath='{.data.argocd\.token}' | base64 -d 2>/dev/null || echo "")
    if [ -n "$EXISTING_TOKEN" ]; then
        echo "✅ ArgoCD Image Updater token already configured!"
        echo ""
        echo "To verify it's working, check the logs:"
        echo "kubectl logs -n argocd deployment/argocd-image-updater --tail=20"
        exit 0
    fi
fi

echo "🔐 Setting up ArgoCD Image Updater authentication..."
echo ""

# Get ArgoCD admin password
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
if [ -z "$ADMIN_PASSWORD" ]; then
    echo "❌ Could not retrieve ArgoCD admin password."
    exit 1
fi

echo "📡 Port-forwarding to ArgoCD server..."
# Kill any existing port-forward
pkill -f "kubectl port-forward.*argocd-server.*8082" 2>/dev/null || true
kubectl port-forward svc/argocd-server -n argocd 8082:80 > /dev/null 2>&1 &
PF_PID=$!
sleep 5

# Login to ArgoCD
echo "🔑 Logging in to ArgoCD..."
if ! echo "y" | argocd login localhost:8082 --username admin --password "$ADMIN_PASSWORD" --insecure; then
    echo "❌ Failed to login to ArgoCD. Admin account might be disabled."
    echo "   Run: kubectl patch cm argocd-cm -n argocd -p '{\"data\":{\"admin.enabled\":\"true\"}}'"
    echo "   Then restart: kubectl rollout restart deployment argocd-server -n argocd"
    kill $PF_PID 2>/dev/null || true
    exit 1
fi

# Generate token for image-updater account
echo "🎫 Generating token for image-updater account..."
TOKEN=$(argocd account generate-token --account image-updater 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to generate token. The image-updater account might not exist."
    echo "   This should have been created by Terraform. Check the ArgoCD configuration."
    kill $PF_PID 2>/dev/null || true
    exit 1
fi

# Create or update the secret
echo "💾 Storing token in Kubernetes secret..."
kubectl create secret generic argocd-image-updater-secret \
    -n argocd \
    --from-literal=argocd.token="$TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

# Restart image updater to pick up the new token
echo "🔄 Restarting ArgoCD Image Updater..."
kubectl rollout restart deployment argocd-image-updater -n argocd

# Clean up port-forward
kill $PF_PID 2>/dev/null || true

echo ""
echo "✅ ArgoCD Image Updater authentication configured successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Wait ~30 seconds for the pod to restart"
echo "2. Check the logs to verify it's working:"
echo "   kubectl logs -n argocd deployment/argocd-image-updater --tail=20"
echo ""
echo "🔍 Look for:"
echo "   - 'Starting image update cycle, considering X annotated application(s)'"
echo "   - No authentication errors"
echo ""
echo "📝 The Image Updater will check for new images every 2 minutes."