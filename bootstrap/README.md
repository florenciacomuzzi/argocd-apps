# ArgoCD Bootstrap Applications

This directory contains bootstrap applications that need to be applied manually to break circular dependencies.

## gitlab-secrets-bootstrap.yaml

This application creates the GitLab token secret that ArgoCD needs to authenticate with GitLab repositories.

### Why is this needed?

There's a circular dependency:
1. ArgoCD needs GitLab credentials to pull from GitLab
2. The credentials are managed by External Secrets Operator
3. The External Secrets configuration is stored in GitLab
4. But ArgoCD can't pull it without credentials!

### How to apply

This bootstrap application uses the GitHub mirror (which doesn't require authentication) to create the initial GitLab credentials:

```bash
kubectl apply -f bootstrap/gitlab-secrets-bootstrap.yaml
```

Once applied, this will:
1. Create the SecretStore in ArgoCD namespace
2. Create the ExternalSecret that pulls the GitLab token from Google Secret Manager
3. Allow ArgoCD to authenticate with GitLab for all other applications

### After bootstrap

Once the GitLab credentials are in place, the regular ArgoCD applications can sync from GitLab normally.
