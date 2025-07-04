#!/bin/bash
# Script to validate Kubernetes manifests using kubeconform in a container

# Run kubeconform in a container
echo "Running kubeconform in Docker container..."

# Validate dev overlay
echo "Validating dev overlay..."
kubectl kustomize overlays/dev | docker run --rm -i ghcr.io/yannh/kubeconform:latest -strict -summary

# Validate prod overlay
echo "Validating prod overlay..."
kubectl kustomize overlays/prod | docker run --rm -i ghcr.io/yannh/kubeconform:latest -strict -summary