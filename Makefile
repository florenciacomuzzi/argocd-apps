# Makefile for ArgoCD GitOps repository

.PHONY: help
help: ## Display this help message
	@echo "ArgoCD GitOps Repository Makefile"
	@echo "================================="
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m%-20s\033[0m %s\n", "Target", "Description"} /^[a-zA-Z_-]+:.*?##/ { printf "\033[36m%-20s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# Schema location for CRDs
SCHEMA_LOCATION := 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

.PHONY: validate
validate: validate-yaml validate-kustomize validate-kubeconform ## Run all validation checks

.PHONY: validate-yaml
validate-yaml: ## Validate YAML syntax
	@echo "📝 Validating YAML syntax..."
	@yamllint -c .yamllint . || (echo "❌ YAML validation failed" && exit 1)
	@echo "✅ YAML syntax is valid"

.PHONY: validate-kustomize
validate-kustomize: ## Validate kustomize builds
	@echo "🔧 Validating kustomize builds..."
	@echo "  Checking dev overlay..."
	@kubectl kustomize overlays/dev > /dev/null || (echo "❌ Dev overlay build failed" && exit 1)
	@echo "  Checking prod overlay..."
	@kubectl kustomize overlays/prod > /dev/null || (echo "❌ Prod overlay build failed" && exit 1)
	@echo "✅ Kustomize builds are valid"

.PHONY: validate-kubeconform
validate-kubeconform: ## Validate Kubernetes manifests with kubeconform
	@echo "🔍 Validating Kubernetes manifests with kubeconform..."
	@echo "  Checking dev overlay..."
	@kubectl kustomize overlays/dev | kubeconform -strict -summary -schema-location $(SCHEMA_LOCATION) -schema-location default
	@echo "  Checking prod overlay..."
	@kubectl kustomize overlays/prod | kubeconform -strict -summary -schema-location $(SCHEMA_LOCATION) -schema-location default
	@echo "✅ Kubernetes manifest validation passed"

.PHONY: validate-docker
validate-docker: ## Validate using kubeconform in Docker
	@echo "🐳 Validating with kubeconform in Docker..."
	@kubectl kustomize overlays/dev | docker run --rm -i ghcr.io/yannh/kubeconform:latest -strict -summary -schema-location $(SCHEMA_LOCATION) -schema-location default
	@kubectl kustomize overlays/prod | docker run --rm -i ghcr.io/yannh/kubeconform:latest -strict -summary -schema-location $(SCHEMA_LOCATION) -schema-location default

.PHONY: build-dev
build-dev: ## Build dev overlay
	@echo "🏗️  Building dev overlay..."
	@kubectl kustomize overlays/dev

.PHONY: build-prod
build-prod: ## Build prod overlay
	@echo "🏗️  Building prod overlay..."
	@kubectl kustomize overlays/prod

.PHONY: diff-dev
diff-dev: ## Show diff for dev overlay
	@echo "📊 Showing diff for dev overlay..."
	@kubectl diff -k overlays/dev || true

.PHONY: diff-prod
diff-prod: ## Show diff for prod overlay
	@echo "📊 Showing diff for prod overlay..."
	@kubectl diff -k overlays/prod || true

.PHONY: dry-run-dev
dry-run-dev: ## Dry run apply for dev overlay
	@echo "🧪 Dry run for dev overlay..."
	@kubectl kustomize overlays/dev | kubectl apply --dry-run=client -f -

.PHONY: dry-run-prod
dry-run-prod: ## Dry run apply for prod overlay
	@echo "🧪 Dry run for prod overlay..."
	@kubectl kustomize overlays/prod | kubectl apply --dry-run=client -f -

.PHONY: deps-check
deps-check: ## Check if required tools are installed
	@echo "🔎 Checking dependencies..."
	@command -v kubectl >/dev/null 2>&1 || (echo "❌ kubectl is not installed" && exit 1)
	@command -v kubeconform >/dev/null 2>&1 || (echo "❌ kubeconform is not installed. Run: brew install kubeconform" && exit 1)
	@command -v yamllint >/dev/null 2>&1 || (echo "❌ yamllint is not installed. Run: pip install yamllint" && exit 1)
	@echo "✅ All dependencies are installed"

.PHONY: install-tools
install-tools: ## Install required tools (macOS)
	@echo "📦 Installing required tools..."
	@which kubeconform > /dev/null || brew install kubeconform
	@which yamllint > /dev/null || pip3 install yamllint
	@echo "✅ Tools installed"

.PHONY: fmt
fmt: ## Format YAML files
	@echo "🎨 Formatting YAML files..."
	@find . -name "*.yaml" -o -name "*.yml" | xargs yamllint --fix

.PHONY: clean
clean: ## Clean temporary files
	@echo "🧹 Cleaning temporary files..."
	@find . -name "*~" -delete
	@find . -name "*.bak" -delete
	@echo "✅ Cleanup complete"

.PHONY: pre-commit
pre-commit: ## Run pre-commit hooks
	@echo "🪝 Running pre-commit hooks..."
	@pre-commit run --all-files

.PHONY: argocd-app-diff
argocd-app-diff: ## Show ArgoCD app diff (requires ArgoCD CLI and cluster access)
	@echo "📊 Showing ArgoCD application differences..."
	@argocd app diff blueberry || echo "Note: This requires ArgoCD CLI and cluster access"

.PHONY: test
test: deps-check validate ## Run all tests

# Advanced targets for CI/CD
.PHONY: ci
ci: deps-check validate ## CI pipeline checks
	@echo "✅ CI checks passed"

.PHONY: render-dev
render-dev: ## Render dev manifests to stdout with annotations
	@echo "# Generated from overlays/dev at $$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	@echo "# DO NOT EDIT - This is generated output"
	@echo "---"
	@kubectl kustomize overlays/dev

.PHONY: render-prod
render-prod: ## Render prod manifests to stdout with annotations
	@echo "# Generated from overlays/prod at $$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	@echo "# DO NOT EDIT - This is generated output"
	@echo "---"
	@kubectl kustomize overlays/prod