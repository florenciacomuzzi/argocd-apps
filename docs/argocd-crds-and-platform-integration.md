# ArgoCD CRDs and Platform Integration

This document explains how ArgoCD Custom Resource Definitions (CRDs) interact with platform components to provide a comprehensive GitOps deployment solution.

## Architecture Overview

![ArgoCD CRDs and Platform Integration](../diagrams/argocd-crds-platform-integration.svg)

*Diagram showing the relationships between ArgoCD CRDs, environment applications, and platform components*

## ArgoCD Custom Resource Definitions (CRDs)

### Application CRD
- **API Version**: `argoproj.io/v1alpha1`
- **Kind**: `Application`
- **Purpose**: Defines individual application deployments
- **Key Features**:
  - Source repository configuration
  - Destination cluster and namespace
  - Sync policies and automation
  - Health checks and status reporting

### AppProject CRD
- **API Version**: `argoproj.io/v1alpha1`
- **Kind**: `AppProject`
- **Purpose**: Defines project boundaries and security policies
- **Key Features**:
  - Source repository restrictions
  - Destination cluster/namespace allowlists
  - Resource type restrictions
  - RBAC policy enforcement

### ApplicationSet CRD
- **API Version**: `argoproj.io/v1alpha1`
- **Kind**: `ApplicationSet`
- **Purpose**: Manages multi-environment application deployments
- **Key Features**:
  - Template-based application generation
  - Environment-specific parameter injection
  - Automated application lifecycle management

### Repository CRD
- **API Version**: `argoproj.io/v1alpha1`
- **Kind**: `Repository`
- **Purpose**: Configures Git repository access
- **Key Features**:
  - Authentication credentials
  - Repository URL configuration
  - TLS/SSH key management

## Project Structure: blueberry

### AppProject Configuration
Our `blueberry-project` AppProject defines:

- **Allowed Source Repositories**:
  - `https://gitlab.com/obtain-blew/argocd-apps.git`
  - `https://gitlab.com/obtain-blew/blueberry.git`
  - External Helm repositories

- **Allowed Destinations**:
  - `argocd` namespace
  - `blueberry` namespace
  - `external-secrets` namespace

- **RBAC Policies**:
  - Role bindings for service accounts
  - User permissions and access control
  - Cross-namespace resource management

## Environment Applications (App-of-Apps Pattern)

### Multi-Environment Strategy
We use the App-of-Apps pattern to manage multiple environments:

#### Development Environment
- **Application**: `blueberry-root-dev`
- **Source Path**: `overlays/dev/`
- **Purpose**: Development environment deployment
- **Features**:
  - Lower resource limits
  - Debug configurations
  - Frequent updates

#### Production Environment
- **Application**: `blueberry-root-prod`
- **Source Path**: `overlays/prod/`
- **Purpose**: Production environment deployment
- **Features**:
  - High availability
  - Resource optimization
  - Strict change management

#### Staging Environment
- **Application**: `blueberry-root-staging`
- **Source Path**: `overlays/staging/`
- **Purpose**: Pre-production testing
- **Features**:
  - Production-like configuration
  - Performance testing
  - Integration validation

## Child Applications and Sync Waves

### Sync Wave Strategy
We use ArgoCD sync waves to control deployment order:

#### Wave -20: Foundation Infrastructure
- **Application**: `external-secrets`
- **Purpose**: External Secrets Operator deployment
- **Components**:
  - ESO installation via Helm
  - Custom Resource Definitions
  - Webhook configuration

#### Wave -10: Bootstrap Secrets
- **Purpose**: Repository credentials and authentication
- **Components**:
  - GitLab token secrets
  - Repository access configuration
  - Service account setup

#### Wave -5: Secret Resources
- **Application**: `gitlab-secret-resources`
- **Purpose**: Application secrets and shared resources
- **Components**:
  - ExternalSecret resources
  - ConfigMaps
  - Shared configurations

#### Wave 0: Platform Components
- **Application**: `argocd-image-updater`
- **Purpose**: Platform tooling and automation
- **Components**:
  - Image update automation
  - Monitoring setup
  - Platform utilities

