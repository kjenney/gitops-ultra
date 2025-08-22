# ArgoCD Installation

This directory contains the ArgoCD v3.0.12 (latest stable) installation configuration using Kustomize.

## Version Information

- **ArgoCD Version**: v3.0.12 (latest stable as of August 2025)
- **Redis Version**: 7.0.15-alpine
- **Installation Method**: Kustomize with official manifests + custom patches

## Files

- `kustomization.yaml` - Main Kustomize configuration with version pinning
- `argocd-service-patch.yaml` - Service configuration (LoadBalancer + Ingress)
- `argocd-cm-patch.yaml` - ConfigMap with Pulumi Stack support + RBAC
- `namespace.yaml` - ArgoCD namespace definition

## Features Included

### ✅ Complete Installation
- All ArgoCD core components (server, controller, repo-server, redis, dex)
- Version-pinned to v3.0.12 for consistency and reproducibility
- Automatic CRD installation (Application, AppProject, ApplicationSet)

### ✅ Production-Ready Configuration
- **Security**: RBAC enabled with admin role configuration
- **Monitoring**: Custom health checks for Pulumi Stack CRDs
- **Networking**: LoadBalancer service + Ingress configuration
- **Performance**: Optimized Redis configuration

### ✅ GitOps Integration
- Pre-configured for Pulumi Stack resource monitoring
- Custom resource health assessments
- Repository configuration support

## Installation

### Quick Start
```bash
# Using make (recommended)
make bootstrap

# Manual installation
kubectl create namespace argocd || true
kubectl apply -k argocd-install/
```

### Verification
```bash
# Check installation status
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward for local access
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Configuration Details

### Service Access Methods

1. **LoadBalancer** (default): External IP assignment
2. **Ingress**: nginx-ingress with TLS termination  
3. **Port Forward**: Local development access

### Security Configuration

- **Insecure Mode**: Enabled for development (disable for production)
- **RBAC**: Configured with admin role and policy
- **TLS**: Ingress handles TLS termination

### Pulumi Integration

Custom health checks for Pulumi Stack resources:
- ✅ `succeeded` state → Healthy
- ⚠️ `running` state → Progressing  
- ❌ `failed` state → Degraded

## Production Deployment

For production environments, update the following:

### 1. Security Hardening
```yaml
# In argocd-cm-patch.yaml
server.insecure: "false"  # Enable TLS
```

### 2. Domain Configuration
```yaml
# In argocd-service-patch.yaml
spec:
  rules:
  - host: argocd.yourdomain.com  # Update domain
```

### 3. Authentication
Consider configuring:
- OIDC/SAML authentication
- LDAP integration
- Certificate-based authentication

## Troubleshooting

### Common Issues

1. **CRD Installation Errors**
   ```bash
   # Manually install CRDs first
   kubectl apply -k https://github.com/argoproj/argo-cd/manifests/crds?ref=v3.0.12
   ```

2. **Service Not Accessible**
   ```bash
   # Check service status
   kubectl get svc argocd-server -n argocd
   
   # Check ingress
   kubectl get ingress argocd-server-ingress -n argocd
   ```

3. **Pods Not Ready**
   ```bash
   # Check pod logs
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
   ```

## Version History

- **v3.0.12**: Current stable release with security fixes
- **v3.0.x**: Major version 3 with performance improvements
- **v2.14.x**: Previous stable branch (legacy)

## Upgrade Notes

When upgrading ArgoCD:

1. **Backup current configuration**
   ```bash
   kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml
   ```

2. **Update version in kustomization.yaml**
   ```yaml
   images:
   - name: quay.io/argoproj/argocd
     newTag: v3.0.13  # Next version
   ```

3. **Apply upgrade**
   ```bash
   kubectl apply -k argocd-install/
   ```

## References

- [ArgoCD Official Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD v3.0.12 Release Notes](https://github.com/argoproj/argo-cd/releases/tag/v3.0.12)
- [Kustomize Documentation](https://kustomize.io/)
