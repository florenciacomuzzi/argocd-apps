# ArgoCD Bootstrap Applications

This directory contains bootstrap applications that need to be applied manually to break circular dependencies.

## Bootstrap Process

### Step 1: Create Manual Repository Credentials

There's a circular dependency: ArgoCD needs GitLab credentials to read this repository, but the instructions to create those credentials are IN the repository!

First, create temporary manual credentials:

```bash
# Get your GitLab token from Google Secret Manager (or use your personal access token)
export GITLAB_TOKEN=$(gcloud secrets versions access latest --secret=gitlab-token --project=development-454916)

# Create the secret with the token
sed "s/<GITLAB_TOKEN>/$GITLAB_TOKEN/g" bootstrap/argocd-apps-repo-manual-secret.yaml | kubectl apply -f -
```

### Step 2: Apply the Bootstrap Application

Now ArgoCD can read the repository and create the permanent credentials:

```bash
kubectl apply -f bootstrap/argocd-bootstrap-app.yaml
```

This will:
1. Create the SecretStore for Google Secret Manager
2. Create ExternalSecrets that pull credentials from GCP
3. Create permanent repository credentials that replace the manual ones

### Step 3: Verify Bootstrap Success

Check that all bootstrap components are synced:

```bash
kubectl get applications -n argocd | grep bootstrap
```

### Step 4: Apply Root Applications

Once bootstrap is complete, apply the environment-specific root applications:

```bash
# For development
kubectl apply -f root/blueberry-root-dev.yaml
```

### Files in this Directory

- **argocd-apps-repo-manual-secret.yaml** - Template for manual bootstrap credentials
- **argocd-bootstrap-app.yaml** - Main bootstrap application
- **gitlab-secrets-bootstrap.yaml** - Creates External Secrets infrastructure
- **argocd-repos-bootstrap.yaml** - Creates permanent repository credentials
- **kustomization.yaml** - Bundles bootstrap resources
