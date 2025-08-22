#!/bin/bash

# Enhanced ArgoCD v3.0.12 Validation Script
# Tests the complete bootstrap configuration

set -e

echo "🧪 Testing ArgoCD v3.0.12 Bootstrap Configuration"
echo "================================================="
echo ""

cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test 1: Prerequisites
print_step "1. Checking prerequisites..."

if command -v kubectl >/dev/null 2>&1; then
    print_success "kubectl found: $(kubectl version --client --short)"
else
    print_error "kubectl not found"
    exit 1
fi

if command -v kustomize >/dev/null 2>&1; then
    print_success "kustomize found: $(kustomize version --short)"
else
    print_error "kustomize not found"
    exit 1
fi

# Test 2: Cluster connectivity
print_step "2. Testing cluster connectivity..."
if kubectl cluster-info --request-timeout=10s >/dev/null 2>&1; then
    print_success "Kubernetes cluster accessible"
else
    print_warning "Cannot connect to Kubernetes cluster (this is OK for offline validation)"
fi

# Test 3: Kustomization build
print_step "3. Testing ArgoCD kustomization build..."
if kustomize build argocd-install/ > /tmp/argocd-test.yaml; then
    print_success "ArgoCD kustomization builds successfully"
    echo "   Generated $(wc -l < /tmp/argocd-test.yaml) lines of YAML"
else
    print_error "ArgoCD kustomization build failed"
    exit 1
fi

# Test 4: Validate generated YAML
print_step "4. Validating generated YAML structure..."
if grep -q "apiVersion: v1" /tmp/argocd-test.yaml && \
   grep -q "kind: Namespace" /tmp/argocd-test.yaml && \
   grep -q "name: argocd" /tmp/argocd-test.yaml; then
    print_success "Namespace configuration found"
else
    print_error "Namespace configuration missing"
    exit 1
fi

if grep -q "app.kubernetes.io/name: argocd-server" /tmp/argocd-test.yaml; then
    print_success "ArgoCD server configuration found"
else
    print_error "ArgoCD server configuration missing"
    exit 1
fi

# Test 5: Check for required components
print_step "5. Checking for required ArgoCD components..."
components=("argocd-server" "argocd-application-controller" "argocd-repo-server" "argocd-redis")
for component in "${components[@]}"; do
    if grep -q "$component" /tmp/argocd-test.yaml; then
        print_success "Component found: $component"
    else
        print_error "Component missing: $component"
        exit 1
    fi
done

# Test 6: Check version pinning
print_step "6. Verifying version pinning..."
if grep -q "v3.0.12" argocd-install/kustomization.yaml; then
    print_success "ArgoCD v3.0.12 version pinning confirmed"
else
    print_error "Version pinning not found or incorrect"
    exit 1
fi

# Test 7: Test patch syntax (modern kustomize)
print_step "7. Testing modern patch syntax..."
if grep -q "patches:" argocd-install/kustomization.yaml && \
   ! grep -q "patchesStrategicMerge:" argocd-install/kustomization.yaml; then
    print_success "Modern patch syntax used (deprecated patchesStrategicMerge removed)"
else
    print_error "Still using deprecated patchesStrategicMerge syntax"
    exit 1
fi

# Test 8: Test updated configuration files
print_step "8. Testing updated configuration files..."
if [[ -f "argocd-install/argocd-ingress.yaml" ]]; then
    print_success "ArgoCD ingress file exists"
else
    print_error "ArgoCD ingress file missing"
    exit 1
fi

if [[ -f "argocd-install/argocd-cm-patch.yaml" ]]; then
    print_success "ConfigMap patch file exists"
else
    print_error "ConfigMap patch file missing"
    exit 1
fi

if [[ -f "argocd-install/argocd-service-patch.yaml.old" ]]; then
    print_success "Old service patch file moved (no longer conflicts)"
else
    print_warning "Old service patch file not found (may have been removed)"
fi

# Test 9: Validate against cluster (if connected)
print_step "9. Testing cluster validation (if connected)..."
if kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
    if kubectl apply --dry-run=client -f /tmp/argocd-test.yaml >/dev/null 2>&1; then
        print_success "Cluster validation passed"
    else
        print_warning "Cluster validation failed (may need CRDs)"
        echo "   This is expected if ArgoCD CRDs are not installed"
        echo "   Run 'make bootstrap' to install CRDs and ArgoCD"
    fi
else
    print_warning "Skipping cluster validation (not connected)"
fi

# Test 10: Check Makefile integration
print_step "10. Testing Makefile integration..."
if grep -q "bootstrap:" Makefile && grep -q "v3.0.12" Makefile; then
    print_success "Makefile bootstrap target updated"
else
    print_error "Makefile not properly updated"
    exit 1
fi

# Test 11: Pulumi Operator validation
print_step "11. Testing Pulumi Operator configuration..."
if [[ -d "pulumi-operator" ]]; then
    if kustomize build pulumi-operator/ > /tmp/pulumi-test.yaml; then
        print_success "Pulumi Operator kustomization builds successfully"
    else
        print_error "Pulumi Operator kustomization build failed"
        exit 1
    fi
else
    print_warning "Pulumi Operator directory not found"
fi

# Cleanup
rm -f /tmp/argocd-test.yaml /tmp/pulumi-test.yaml

echo ""
print_step "🎉 Validation Summary:"
print_success "All critical tests passed!"
print_success "ArgoCD v3.0.12 bootstrap configuration is ready"
echo ""
echo "📋 Next steps:"
echo "   1. Run 'make bootstrap' to install ArgoCD v3.0.12"
echo "   2. Run 'make check-argocd' to get access details"
echo "   3. Run 'make validate' for comprehensive validation"
echo ""
echo "🔗 For more information, see:"
echo "   - argocd-install/README.md"
echo "   - BOOTSTRAP-UPDATE-SUMMARY.md"
