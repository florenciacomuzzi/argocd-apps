#!/bin/bash
# Bootstrap ArgoCD with GitLab credentials

set -e

echo "🚀 Starting ArgoCD Bootstrap Process..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud is not installed or not in PATH"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "bootstrap/argocd-bootstrap-app.yaml" ]; then
    echo "❌ Please run this script from the argocd-apps root directory"
    exit 1
fi

echo "📥 Fetching GitLab token from Google Secret Manager..."
GITLAB_TOKEN=$(gcloud secrets versions access latest --secret=gitlab-token --project=development-454916)

if [ -z "$GITLAB_TOKEN" ]; then
    echo "❌ Failed to fetch GitLab token from Google Secret Manager"
    exit 1
fi

echo "🔑 Creating temporary repository credentials..."
sed "s/<GITLAB_TOKEN>/$GITLAB_TOKEN/g" bootstrap/argocd-apps-repo-manual-secret.yaml | kubectl apply -f -

echo "⏳ Waiting for secret to be created..."
sleep 5

echo "🎯 Applying bootstrap application..."
kubectl apply -f bootstrap/argocd-bootstrap-app.yaml

echo "⏳ Waiting for bootstrap to start..."
sleep 10

echo "📊 Checking bootstrap status..."
kubectl get applications -n argocd | grep bootstrap

echo "✅ Bootstrap process initiated!"
echo ""
echo "Next steps:"
echo "1. Wait for bootstrap applications to sync: kubectl get applications -n argocd"
echo "2. Once synced, apply root application: kubectl apply -f root/blueberry-root-dev.yaml"
echo "3. Monitor sync status: kubectl get applications -n argocd"