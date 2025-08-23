# Multi-Environment GitOps Setup

This directory contains examples for deploying GitOps Ultra across multiple environments (dev, staging, production).

## Environment Strategy

### 1. Branch-Based Environments

```
main branch         → production environment
staging branch      → staging environment  
develop branch      → development environment
```

### 2. Directory-Based Environments

```
environments/
├── dev/
├── staging/
└── production/
```

### 3. Repository-Per-Environment

```
gitops-ultra-dev
gitops-ultra-staging
gitops-ultra-production
```

## Configuration Differences

### Development Environment
- **Cluster**: Single-node or small cluster
- **AWS Resources**: Smaller, cost-optimized
- **Monitoring**: Basic metrics
- **Security**: Relaxed for development
- **Auto-sync**: Enabled for rapid iteration

### Staging Environment
- **Cluster**: Production-like but smaller
- **AWS Resources**: Similar to production but scaled down
- **Monitoring**: Full monitoring stack
- **Security**: Production-like security
- **Auto-sync**: Enabled with manual promotion triggers

### Production Environment
- **Cluster**: Multi-AZ, HA configuration
- **AWS Resources**: Full production sizing
- **Monitoring**: Comprehensive observability
- **Security**: Strict security policies
- **Auto-sync**: Disabled, manual approvals required

## Example Configurations

### Development Environment (dev)

```yaml
# Pulumi Stack Configuration
config:
  aws:region: us-west-2
  project:prefix: myapp-dev
  kubernetes:namespace: myapp-dev
  project:environment: dev
  project:cluster-size: small
  project:replicas: 1
  project:enable-monitoring: false
```

### Staging Environment (staging)

```yaml
# Pulumi Stack Configuration  
config:
  aws:region: us-west-2
  project:prefix: myapp-staging
  kubernetes:namespace: myapp-staging
  project:environment: staging
  project:cluster-size: medium
  project:replicas: 2
  project:enable-monitoring: true
```

### Production Environment (prod)

```yaml
# Pulumi Stack Configuration
config:
  aws:region: us-west-2
  project:prefix: myapp-prod
  kubernetes:namespace: myapp-prod
  project:environment: production
  project:cluster-size: large
  project:replicas: 3
  project:enable-monitoring: true
  project:enable-backup: true
```

## ArgoCD Application Examples

### Development Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-dev-infrastructure
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/gitops-ultra
    targetRevision: develop  # Development branch
    path: infrastructure/stacks
  destination:
    server: https://kubernetes.default.svc
    namespace: pulumi-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true  # Auto-heal for development
```

### Production Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-prod-infrastructure
  namespace: argocd
spec:
  project: production  # Separate project with restricted permissions
  source:
    repoURL: https://github.com/your-org/gitops-ultra
    targetRevision: main  # Main branch for production
    path: infrastructure/stacks
  destination:
    server: https://kubernetes.default.svc
    namespace: pulumi-system
  syncPolicy:
    # Manual sync for production
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
```

## Deployment Workflow

### 1. Development Workflow
```bash
# Developer creates feature branch
git checkout -b feature/new-feature

# Makes changes and pushes
git push origin feature/new-feature

# ArgoCD automatically syncs to dev environment
# Developer tests changes
```

### 2. Staging Promotion
```bash
# Merge to staging branch
git checkout staging
git merge feature/new-feature
git push origin staging

# ArgoCD syncs to staging environment
# Run automated tests
```

### 3. Production Promotion
```bash
# Create PR to main branch
gh pr create --base main --title "Production Release v1.2.3"

# After review and approval, merge to main
git checkout main
git merge staging
git tag v1.2.3
git push origin main --tags

# Manual sync in ArgoCD for production
```

## Security Considerations

### Environment Separation
- **Separate AWS Accounts**: Each environment in its own AWS account
- **Separate Kubernetes Clusters**: Isolated clusters per environment  
- **Separate ArgoCD Instances**: Or use ArgoCD projects for isolation
- **Separate Git Repositories**: For maximum security isolation

### RBAC Configuration
- **Development**: Relaxed permissions for rapid development
- **Staging**: Production-like permissions for realistic testing
- **Production**: Strict permissions with approval workflows

### Secrets Management
- **Development**: Local secrets or development-specific values
- **Staging**: Production-like secrets but non-sensitive data
- **Production**: Encrypted secrets, external secret management

## Monitoring Differences

### Development
- Basic logging
- Simple metrics
- No alerting

### Staging  
- Full logging stack
- Comprehensive metrics
- Test alerting rules

### Production
- Full observability stack
- Real-time monitoring
- Production alerting
- SLA monitoring

## Cost Optimization

### Development
- Single-node clusters
- Smaller AWS resources
- Auto-shutdown during off-hours
- Shared resources

### Staging
- Right-sized for testing
- Similar to production but scaled down
- Cost monitoring

### Production
- Optimized for performance and availability
- Reserved instances
- Cost allocation tags
- Regular cost reviews
