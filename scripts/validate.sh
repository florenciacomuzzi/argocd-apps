#!/bin/bash
# Comprehensive validation script for ArgoCD manifests

set -e

echo "🔍 Validating ArgoCD manifests..."
echo ""

# Check if kubeconform is installed
if ! command -v kubeconform &> /dev/null; then
    echo "❌ kubeconform is not installed. Install with: brew install kubeconform"
    exit 1
fi

# Schema locations for CRDs
SCHEMA_LOCATION='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

# Validate YAML syntax first
echo "📝 Checking YAML syntax..."
if yamllint -c .yamllint . > /dev/null 2>&1; then
    echo "✅ YAML syntax is valid"
else
    echo "❌ YAML syntax errors found:"
    yamllint -c .yamllint .
    exit 1
fi
echo ""

# Validate dev overlay
echo "🚀 Validating dev overlay..."
if kubectl kustomize overlays/dev | kubeconform -strict -summary -schema-location "$SCHEMA_LOCATION" -schema-location default; then
    echo "✅ Dev overlay is valid"
else
    echo "❌ Dev overlay validation failed"
    exit 1
fi
echo ""

# Validate prod overlay
echo "🚀 Validating prod overlay..."
if kubectl kustomize overlays/prod | kubeconform -strict -summary -schema-location "$SCHEMA_LOCATION" -schema-location default; then
    echo "✅ Prod overlay is valid"
else
    echo "❌ Prod overlay validation failed"
    exit 1
fi
echo ""

# Optional: Run in Docker if preferred
if [ "$1" == "--docker" ]; then
    echo "🐳 Running validation in Docker container..."
    kubectl kustomize overlays/dev | docker run --rm -i ghcr.io/yannh/kubeconform:latest -strict -summary -schema-location "$SCHEMA_LOCATION" -schema-location default
fi

echo "✨ All validations passed!"