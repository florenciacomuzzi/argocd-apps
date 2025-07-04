# ArgoCD Apps Repository

This repository hosts the **declarative manifests** (Kustomize overlays) consumed by Argo CD as well as helper tooling to keep environments in sync.

## Layout

```text
base/        # Kustomize bases for each component
  └── <app>/
      ├── <app>.yml          # Base manifest(s)
      └── kustomization.yaml # Kustomize base

overlays/    # Environment-specific customisations
  ├── dev/
  └── prod/

bootstrap/   # Manifests used to bootstrap Argo CD / External-Secrets on a fresh cluster
root/        # Argo CD root application definitions for each environment
scripts/     # Utility scripts (e.g. compare_dirs.py)
```

## Utility Scripts

### `compare_dirs.py`
Compare two directories recursively, highlighting:
* files only present in one directory
* differing files (with YAML-aware key-level diffs)

```bash
python scripts/compare_dirs.py overlays/dev overlays/prod
```

Exit code 0 means identical, 1 means differences.

## Pre-commit Hooks

We use [pre-commit](https://pre-commit.com/) to automatically lint YAML and Python files and enforce basic hygiene before each commit.

### Setup

```bash
# Install pre-commit (once)
pip install pre-commit

# Install the git hooks defined in .pre-commit-config.yaml
pre-commit install
```

### Running Manually

```bash
pre-commit run --all-files
```

Hooks configured:
* **pre-commit-hooks** – trailing whitespace, EOF fixer, YAML syntax, file size guard
* **yamllint** – opinionated YAML linting
* **flake8** – Python style & error checking (with `pyyaml` dependency)

## Documentation

### Architecture and Design
- **[ArgoCD CRDs and Platform Integration](./argocd-crds-and-platform-integration.md)** - Comprehensive guide to ArgoCD Custom Resource Definitions and how they interact with platform components
- **[GitOps Flow](./gitops-flow.md)** - Understanding the GitOps workflow and deployment process
- **[Manifest Validation](./manifest-validation.md)** - Guide to validating Kubernetes manifests

### Operational Guides
- **Configuration Overrides** - How environment-specific configurations are applied
- **Order of Operations** - Deployment sequence and dependencies

## Contribution Workflow

1. Create a feature branch.
2. Ensure `pre-commit run --all-files` passes.
3. Open a merge request / pull request.
4. CI will execute Kustomize build / lint checks.

See the root `README.md` for more details about deploying via Argo CD.
