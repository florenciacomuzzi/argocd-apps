# ArgoCD Applications with Kustomize Overlays

This directory contains ArgoCD application definitions organized using Kustomize overlays to handle environment-specific configurations.

## Directory Structure

```
argocd-apps/
├── base/                         # Base application definitions
│   ├── blueberry/               # Blueberry application
│   │   ├── blueberry.yml
│   │   └── kustomization.yaml
│   └── external-secrets/        # External Secrets Operator
│       ├── external-secrets.yml
│       ├── gitlab-secrets-application.yml
│       ├── gitlab-token-secret.yml
│       └── kustomization.yaml
├── overlays/                    # Environment-specific patches
│   ├── dev/                    # Development environment
│   │   └── kustomization.yaml
│   ├── prod/                   # Production environment
│   │   └── kustomization.yaml
│   └── staging/                # Staging environment (if needed)
│       └── kustomization.yaml
└── root/                       # Root applications
    └── blueberry-root-dev.yaml # Dev environment root
```

## How It Works

1. **Base Applications**: Define the core application configurations with placeholder values
2. **Overlays**: Apply environment-specific patches to customize values
3. **Root Application**: Points to the appropriate overlay directory for each environment

## Deployment

To deploy to a specific environment, apply the corresponding root application:

```bash
# For development
kubectl apply -f root/blueberry-root-dev.yaml

# For production (create blueberry-root-prod.yaml first)
kubectl apply -f root/blueberry-root-prod.yaml
```

## Adding New Environment Variables

When you need to add environment-specific values:

1. Add placeholder value in the base application
2. Create patches in each overlay directory
3. Update the overlay's kustomization.yaml if needed

## Ephemeral Environments

Ephemeral environments don't need a separate ingress application. Each environment created by the Blueberry IDP:

1. Creates its own namespace
2. Deploys its own Ingress resources
3. Uses the shared static IP via annotation: `kubernetes.io/ingress.global-static-ip-name`

The static IP names follow this pattern:
- **Dev**: `blueberry-dev-cluster-ephemeral-ip`
- **Staging**: `blueberry-staging-cluster-ephemeral-ip`
- **Prod**: `blueberry-prod-cluster-ephemeral-ip`

These values are created by Terraform and configured in the Blueberry application.
