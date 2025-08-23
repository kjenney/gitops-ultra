#!/bin/bash

# GitOps Ultra - Deployment Verification Script
# This script verifies that the GitOps deployment with Pulumi Kubernetes Operator is working correctly

set -e

echo "🔍 GitOps Ultra - Deployment Verification"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available and connected
check_kubectl() {
    print_status "Checking kubectl connectivity..."
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl not found in PATH"
        return 1
    fi
    
    if ! kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    print_success "kubectl connectivity verified"
}

# Check ArgoCD installation
check_argocd() {
    print_status "Checking ArgoCD installation..."
    
    # Check namespace exists
    if ! kubectl get namespace argocd >/dev/null 2>&1; then
        print_error "ArgoCD namespace not found"
        return 1
    fi
    
    # Check ArgoCD pods
    local argocd_pods
    argocd_pods=$(kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd --no-headers 2>/dev/null | wc -l)
    
    if [ "$argocd_pods" -eq 0 ]; then
        print_error "No ArgoCD pods found"
        return 1
    fi
    
    # Check if all ArgoCD components are running
    local not_ready
    not_ready=$(kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd --no-headers 2>/dev/null | grep -v Running | wc -l)
    
    if [ "$not_ready" -gt 0 ]; then
        print_warning "Some ArgoCD pods are not ready:"
        kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd --no-headers | grep -v Running
    else
        print_success "All ArgoCD components are running ($argocd_pods pods)"
    fi
    
    # Check ArgoCD server service
    if kubectl get svc argocd-server -n argocd >/dev/null 2>&1; then
        print_success "ArgoCD server service found"
    else
        print_warning "ArgoCD server service not found"
    fi
}

# Check Pulumi Kubernetes Operator installation
check_pulumi_operator() {
    print_status "Checking Pulumi Kubernetes Operator..."
    
    # Check if the namespace exists
    local operator_namespace=""
    if kubectl get namespace pulumi-kubernetes-operator >/dev/null 2>&1; then
        operator_namespace="pulumi-kubernetes-operator"
    elif kubectl get namespace pulumi-system >/dev/null 2>&1; then
        operator_namespace="pulumi-system"
    else
        print_error "Pulumi Operator namespace not found (tried: pulumi-kubernetes-operator, pulumi-system)"
        return 1
    fi
    
    print_status "Using Pulumi Operator namespace: $operator_namespace"
    
    # Check operator pods
    local operator_pods
    operator_pods=$(kubectl get pods -n "$operator_namespace" --no-headers 2>/dev/null | wc -l)
    
    if [ "$operator_pods" -eq 0 ]; then
        print_error "No Pulumi Operator pods found in namespace $operator_namespace"
        return 1
    fi
    
    # Check if operator is running
    local not_ready
    not_ready=$(kubectl get pods -n "$operator_namespace" --no-headers 2>/dev/null | grep -v Running | wc -l)
    
    if [ "$not_ready" -gt 0 ]; then
        print_warning "Some Pulumi Operator pods are not ready:"
        kubectl get pods -n "$operator_namespace" --no-headers | grep -v Running
    else
        print_success "Pulumi Operator is running ($operator_pods pods in $operator_namespace)"
    fi
    
    # Check Pulumi CRDs
    if kubectl get crd stacks.pulumi.com >/dev/null 2>&1; then
        print_success "Pulumi Stack CRD is installed"
    else
        print_error "Pulumi Stack CRD not found"
        return 1
    fi
}

# Check ArgoCD applications
check_argocd_applications() {
    print_status "Checking ArgoCD applications..."
    
    local apps
    apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
    
    if [ "$apps" -eq 0 ]; then
        print_warning "No ArgoCD applications found"
        return 0
    fi
    
    print_success "Found $apps ArgoCD applications"
    
    # Show application status
    echo ""
    echo "Application Status:"
    kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REPO:.spec.source.repoURL 2>/dev/null || print_warning "Could not get application details"
    
    # Check for any out-of-sync applications
    local out_of_sync
    out_of_sync=$(kubectl get applications -n argocd -o jsonpath='{.items[?(@.status.sync.status!="Synced")].metadata.name}' 2>/dev/null)
    
    if [ -n "$out_of_sync" ]; then
        print_warning "Applications that are not synced: $out_of_sync"
    else
        print_success "All applications are synced"
    fi
}

# Check Pulumi Stacks
check_pulumi_stacks() {
    print_status "Checking Pulumi Stacks..."
    
    local stacks
    stacks=$(kubectl get stack -A --no-headers 2>/dev/null | wc -l)
    
    if [ "$stacks" -eq 0 ]; then
        print_warning "No Pulumi Stacks found"
        return 0
    fi
    
    print_success "Found $stacks Pulumi Stack(s)"
    
    # Show stack status
    echo ""
    echo "Stack Status:"
    kubectl get stack -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,LAST-UPDATE:.status.lastUpdate.state,OUTPUTS:.status.outputs 2>/dev/null || print_warning "Could not get stack details"
}

