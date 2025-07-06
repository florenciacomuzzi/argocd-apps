# ArgoCD GitOps Repository

This repository manages Kubernetes deployments using ArgoCD and Kustomize for the Blueberry platform.

## Repository Structure

```
argocd-apps/
├── base/                         # Base Kubernetes manifests
│   ├── argocd-appproject/       # ArgoCD project configuration
│   │   ├── blueberry-project.yml
│   │   └── kustomization.yaml
│   ├── argocd-image-updater/    # Automatic image updates
│   │   ├── argocd-image-updater.yml
│   │   └── kustomization.yaml
│   ├── argocd-repos/            # Repository credentials
│   │   ├── argocd-apps-repo-externalsecret.yml
│   │   ├── argocd-apps-repo-secret.yml
│   │   └── kustomization.yaml
│   ├── blueberry/               # Main application
│   │   ├── blueberry.yml
│   │   └── kustomization.yaml
│   └── external-secrets/        # Secrets management
│       ├── external-secrets.yml
│       ├── gitlab-secrets-application.yml
│       ├── gitlab-token-secret.yml
│       ├── gitlab-token-secret_externalsecret_gitlab-token.yaml
│       ├── gitlab-token-secret_secretstore_gsm-store.yaml
│       └── kustomization.yaml
├── overlays/                    # Environment-specific patches
│   ├── dev/
│   │   ├── blueberry-values.yaml
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
├── root/                        # ArgoCD root applications
│   └── blueberry-root-dev.yaml
├── bootstrap/                   # Initial setup files
│   ├── README.md
│   ├── argocd-bootstrap-app.yaml
│   ├── argocd-repos-bootstrap.yaml
│   ├── gitlab-secrets-bootstrap.yaml
│   └── kustomization.yaml
└── scripts/                     # Utility scripts
    └── compare_dirs.py
```

## Directory Documentation

### Bootstrap Directory (`/bootstrap/`)
Contains the initial setup files required to bootstrap ArgoCD with GitLab repository access:

- **argocd-bootstrap-app.yaml**: Main bootstrap application (sync wave -100) that deploys all bootstrap resources
- **gitlab-secrets-bootstrap.yaml**: Sets up External Secrets infrastructure to pull GitLab tokens from Google Secret Manager (sync wave -10)
- **argocd-repos-bootstrap.yaml**: Creates permanent ArgoCD repository credentials after external secrets are ready (sync wave -50)
- **kustomization.yaml**: Bundles the bootstrap applications together
- **README.md**: Explains the bootstrap process and circular dependency resolution

The bootstrap process solves the chicken-and-egg problem of needing repository credentials to read the repository that contains the instructions for creating those credentials.

### Root Directory (`/root/`)
Contains ArgoCD root applications that manage entire environments:

- **blueberry-root-dev.yaml**: Root application for development environment
  - Points to `overlays/dev` path
  - Uses the `blueberry` ArgoCD project
  - Enables automated sync with prune and self-heal
  - Includes ignore differences for GKE Autopilot managed resources

### Overlays Directory (`/overlays/`)
Environment-specific configurations using Kustomize patches:

#### Development (`/overlays/dev/`)
- Includes all 5 base components (AppProject, Repos, Blueberry, External Secrets, Image Updater)
- Contains `blueberry-values.yaml` with CI/CD placeholders for dynamic updates
- Enables automated image updates and rapid iteration

#### Production (`/overlays/prod/`)
- Includes only essential components (Blueberry app and External Secrets)
- No value overrides - uses base configuration as-is
- Manual/controlled update process for stability

### Base Directory (`/base/`)
Core Kubernetes manifests and ArgoCD applications:

#### ArgoCD AppProject (`/base/argocd-appproject/`)
- Defines the `blueberry` project with access controls
- Allows specific GitLab repositories and Helm charts
- Grants admin permissions to `blueberry-admins` group

