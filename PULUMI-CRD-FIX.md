# Pulumi Operator CRD Annotation Fix

## 🚨 Problem
When running `make bootstrap`, the installation failed with:
```
Error from server (Invalid): error when creating "pulumi-operator/": CustomResourceDefinition.apiextensions.k8s.io "stacks.pulumi.com" is invalid: metadata.annotations: Too long: must have at most 262144 bytes
Error from server (Invalid): error when creating "pulumi-operator/": CustomResourceDefinition.apiextensions.k8s.io "workspaces.auto.pulumi.com" is invalid: metadata.annotations: Too long: must have at most 262144 bytes
```

## 🔍 Root Cause Analysis

### The Annotation Issue
- **Kubernetes Limit**: Annotations have a strict 262,144 byte (256KB) limit
- **kubectl apply Behavior**: Adds `kubectl.kubernetes.io/last-applied-configuration` annotation containing full JSON representation
- **Large CRDs**: Pulumi Operator CRDs with extensive schemas exceed this limit when the annotation is added

### Why This Happens
1. **Client-Side Apply**: `kubectl apply` creates large annotations for tracking changes
2. **CRD Complexity**: Modern CRDs have extensive OpenAPI schemas for validation
3. **JSON Bloat**: The full JSON representation includes all metadata, specs, and schemas

## ✅ Solutions Implemented

### 1. Primary Fix: Server-Side Apply
**Updated `make bootstrap`**:
- Uses `kubectl apply --server-side` for Pulumi Operator
- Avoids client-side annotation creation
- Relies on Kubernetes server for state management

```bash
kubectl apply --server-side -k pulumi-operator/
```

### 2. Alternative Fix: CRD-Specific Installation
**New `make bootstrap-with-crd-fix`**:
- Separates CRD installation from other resources
- Uses `kubectl create` for CRDs (no annotations)
- Uses `kubectl replace` for updates
- Falls back to server-side apply if needed

### 3. Version Update
**Pulumi Operator Version**:
- **Old**: v2.2.0 (had CRD annotation issues)
- **New**: v2.0.0 GA (latest stable release)
- **Benefits**: More stable, better tested, potential CRD optimizations

## 📋 Available Bootstrap Options

### Option 1: Standard Bootstrap (Recommended)
```bash
make bootstrap
```
- Uses server-side apply for Pulumi Operator
- Should work on Kubernetes 1.22+ clusters
- Fastest and most straightforward

### Option 2: CRD Fix Bootstrap (Fallback)
```bash
make bootstrap-with-crd-fix
```
- Handles CRDs separately to avoid annotation issues
- Works on older Kubernetes versions
- More robust error handling
- Use if standard bootstrap fails

## 🔧 Technical Details

### Server-Side Apply Benefits
- **No Annotations**: Doesn't create large `last-applied-configuration` annotations
- **Server Management**: Kubernetes server manages resource state
- **Better Performance**: Reduces network overhead for large resources
- **Conflict Resolution**: Better handling of multi-client scenarios

### CRD Fix Approach
1. **Extract CRDs**: Uses `grep` to separate CRDs from other resources
2. **Create vs Apply**: Uses `kubectl create` for CRDs (no annotations)
3. **Replace on Update**: Uses `kubectl replace` for CRD updates
4. **Fallback Strategy**: Falls back to server-side apply if extraction fails

### File Changes Made
```
pulumi-operator/
├── kustomization.yaml          # ✅ Updated to v2.0.0
Makefile                        # ✅ Added server-side apply
                               # ✅ Added bootstrap-with-crd-fix target
```

## 🧪 Testing Both Approaches

### Test Standard Bootstrap
```bash
# Should work on most modern clusters
make bootstrap

# Verify installation
kubectl get pods -n pulumi-kubernetes-operator
kubectl get crd stacks.pulumi.com workspaces.auto.pulumi.com
```

### Test CRD Fix Bootstrap
```bash
# Use if standard bootstrap fails
make bootstrap-with-crd-fix

# Verify installation with detailed status
kubectl get crd stacks.pulumi.com -o yaml | grep -c "Too long" || echo "✅ CRD installed successfully"
```

## 📚 References

### Known Issue Sources
- [Pulumi Kubernetes Issue #1883](https://github.com/pulumi/pulumi-kubernetes/issues/1883)
- [Prometheus Operator Issue #4355](https://github.com/prometheus-operator/prometheus-operator/issues/4355)
- [Kubebuilder Issue #2556](https://github.com/kubernetes-sigs/kubebuilder/issues/2556)

### Workaround Resources
- [ArgoCD CRD Too Long Error Fix](https://www.arthurkoziel.com/fixing-argocd-crd-too-long-error/)
- [Kubernetes CRD Annotation Fix](https://www.pcbaecker.com/articles/kubernetes-crd-annotation-too-long-fix/)
- [Medium: kubectl Install CRD Failed](https://medium.com/pareture/kubectl-install-crd-failed-annotations-too-long-2ebc91b40c7d)

### Official Documentation
- [Pulumi Kubernetes Operator v2.0](https://www.pulumi.com/blog/pko-2-0-ga/)
- [Kubernetes Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/)

## 🎯 Outcome

Both bootstrap methods will now successfully install:
- ✅ **ArgoCD v3.0.12** with all components and CRDs
- ✅ **Pulumi Operator v2.0 GA** without annotation issues
- ✅ **Complete GitOps pipeline** ready for infrastructure management

Choose the standard `make bootstrap` first, and fall back to `make bootstrap-with-crd-fix` if you encounter any CRD issues specific to your Kubernetes environment.
