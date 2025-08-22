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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if component is specified
if [[ $# -eq 0 ]]; then
    echo "🔍 GitOps Troubleshooting Helper"
    echo "==============================="
    echo ""
    echo "Usage: $0 <component>"
    echo ""
    echo "Available components:"
    echo "  argocd         - Troubleshoot ArgoCD issues"
    echo "  pulumi         - Troubleshoot Pulumi Operator issues"
    echo "  infrastructure - Troubleshoot infrastructure deployment"
    echo "  application    - Troubleshoot application deployment"
    echo "  aws            - Troubleshoot AWS resource issues"
    echo "  irsa           - Troubleshoot IRSA (IAM Roles for Service Accounts)"
    echo "  all            - Run all troubleshooting checks"
    exit 1
fi

COMPONENT=$1

troubleshoot_argocd() {
    print_status "🔍 Troubleshooting ArgoCD..."
    
    # Check namespace
    if ! kubectl get namespace argocd &> /dev/null; then
        print_error "ArgoCD namespace not found"
        print_status "Run: kubectl create namespace argocd"
        return 1
    fi
    
    # Check ArgoCD server pod
    print_status "Checking ArgoCD server pods..."
    kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
    
    # Check ArgoCD server logs
    print_status "Recent ArgoCD server logs:"
    kubectl logs --tail=20 -l app.kubernetes.io/name=argocd-server -n argocd || print_error "Cannot get ArgoCD server logs"
    
    # Check ArgoCD application controller
    print_status "Checking ArgoCD application controller..."
    kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller
    
    # Check applications
    print_status "ArgoCD applications:"
    kubectl get applications -n argocd -o wide || print_error "No applications found"
    
    # Check for common issues
    print_status "Checking for common issues..."
    
    # Check if applications are out of sync
    OUT_OF_SYNC=$(kubectl get applications -n argocd -o jsonpath='{.items[?(@.status.sync.status!="Synced")].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$OUT_OF_SYNC" ]]; then
        print_warning "Applications out of sync: $OUT_OF_SYNC"
        for app in $OUT_OF_SYNC; do
            print_status "Details for $app:"
            kubectl get application $app -n argocd -o jsonpath='{.status.sync}' | jq . 2>/dev/null || echo "Cannot parse sync status"
        done
    fi
    
    # Check for unhealthy applications
    UNHEALTHY=$(kubectl get applications -n argocd -o jsonpath='{.items[?(@.status.health.status!="Healthy")].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$UNHEALTHY" ]]; then
        print_warning "Unhealthy applications: $UNHEALTHY"
    fi
    
    print_status "ArgoCD troubleshooting complete"
}

troubleshoot_pulumi() {
    print_status "🔍 Troubleshooting Pulumi Operator..."
    
    # Check namespace
    if ! kubectl get namespace pulumi-system &> /dev/null; then
        print_error "Pulumi system namespace not found"
        print_status "Run: kubectl create namespace pulumi-system"
        return 1
    fi
    
    # Check Pulumi operator pod
    print_status "Checking Pulumi operator pods..."
    kubectl get pods -n pulumi-system -l app.kubernetes.io/name=pulumi-operator
    
    # Check Pulumi operator logs
    print_status "Recent Pulumi operator logs:"
    kubectl logs --tail=20 -l app.kubernetes.io/name=pulumi-operator -n pulumi-system || print_error "Cannot get Pulumi operator logs"
    
    # Check Pulumi stacks
    print_status "Pulumi stacks:"
    kubectl get stacks -n pulumi-system -o wide || print_error "No stacks found"
    
    # Check stack status details
    STACKS=$(kubectl get stacks -n pulumi-system -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    for stack in $STACKS; do
        print_status "Stack details for $stack:"
        kubectl get stack $stack -n pulumi-system -o jsonpath='{.status.lastUpdate}' | jq . 2>/dev/null || echo "Cannot parse stack status"
    done
    
    # Check secrets
    print_status "Checking Pulumi secrets..."
    kubectl get secrets -n pulumi-system | grep -E "(pulumi|aws)" || print_warning "No Pulumi/AWS secrets found"
    
    print_status "Pulumi operator troubleshooting complete"
}

troubleshoot_infrastructure() {
    print_status "🔍 Troubleshooting Infrastructure..."
    
    # Check if infrastructure application exists
    if kubectl get application myapp-infrastructure -n argocd &> /dev/null; then
        print_status "Infrastructure application status:"
        kubectl get application myapp-infrastructure -n argocd -o yaml | grep -A 20 "status:" || print_error "Cannot get application status"
    else
        print_error "Infrastructure application not found"
        print_status "Run: kubectl apply -f argocd/infrastructure-app.yaml"
        return 1
    fi
    
    # Check Pulumi stack corresponding to infrastructure
    if kubectl get stack myapp-infrastructure -n pulumi-system &> /dev/null; then
        print_status "Infrastructure stack status:"
        kubectl describe stack myapp-infrastructure -n pulumi-system
    else
        print_warning "Infrastructure stack not found in pulumi-system namespace"
    fi
    
    print_status "Infrastructure troubleshooting complete"
}

troubleshoot_application() {
    print_status "🔍 Troubleshooting Application..."
    
    # Check if application namespace exists
    if ! kubectl get namespace myapp-dev &> /dev/null; then
        print_error "Application namespace (myapp-dev) not found"
        print_status "Run: kubectl apply -f kubernetes/namespace.yaml"
        return 1
    fi
    
    # Check application resources
    print_status "Application resources in myapp-dev namespace:"
    kubectl get all -n myapp-dev
    
    # Check application deployment logs
    print_status "Application deployment logs:"
    kubectl logs --tail=20 -l app.kubernetes.io/component=application -n myapp-dev || print_warning "No application pods found"
    
    # Check service account
    print_status "Service account details:"
    kubectl describe serviceaccount myapp-dev-service-account -n myapp-dev || print_error "Service account not found"
    
    # Check config map
    print_status "ConfigMap details:"
    kubectl describe configmap myapp-dev-aws-resources -n myapp-dev || print_error "ConfigMap not found"
    
    print_status "Application troubleshooting complete"
}

troubleshoot_aws() {
    print_status "🔍 Troubleshooting AWS Resources..."
    
    # Check AWS CLI availability
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found"
        return 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid"
        print_status "Run: aws configure"
        return 1
    fi
    
    print_status "AWS Account Info:"
    aws sts get-caller-identity
    
    # Check S3 buckets
    print_status "S3 buckets with myapp-dev prefix:"
    aws s3api list-buckets --query 'Buckets[?contains(Name, `myapp-dev`)]' || print_warning "No matching S3 buckets found"
    
    # Check SQS queues
    print_status "SQS queues with myapp-dev prefix:"
    aws sqs list-queues --queue-name-prefix myapp-dev || print_warning "No matching SQS queues found"
    
    # Check IAM roles
    print_status "IAM roles with myapp-dev prefix:"
    aws iam list-roles --query 'Roles[?contains(RoleName, `myapp-dev`)].[RoleName,Arn]' --output table || print_warning "No matching IAM roles found"
    
    print_status "AWS troubleshooting complete"
}

troubleshoot_irsa() {
    print_status "🔍 Troubleshooting IRSA (IAM Roles for Service Accounts)..."
    
    # Check if we're on EKS
    CLUSTER_INFO=$(kubectl cluster-info | grep -o "eks.*amazonaws.com" || echo "")
    if [[ -z "$CLUSTER_INFO" ]]; then
        print_warning "This doesn't appear to be an EKS cluster. IRSA may not be available."
    else
        print_success "EKS cluster detected: $CLUSTER_INFO"
    fi
    
    # Check service account annotations
    print_status "Service account IRSA configuration:"
    SA_ROLE=$(kubectl get serviceaccount myapp-dev-service-account -n myapp-dev -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>/dev/null || echo "")
    if [[ -n "$SA_ROLE" ]]; then
        print_success "IRSA role configured: $SA_ROLE"
        
        # Check if role exists in AWS
        ROLE_NAME=$(echo $SA_ROLE | grep -o '[^/]*$')
        if aws iam get-role --role-name $ROLE_NAME &> /dev/null; then
            print_success "IAM role exists in AWS"
            
            # Check trust policy
            print_status "IAM role trust policy:"
            aws iam get-role --role-name $ROLE_NAME --query 'Role.AssumeRolePolicyDocument' | jq .
        else
            print_error "IAM role does not exist in AWS"
        fi
    else
        print_error "IRSA role annotation not found on service account"
    fi
    
    # Check if pods have AWS credentials
    POD_NAME=$(kubectl get pods -n myapp-dev -l app.kubernetes.io/component=application -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$POD_NAME" ]]; then
        print_status "Checking AWS credentials in pod $POD_NAME:"
        kubectl exec $POD_NAME -n myapp-dev -- env | grep AWS || print_warning "No AWS environment variables found"
        
        print_status "Checking AWS STS identity in pod:"
        kubectl exec $POD_NAME -n myapp-dev -- aws sts get-caller-identity 2>/dev/null || print_error "Cannot assume role or AWS CLI not available in pod"
    else
        print_warning "No application pods found to test IRSA"
    fi
    
    print_status "IRSA troubleshooting complete"
}

# Main execution
case $COMPONENT in
    "argocd")
        troubleshoot_argocd
        ;;
    "pulumi")
        troubleshoot_pulumi
        ;;
    "infrastructure")
        troubleshoot_infrastructure
        ;;
    "application")
        troubleshoot_application
        ;;
    "aws")
        troubleshoot_aws
        ;;
    "irsa")
        troubleshoot_irsa
        ;;
    "all")
        print_status "Running comprehensive troubleshooting..."
        troubleshoot_argocd
        echo ""
        troubleshoot_pulumi
        echo ""
        troubleshoot_infrastructure
        echo ""
        troubleshoot_application
        echo ""
        troubleshoot_aws
        echo ""
        troubleshoot_irsa
        ;;
    *)
        print_error "Unknown component: $COMPONENT"
        print_status "Available components: argocd, pulumi, infrastructure, application, aws, irsa, all"
        exit 1
        ;;
esac

print_success "🎉 Troubleshooting complete!"