# Check infrastructure resources (AWS)
check_infrastructure() {
    print_status "Checking infrastructure resources..."
    
    # Check if AWS CLI is available
    if ! command -v aws >/dev/null 2>&1; then
        print_warning "AWS CLI not found - skipping infrastructure checks"
        return 0
    fi
    
    # Check for S3 buckets
    local s3_buckets
    s3_buckets=$(aws s3 ls 2>/dev/null | grep -c myapp-dev || echo "0")
    
    if [ "$s3_buckets" -gt 0 ]; then
        print_success "Found $s3_buckets S3 bucket(s) with myapp-dev prefix"
    else
        print_warning "No S3 buckets found with myapp-dev prefix"
    fi
    
    # Check for SQS queues
    local sqs_queues
    sqs_queues=$(aws sqs list-queues --queue-name-prefix myapp-dev 2>/dev/null | jq -r '.QueueUrls // [] | length' 2>/dev/null || echo "0")
    
    if [ "$sqs_queues" -gt 0 ]; then
        print_success "Found $sqs_queues SQS queue(s) with myapp-dev prefix"
    else
        print_warning "No SQS queues found with myapp-dev prefix"
    fi
}

# Check application namespace and resources
check_application_resources() {
    print_status "Checking application resources..."
    
    local app_namespace="myapp-dev"
    
    if ! kubectl get namespace "$app_namespace" >/dev/null 2>&1; then
        print_warning "Application namespace '$app_namespace' not found"
        return 0
    fi
    
    print_success "Application namespace '$app_namespace' exists"
    
    # Check for resources in the namespace
    local resources
    resources=$(kubectl get all -n "$app_namespace" --no-headers 2>/dev/null | wc -l)
    
    if [ "$resources" -eq 0 ]; then
        print_warning "No resources found in namespace $app_namespace"
    else
        print_success "Found $resources resource(s) in namespace $app_namespace"
    fi
    
    # Check for ConfigMaps with AWS resource information
    if kubectl get configmap -n "$app_namespace" -l app.kubernetes.io/managed-by=Pulumi >/dev/null 2>&1; then
        print_success "Found Pulumi-managed ConfigMaps"
    else
        print_warning "No Pulumi-managed ConfigMaps found"
    fi
}

# Main verification function
run_verification() {
    local failed_checks=0
    
    echo "Starting comprehensive deployment verification..."
    echo ""
    
    # Run all checks
    check_kubectl || ((failed_checks++))
    echo ""
    
    check_argocd || ((failed_checks++))
    echo ""
    
    check_pulumi_operator || ((failed_checks++))
    echo ""
    
    check_argocd_applications || ((failed_checks++))
    echo ""
    
    check_pulumi_stacks || ((failed_checks++))
    echo ""
    
    check_infrastructure || ((failed_checks++))
    echo ""
    
    check_application_resources || ((failed_checks++))
    echo ""
    
    # Summary
    echo "=========================================="
    if [ "$failed_checks" -eq 0 ]; then
        print_success "🎉 All verification checks passed!"
        echo ""
        echo "Your GitOps Ultra deployment appears to be working correctly."
        echo ""
        echo "Next steps:"
        echo "  1. Access ArgoCD UI: make check-argocd"
        echo "  2. Monitor deployments: make status"
        echo "  3. Check logs: make dev-logs-infrastructure"
    else
        print_error "❌ $failed_checks verification check(s) failed"
        echo ""
        echo "Please review the warnings and errors above."
        echo "Common solutions:"
        echo "  1. Run 'make bootstrap' to install missing components"
        echo "  2. Run 'make deploy-infra' to deploy infrastructure"
        echo "  3. Run 'make deploy-k8s' to deploy applications"
        echo "  4. Check 'make status' for detailed information"
        
        return 1
    fi
}

# Parse command line arguments
case "${1:-all}" in
    "kubectl")
        check_kubectl
        ;;
    "argocd")
        check_argocd
        ;;
    "pulumi")
        check_pulumi_operator
        ;;
    "apps")
        check_argocd_applications
        ;;
    "stacks")
        check_pulumi_stacks
        ;;
    "infra")
        check_infrastructure
        ;;
    "resources")
        check_application_resources
        ;;
    "all")
        run_verification
        ;;
    *)
        echo "Usage: $0 [kubectl|argocd|pulumi|apps|stacks|infra|resources|all]"
        echo ""
        echo "  kubectl     - Check kubectl connectivity"
        echo "  argocd      - Check ArgoCD installation"
        echo "  pulumi      - Check Pulumi Kubernetes Operator"
        echo "  apps        - Check ArgoCD applications"
        echo "  stacks      - Check Pulumi Stacks"
        echo "  infra       - Check AWS infrastructure resources"
        echo "  resources   - Check application resources"
        echo "  all         - Run all checks (default)"
        exit 1
        ;;
esac
