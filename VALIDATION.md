# ArgoCD Manifests Validation Guide

This repository includes comprehensive validation tools for Kubernetes manifests managed by ArgoCD.

## Quick Start

### Local Validation

```bash
# Run all validations
make validate

# Run specific validations
make validate-yaml        # YAML syntax check
make validate-kustomize   # Kustomize build check
make validate-kubeconform # Kubernetes manifest validation

# Build and view manifests
make build-dev   # Build dev overlay
make build-prod  # Build prod overlay
```

### Available Make Targets

Run `make help` to see all available targets:

- **validate**: Run all validation checks
- **validate-yaml**: Validate YAML syntax
- **validate-kustomize**: Validate kustomize builds
- **validate-kubeconform**: Validate Kubernetes manifests with kubeconform
- **validate-docker**: Validate using kubeconform in Docker
- **build-dev/prod**: Build overlays
- **dry-run-dev/prod**: Test apply without making changes
- **deps-check**: Verify required tools are installed
- **install-tools**: Install validation tools (macOS)

## CI/CD Pipeline

The GitHub Actions workflow automatically validates all changes on push and pull requests.

### Workflow Jobs

1. **YAML Lint**: Checks YAML syntax according to `.yamllint` rules
2. **Single Document Check**: Ensures each file contains only one YAML document
3. **Kustomize Build**: Validates that overlays build successfully
4. **Kubeconform Validation**: Validates against Kubernetes and CRD schemas
5. **Kube-score**: Provides best practice recommendations

### Tool Versions

Defined in `.github/workflows/ci.yml`:
- Kustomize: 5.2.1
- Kubeconform: 0.6.4
- Kube-score: 1.17.0

## Manual Installation

### macOS (Homebrew)

```bash
brew install kustomize kubeconform
pip3 install yamllint
```

### Linux

```bash
# Install kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash

# Install kubeconform
wget https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz
tar xf kubeconform-linux-amd64.tar.gz
sudo mv kubeconform /usr/local/bin/

# Install yamllint
pip install yamllint
```

### Docker

No installation needed - use the Docker image:

```bash
make validate-docker
```

## Validation Details

### YAML Lint Rules

Configured in `.yamllint`:
- Line length: max 80 characters (warnings at 120)
- Requires document start marker (`---`)
- No trailing spaces
- Files must end with newline

### Kubeconform

Validates manifests against:
- Kubernetes API schemas
- ArgoCD CRD schemas
- External Secrets CRD schemas

Schema location is automatically configured for CRDs from the Datree catalog.

### Kube-score

Checks for Kubernetes best practices:
- Resource limits and requests
- Security contexts
- Network policies
- Pod disruption budgets

## Troubleshooting

### Kubeconform Schema Errors

If you see "could not find schema" errors, the CRD schemas are fetched from:
```
https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json
```

### Kustomize Build Errors

Check that:
1. All referenced files exist
2. YAML syntax is valid
3. Kustomization paths are correct

### CI Pipeline Failures

The CI logs will show:
- Which validation step failed
- Specific error messages
- Line numbers for YAML issues

## Best Practices

1. **Run validations locally** before pushing:
   ```bash
   make validate
   ```

2. **Fix YAML issues** automatically where possible:
   ```bash
   make fmt
   ```

3. **Check rendered manifests** before applying:
   ```bash
   make build-dev | less
   ```

4. **Use dry-run** to test changes:
   ```bash
   make dry-run-dev
   ```