#### Wave 10: Applications
- **Application**: `blueberry`
- **Purpose**: Main business applications
- **Components**:
  - Web application deployment
  - Database components
  - Application-specific resources

## Git Repository Integration

### Base and Overlay Pattern
Our repository structure follows Kustomize best practices:

#### Base Directory (`base/`)
- **Purpose**: Common manifests shared across environments
- **Contains**:
  - Core application definitions
  - Common configurations
  - Shared templates

#### Overlay Directories (`overlays/`)
- **Purpose**: Environment-specific configurations
- **Structure**:
  - `overlays/dev/` - Development patches
  - `overlays/prod/` - Production patches
  - `overlays/staging/` - Staging patches

### Kustomize Integration
1. **Base Resources**: Common manifests and shared configurations
2. **Overlay Patches**: Environment-specific modifications
3. **Final Manifests**: Rendered YAML ready for deployment

## Platform Components Integration

### Secret Management
- **Component**: External Secrets Operator
- **Integration**: Sync wave -20 ensures ESO is ready before secrets
- **Features**:
  - Google Secret Manager integration
  - Automatic secret rotation
  - Secure credential management

### Image Automation
- **Component**: ArgoCD Image Updater
- **Integration**: Monitors container registries for updates
- **Features**:
  - Automated image tag updates
  - Git write-back capability
  - Rollback protection

### Monitoring and Observability
- **Integration**: Application health checks and metrics
- **Features**:
  - Health status reporting
  - Performance monitoring
  - Alerting integration

### Ingress and Networking
- **Integration**: Traffic routing and SSL termination
- **Features**:
  - Load balancing
  - SSL certificate management
  - External access configuration

## Application Lifecycle

### 1. Application Creation
- CRD instantiation and validation
- Project assignment and security checks
- Resource validation

### 2. Source Sync
- Git repository pull and authentication
- Manifest generation (Kustomize/Helm)
- Template processing

### 3. Reconciliation
- Desired vs actual state comparison
- Drift detection and analysis
- Sync status updates

### 4. Deployment
- Resource application to cluster
- Health checks and validation
- Status reporting and alerting

## Security Considerations

### Project-Level Security
- **Resource Restrictions**: AppProject defines allowed resource types
- **Namespace Isolation**: Strict namespace access controls
- **Repository Access**: Limited to approved repositories

### Secret Management
- **External Secrets**: No secrets stored in Git
- **Workload Identity**: Secure GCP service account access
- **Credential Rotation**: Automated secret updates

### RBAC Integration
- **Service Accounts**: Dedicated accounts for each component
- **Role Bindings**: Least privilege access
- **Cross-Namespace Access**: Controlled resource sharing

## Troubleshooting

### Common Issues

#### Applications Not Syncing
1. Check repository authentication
2. Verify AppProject permissions
3. Validate sync wave dependencies

#### Secret Access Errors
1. Verify External Secrets configuration
2. Check Workload Identity bindings
3. Validate Secret Manager permissions

#### Deployment Failures
1. Check resource quotas
2. Verify namespace existence
3. Validate RBAC permissions

### Monitoring and Debugging

#### Application Status
```bash
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
```

#### Sync Wave Status
```bash
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,WAVE:.metadata.annotations."argocd\.argoproj\.io/sync-wave"
```

#### Secret Status
```bash
kubectl get externalsecrets -n argocd
kubectl get secretstores -n argocd
```

## Best Practices

### Application Design
- Use sync waves for dependency management
- Implement proper health checks
- Design for multi-environment deployment

### Security
- Never store secrets in Git
- Use External Secrets for all credentials
- Implement proper RBAC policies

### Monitoring
- Monitor application health status
- Track sync performance
- Set up alerting for failures

### Git Operations
- Use meaningful commit messages
- Implement proper branching strategy
- Validate manifests before commit

## Related Documentation

- [GitOps Flow](./gitops-flow.md)
- [Manifest Validation](./manifest-validation.md)
- [Repository Structure](../README.md) 