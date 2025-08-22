#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🔍 GitOps Infrastructure Health Check"
echo "====================================="

# Check ArgoCD installation
print_status "Checking ArgoCD installation..."
if kubectl get namespace argocd &> /dev/null; then
    if kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --field-selector=status.phase=Running &> /dev/null; then
        print_success "ArgoCD is running"
        
        # Get ArgoCD server status
        ARGOCD_PODS=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --field-selector=status.phase=Running --no-headers | wc -l)
        print_status "ArgoCD server pods running: $ARGOCD_PODS"
        
        # Check ArgoCD applications
        APP_COUNT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
        print_status "ArgoCD applications deployed: $APP_COUNT"
        
        if [[ $APP_COUNT -gt 0 ]]; then
            print_status "Application status:"
            kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status" 2>/dev/null || print_error "Cannot get application status"
        fi
    else
        print_error "ArgoCD pods are not running"
    fi
else
    print_error "ArgoCD namespace not found"
fi

echo ""

# Check Pulumi Operator
print_status "Checking Pulumi Operator..."
if kubectl get namespace pulumi-system &> /dev/null; then
    if kubectl get pods -n pulumi-system -l app.kubernetes.io/name=pulumi-operator --field-selector=status.phase=Running &> /dev/null; then
        print_success "Pulumi Operator is running"
        
        # Check Pulumi stacks
        STACK_COUNT=$(kubectl get stacks -n pulumi-system --no-headers 2>/dev/null | wc -l || echo "0")
        print_status "Pulumi stacks deployed: $STACK_COUNT"
        
        if [[ $STACK_COUNT -gt 0 ]]; then
            print_status "Stack status:"
            kubectl get stacks -n pulumi-system -o custom-columns="NAME:.metadata.name,STATE:.status.lastUpdate.state,RESULT:.status.lastUpdate.result" 2>/dev/null || print_error "Cannot get stack status"
        fi
    else
        print_error "Pulumi Operator pods are not running"
    fi
else
    print_error "Pulumi Operator namespace not found"
fi

echo ""

# Check application namespace and resources
print_status "Checking application resources..."
if kubectl get namespace myapp-dev &> /dev/null; then
    print_success "Application namespace (myapp-dev) exists"
    
    # Check service account
    if kubectl get serviceaccount myapp-dev-service-account -n myapp-dev &> /dev/null; then
        print_success "Service account exists"
        
        # Check IRSA annotation
        ROLE_ARN=$(kubectl get serviceaccount myapp-dev-service-account -n myapp-dev -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")
        if [[ -n "$ROLE_ARN" ]]; then
            print_success "IRSA role configured: $ROLE_ARN"
        else
            print_error "IRSA role annotation missing"
        fi
    else
        print_error "Service account not found"
    fi
    
    # Check deployments
    DEPLOYMENT_COUNT=$(kubectl get deployments -n myapp-dev --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ $DEPLOYMENT_COUNT -gt 0 ]]; then
        print_success "Deployments found: $DEPLOYMENT_COUNT"
        kubectl get deployments -n myapp-dev -o custom-columns="NAME:.metadata.name,READY:.status.readyReplicas,AVAILABLE:.status.availableReplicas,AGE:.metadata.creationTimestamp" 2>/dev/null
    else
        print_error "No deployments found"
    fi
    
    # Check services
    SERVICE_COUNT=$(kubectl get services -n myapp-dev --no-headers 2>/dev/null | wc -l || echo "0")
    if [[ $SERVICE_COUNT -gt 0 ]]; then
        print_success "Services found: $SERVICE_COUNT"
    else
        print_error "No services found"
    fi
else
    print_error "Application namespace (myapp-dev) not found"
fi

echo ""

# Check AWS resources
print_status "Checking AWS resources..."
if command -v aws &> /dev/null; then
    if aws sts get-caller-identity &> /dev/null; then
        print_success "AWS credentials are valid"
        
        # Check S3 buckets
        S3_BUCKETS=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `myapp-dev`)].Name' --output text 2>/dev/null || echo "")
        if [[ -n "$S3_BUCKETS" ]]; then
            print_success "S3 buckets found: $S3_BUCKETS"
        else
            print_error "No S3 buckets found with myapp-dev prefix"
        fi
        
        # Check SQS queues
        SQS_QUEUES=$(aws sqs list-queues --queue-name-prefix myapp-dev --query 'QueueUrls' --output text 2>/dev/null || echo "")
        if [[ -n "$SQS_QUEUES" ]]; then
            print_success "SQS queues found"
        else
            print_error "No SQS queues found with myapp-dev prefix"
        fi
    else
        print_error "AWS credentials are not valid"
    fi
else
    print_error "AWS CLI not found"
fi

echo ""

# Overall health summary
print_status "Health Summary:"
if kubectl get applications -n argocd --no-headers 2>/dev/null | grep -q "Synced.*Healthy"; then
    print_success "✅ GitOps pipeline is healthy"
else
    print_error "❌ GitOps pipeline has issues"
fi

echo ""
print_status "For detailed troubleshooting, run:"
echo "  - kubectl get applications -n argocd"
echo "  - kubectl get stacks -n pulumi-system"
echo "  - kubectl logs -f deployment/argocd-application-controller -n argocd"
echo "  - kubectl logs -f deployment/pulumi-operator -n pulumi-system"
