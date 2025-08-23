# GitOps Ultra - Production-Ready GitOps with ArgoCD and Pulumi

A comprehensive GitOps implementation using ArgoCD v3.1.0 and Pulumi Kubernetes Operator v2.4 with the App of Apps pattern.

## 🚀 Architecture Overview

This project implements a production-ready GitOps architecture with:

- **ArgoCD v3.1.0** - Latest stable version with improved security
- **Pulumi Kubernetes Operator v2.4** - Infrastructure as Code with Python
- **App of Apps Pattern** - Hierarchical application management
- **Pod Security Standards** - Enhanced security policies
- **Resource Quotas** - Proper resource management
- **RBAC** - Role-based access control

## 📋 Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl configured and connected
- kustomize (v3.0+)
- Python 3.8+ (for Pulumi)
- curl
- Git

## 🔧 Quick Start

### 1. Initial Setup

**⚠️ Run this first to make all scripts executable:**

```bash
make setup
```

### 2. Configure Your Repository

**⚠️ Important: Run this second!**

```bash
make configure-repo
```

This interactive script will update all configuration files with your actual Git repository URL and settings.

### 3. Install Dependencies

```bash
make install-deps
```

### 4. Validate Configuration

```bash
make quick-check
make validate
```

### 5. Bootstrap Infrastructure

```bash
make bootstrap
```

This will:
- Install ArgoCD v3.1.0 with production configuration
- Deploy Pulumi Kubernetes Operator via App of Apps pattern
- Set up namespaces with resource quotas and security policies
- Configure proper RBAC and Pod Security Standards

### 6. Deploy Infrastructure

```bash
make deploy-infra
```

This creates AWS resources (S3, SQS, IAM) using Pulumi Stack CRDs.

### 7. Deploy Applications

```bash
make deploy-k8s
```

### 8. Verify Deployment

```bash
make health-check        # Quick health check
make status             # Detailed status
make verify-deployment  # Comprehensive verification
```

### 9. Troubleshooting

```bash
make troubleshoot       # Interactive troubleshooting guide
```

## 🏗️ Architecture Details

### App of Apps Pattern

```
bootstrap/bootstrap-apps.yaml (Root App of Apps)
├── bootstrap/core/namespaces.yaml (Wave 0)
├── bootstrap/core/pulumi-operator.yaml (Wave 1)  
└── bootstrap/core/infrastructure.yaml (Wave 2)
    └── infrastructure/stacks/ (Wave 3)
```

### Directory Structure

```
gitops-ultra/
├── Makefile                    # Main automation
├── README.md                   # This file
├── argocd/                     # Application definitions
│   ├── infrastructure-app.yaml
│   └── kubernetes-app.yaml
├── argocd-install/             # ArgoCD installation
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   └── patches/
├── bootstrap/                  # Bootstrap applications
│   ├── bootstrap-apps.yaml     # Root App of Apps
│   ├── core/                   # Core component apps
│   │   ├── pulumi-operator.yaml
│   │   ├── namespaces.yaml
│   │   └── infrastructure.yaml
│   └── namespaces/             # Namespace definitions
├── infrastructure/             # Infrastructure as Code
│   ├── pulumi/                 # Pulumi Python code
│   │   ├── __main__.py
│   │   └── requirements.txt
│   └── stacks/                 # Pulumi Stack CRDs
│       └── infrastructure-stack.yaml
├── kubernetes/                 # K8s application manifests
└── scripts/                    # Helper scripts
    ├── configure-repo.sh
    └── verify-deployment.sh
```

## 🔐 Security Features

- **Pod Security Standards**: Enforced at namespace level
- **Resource Quotas**: CPU/Memory limits per namespace  
- **Network Policies**: Traffic segmentation (where supported)
- **RBAC**: Proper role-based access control
- **Security Contexts**: Non-root containers, read-only filesystems
- **IRSA Support**: AWS IAM Roles for Service Accounts

## 📊 Monitoring and Observability

### Quick Health Checks

```bash
make health-check         # Quick health overview
make status              # Detailed component status
make verify-deployment   # Comprehensive verification
```

### ArgoCD Access

```bash
make check-argocd
```

This provides:
- Admin credentials
- Port forwarding instructions
- LoadBalancer/Ingress URLs (if configured)

### Status Checking

```bash
make status                    # Overall status
make verify-deployment        # Comprehensive verification
kubectl get applications -n argocd  # ArgoCD apps
kubectl get stacks -n pulumi-system # Pulumi stacks
```

### Troubleshooting

```bash
make troubleshoot         # Interactive troubleshooting guide
```

Targeted troubleshooting:
```bash
./scripts/troubleshoot.sh argocd    # ArgoCD issues
./scripts/troubleshoot.sh pulumi    # Pulumi Operator issues
./scripts/troubleshoot.sh all       # Check all common issues
```

## 🛠️ Development and Troubleshooting

### Local Development

```bash
make dev-argocd-forward       # Forward ArgoCD UI
make dev-logs-infrastructure  # Follow Pulumi logs
make dev-logs-argocd         # Follow ArgoCD logs
```

### Validation

```bash
make validate-python         # Validate Pulumi configuration
make test-pulumi            # Test Pulumi installation
```

### Cleanup

```bash
make clean                  # Remove all resources
```

## 🔄 Sync Waves

Applications are deployed in waves to ensure proper dependency order:

- **Wave 0**: Namespaces, resource quotas, security policies
- **Wave 1**: Core operators (Pulumi Kubernetes Operator)
- **Wave 2**: Bootstrap infrastructure applications  
- **Wave 3**: Actual infrastructure stacks (AWS resources)

## 🆕 What's New in This Version

### Improvements Over Previous Versions

1. **App of Apps Pattern**: Better organization and dependency management
2. **ArgoCD v3.1.0**: Latest stable with security enhancements
3. **Resource Management**: Proper quotas and limits
4. **Security Hardening**: Pod Security Standards, RBAC, security contexts
5. **Pulumi Stack CRDs**: Cleaner separation of infrastructure definitions
6. **Configuration Script**: Easy repository setup
7. **Enhanced Validation**: Comprehensive pre-flight checks

### Migration from v3.0.12

The project now uses ArgoCD v3.1.0 and the App of Apps pattern. If upgrading:

1. Run `make configure-repo` to update configurations
2. Review the new bootstrap structure
3. Update any custom applications to use the new pattern

## 🤝 Contributing

1. Fork the repository
2. Run `make configure-repo` with your repository details
3. Make your changes
4. Test with `make validate` and `make verify-deployment`
5. Submit a pull request

## 📚 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Pulumi Kubernetes Operator](https://github.com/pulumi/pulumi-kubernetes-operator)
- [GitOps Principles](https://opengitops.dev/)
- [CNCF App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section in `scripts/troubleshoot.sh`
2. Run `make verify-deployment` for diagnostic information
3. Review ArgoCD application status in the UI
4. Check logs with the development commands