#### ArgoCD Image Updater (`/base/argocd-image-updater/`)
- Automatically updates container images from Google Artifact Registry
- Uses Helm chart v0.11.0 with Workload Identity authentication
- Configured to update images with Git SHA tags

#### ArgoCD Repository Credentials (`/base/argocd-repos/`)
- Manages GitLab repository access for ArgoCD
- Uses External Secrets to fetch GitLab token from Google Secret Manager
- Creates repository credential secrets for ArgoCD

#### Blueberry Application (`/base/blueberry/`)
- Main application deployment configuration
- Sources from Helm chart in GitLab repository
- Configured for automatic image updates with tag pattern matching
- Creates and manages the `blueberry` namespace

#### External Secrets (`/base/external-secrets/`)
- Deploys External Secrets Operator v0.9.3
- Configures Google Secret Manager integration using Workload Identity
- Creates SecretStore and ExternalSecret resources for GitLab credentials
- Foundation for all secret management (sync wave -10)

## Key Concepts

### GitOps Workflow
- All changes are made through Git commits
- ArgoCD watches this repository and automatically syncs changes to the cluster
- Environment-specific configurations are managed through Kustomize overlays

### Kustomize Structure
- **base/**: Contains the core Kubernetes manifests with placeholder values
- **overlays/**: Environment-specific patches that override base values
- **root/**: ArgoCD Application resources that point to specific overlays

### Applications

1. **Blueberry**: The main application being deployed
2. **External Secrets**: Manages secrets from GitLab
3. **ArgoCD Image Updater**: Automatically updates container images

## Working with This Repository

### Adding a New Environment
1. Create a new directory under `overlays/` (e.g., `overlays/staging/`)
2. Add a `kustomization.yaml` file that references the base and includes patches
3. Create a new root application in `root/` (e.g., `blueberry-root-staging.yaml`)

### Modifying Environment Variables
1. Update the base manifest if adding new variables
2. Add environment-specific values in the overlay's patch files
3. Update the overlay's `kustomization.yaml` if needed

### Deployment Process
Commit and push your code. It is not recommended to manually apply manifests.

If you still wish to do so,
```bash
# Deploy to development
kubectl apply -f root/blueberry-root-dev.yaml

# Deploy to production
kubectl apply -f root/blueberry-root-prod.yaml
```

## Ephemeral Environments

The Blueberry IDP creates ephemeral environments that:
- Get their own namespace
- Deploy their own Ingress resources
- Use shared static IPs configured by Terraform:
  - Dev: `blueberry-dev-cluster-ephemeral-ip`
  - Staging: `blueberry-staging-cluster-ephemeral-ip`
  - Prod: `blueberry-prod-cluster-ephemeral-ip`

## Best Practices

1. **Never edit files in the cluster directly** - All changes must go through Git
2. **Test in dev first** - Always deploy to development before production
3. **Use meaningful commit messages** - ArgoCD shows these in the UI
4. **Keep secrets in External Secrets** - Never commit secrets to Git
5. **Follow the existing structure** - Maintain consistency with base/overlay pattern

## Common Tasks

### Update an Image Tag
1. Modify the image tag in the base application or use ArgoCD Image Updater
2. Commit and push the change
3. ArgoCD will automatically sync

### Add a New ConfigMap
1. Create the ConfigMap in `base/blueberry/`
2. Reference it in `base/blueberry/kustomization.yaml`
3. Add any environment-specific patches in the overlays

### Debug a Failed Sync
1. Check ArgoCD UI for sync status
2. Review the Git commit that triggered the sync
3. Validate YAML syntax with `kubectl --dry-run=client`
4. Check Kustomize output with `kustomize build overlays/dev/`

## Sync Wave Order

Components deploy in this order based on sync waves:
1. External Secrets Operator (wave -10)
2. GitLab Secrets & Image Updater (wave -5)
3. Repository credentials (wave -50 in bootstrap)
4. Main Blueberry application (wave 10)

This ensures proper dependency resolution during deployment.