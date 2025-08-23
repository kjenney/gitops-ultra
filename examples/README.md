# Example Configurations for GitOps Ultra

This directory contains comprehensive examples for different deployment scenarios, environments, and advanced configurations.

## 📁 Directory Structure

- **`applications/`** - Example application deployments using GitOps Ultra
- **`multi-environment/`** - Multi-environment setup (dev/staging/production)
- **`monitoring/`** - Observability stack (Prometheus, Grafana, Loki)
- **`ci-cd/`** - CI/CD pipeline examples (GitHub Actions, GitLab CI)
- **`backup-recovery/`** - Backup strategies and disaster recovery procedures
- **`production-config/`** - Production-ready configurations

## 🚀 Quick Start Examples

### 1. Basic Application Deployment

```bash
# Deploy the sample web application
kubectl apply -f applications/sample-web-app.yaml

# Create ArgoCD application for it
kubectl apply -f applications/argocd-app.yaml
```

### 2. Add Monitoring Stack

```bash
# Deploy Prometheus monitoring
kubectl apply -f monitoring/prometheus-stack.yaml

# Deploy Loki logging
kubectl apply -f monitoring/loki-stack.yaml
```

### 3. Multi-Environment Setup

See `multi-environment/README.md` for detailed setup instructions for:
- Development environment
- Staging environment  
- Production environment

### 4. CI/CD Integration

Use the pipeline examples in `ci-cd/`:
- `github-actions.yml` - Complete GitHub Actions workflow
- Includes validation, security scanning, and multi-environment deployment

### 5. Backup and DR

Implement the backup strategies from `backup-recovery/README.md`:
- Automated backups for all components
- Disaster recovery procedures
- Testing schedules

## 🏗️ Architecture Examples

### Development Environment
- **Cluster**: Single-node or small cluster
- **Resources**: Cost-optimized, smaller instances
- **Auto-sync**: Enabled for rapid iteration
- **Monitoring**: Basic metrics

### Staging Environment  
- **Cluster**: Production-like but smaller
- **Resources**: Similar to production, scaled down
- **Auto-sync**: Enabled with approval gates
- **Monitoring**: Full monitoring stack

### Production Environment
- **Cluster**: Multi-AZ, highly available
- **Resources**: Full production sizing
- **Auto-sync**: Manual approval required
- **Monitoring**: Comprehensive observability
- **Backup**: Full backup and DR procedures

## 🔧 Customization Patterns

Each example demonstrates different approaches to:

### Environment-Specific Configurations
- **Config Management**: Environment-specific values
- **Resource Sizing**: Different CPU/memory limits per environment
- **Security Policies**: Varying security postures
- **Networking**: Environment-specific ingress/egress rules

### AWS Resource Management
- **Account Separation**: Different AWS accounts per environment
- **Resource Tagging**: Consistent tagging strategies
- **Cost Optimization**: Environment-appropriate instance types
- **Backup Strategies**: Tiered backup retention policies

### ArgoCD Application Structuring
- **App of Apps Pattern**: Hierarchical application management
- **Project-Based Isolation**: Separate projects for different teams
- **Sync Wave Orchestration**: Proper deployment ordering
- **Health Checks**: Custom resource health assessment

### Pulumi Stack Organization
- **Stack Per Environment**: Isolated state management
- **Shared Resources**: Common infrastructure components
- **Configuration Management**: Environment-specific settings
- **State Backup**: Automated state backup strategies

## 🛡️ Security Best Practices

### RBAC and Access Control
```yaml
# Example RBAC configuration
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gitops-developer
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "patch"]
```

### Secret Management
- **External Secrets Operator**: Integration examples
- **AWS Secrets Manager**: Secure credential storage
- **Sealed Secrets**: GitOps-friendly secret encryption
- **IRSA Integration**: AWS IAM roles for service accounts

### Pod Security Standards
```yaml
# Example Pod Security Policy
apiVersion: v1
kind: Namespace
metadata:
  name: secure-app
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## 📊 Monitoring and Observability

### Metrics Collection
- **Prometheus**: Application and infrastructure metrics
- **Custom Metrics**: Business logic and GitOps-specific metrics
- **Service Level Indicators**: SLI/SLO monitoring
- **Cost Monitoring**: AWS resource cost tracking

### Logging Strategy
- **Structured Logging**: JSON-formatted application logs
- **Log Aggregation**: Centralized logging with Loki
- **Log-Based Alerting**: Proactive issue detection
- **Audit Logging**: Security and compliance logging

### Distributed Tracing
- **Jaeger Integration**: Request tracing across services
- **OpenTelemetry**: Modern observability standards
- **Performance Monitoring**: Application performance insights

## 🔄 GitOps Workflow Examples

### Development Workflow
```bash
# Feature development
git checkout -b feature/new-feature
# Make changes to applications or infrastructure
git commit -m "feat: add new feature"
git push origin feature/new-feature
# ArgoCD automatically syncs to development environment
```

### Staging Promotion
```bash
# Promote to staging
git checkout staging
git merge feature/new-feature
git push origin staging
# Automated testing triggered
# ArgoCD syncs to staging environment
```

### Production Deployment
```bash
# Production release
git checkout main
git merge staging
git tag v1.2.3
git push origin main --tags
# Manual approval required
# Manual sync in ArgoCD for production
```

## 💡 Advanced Patterns

### Progressive Delivery
- **Canary Deployments**: Gradual traffic shifting
- **Blue-Green Deployments**: Zero-downtime releases
- **Feature Flags**: Runtime feature toggling
- **A/B Testing**: Controlled feature rollouts

### Multi-Cluster Management
- **Cluster Registration**: Managing multiple Kubernetes clusters
- **Cross-Cluster Applications**: Applications spanning clusters
- **Cluster Policies**: Consistent policies across clusters
- **Disaster Recovery**: Cross-region cluster failover

### Advanced ArgoCD Features
- **ApplicationSets**: Templated application generation
- **Sync Hooks**: Custom deployment logic
- **Resource Hooks**: Pre/post deployment actions
- **Health Checks**: Custom resource health definitions

## 📚 Learning Resources

### Getting Started
1. Start with basic application deployment (`applications/`)
2. Add monitoring (`monitoring/`)
3. Implement CI/CD (`ci-cd/`)
4. Set up backup procedures (`backup-recovery/`)

### Advanced Topics
1. Multi-environment management (`multi-environment/`)
2. Production configurations (`production-config/`)
3. Custom monitoring dashboards
4. Disaster recovery testing

### Best Practices
- Follow the GitOps principles
- Implement proper RBAC
- Use infrastructure as code
- Monitor everything
- Test disaster recovery procedures
- Keep security in mind from the start

## 🤝 Contributing Examples

To add new examples:
1. Create a new directory with descriptive name
2. Include comprehensive README.md
3. Provide working code examples
4. Document prerequisites and setup steps
5. Include testing procedures
6. Update this main README.md

## 📞 Support

For questions about examples:
1. Check the specific README in each directory
2. Review the main GitOps Ultra documentation
3. Run `make troubleshoot` for interactive help
4. Check GitHub issues for common problems
