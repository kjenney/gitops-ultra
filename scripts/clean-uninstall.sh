#!/bin/bash
set -e

echo "🧹 Clean Uninstall of GitOps Infrastructure"
echo "==========================================="

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

# Confirm deletion
read -p "⚠️  This will completely remove all GitOps infrastructure. Are you sure? (y/N): " confirm
if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    print_warning "Cleanup cancelled"
    exit 0
fi

# Check if we should also clean AWS resources
read -p "🗑️  Also attempt to clean up AWS resources (S3, SQS, IAM)? (y/N): " clean_aws
CLEAN_AWS=false
if [[ $clean_aws == [yY] || $clean_aws == [yY][eE][sS] ]]; then
    CLEAN_AWS=true
fi

print_status "Starting cleanup process..."

# Step 1: Remove application resources
print_status "Removing application resources..."
kubectl delete -f argocd/kubernetes-app.yaml -n argocd --ignore-not-found=true
kubectl delete namespace myapp-dev --ignore-not-found=true --timeout=120s
print_success "Application resources removed"

# Step 2: Remove infrastructure resources  
print_status "Removing infrastructure resources..."
kubectl delete -f argocd/infrastructure-app.yaml -n argocd --ignore-not-found=true

# Wait for Pulumi stack to be cleaned up
print_status "Waiting for infrastructure cleanup..."
sleep 30

# Force remove any remaining stacks
kubectl delete stacks --all -n pulumi-system --ignore-not-found=true --timeout=300s
print_success "Infrastructure resources removed"

# Step 3: Remove bootstrap applications
print_status "Removing bootstrap applications..."
kubectl delete -f bootstrap/bootstrap-apps.yaml -n argocd --ignore-not-found=true
print_success "Bootstrap applications removed"

# Step 4: Remove Pulumi Operator
print_status "Removing Pulumi Operator..."
kubectl delete -k pulumi-operator/ --ignore-not-found=true --timeout=120s
kubectl delete namespace pulumi-system --ignore-not-found=true --timeout=120s
print_success "Pulumi Operator removed"

# Step 5: Remove ArgoCD
print_status "Removing ArgoCD..."
kubectl delete -k argocd-install/ --ignore-not-found=true --timeout=120s
kubectl delete namespace argocd --ignore-not-found=true --timeout=120s
print_success "ArgoCD removed"

# Step 6: Clean AWS resources if requested
if [[ $CLEAN_AWS == true ]]; then
    print_status "Cleaning AWS resources..."
    
    if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
        # Clean S3 buckets
        print_status "Cleaning S3 buckets..."
        S3_BUCKETS=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `myapp-dev`)].Name' --output text 2>/dev/null || echo "")
        for bucket in $S3_BUCKETS; do
            print_status "Emptying and deleting S3 bucket: $bucket"
            aws s3 rm "s3://$bucket" --recursive 2>/dev/null || print_warning "Could not empty bucket $bucket"
            aws s3api delete-bucket --bucket "$bucket" 2>/dev/null || print_warning "Could not delete bucket $bucket"
        done
        
        # Clean SQS queues
        print_status "Cleaning SQS queues..."
        SQS_QUEUES=$(aws sqs list-queues --queue-name-prefix myapp-dev --query 'QueueUrls[]' --output text 2>/dev/null || echo "")
        for queue_url in $SQS_QUEUES; do
            print_status "Deleting SQS queue: $queue_url"
            aws sqs delete-queue --queue-url "$queue_url" 2>/dev/null || print_warning "Could not delete queue $queue_url"
        done
        
        # Clean IAM policies and roles
        print_status "Cleaning IAM resources..."
        
        # List and delete policies
        POLICIES=$(aws iam list-policies --scope Local --query 'Policies[?contains(PolicyName, `myapp-dev`)].PolicyName' --output text 2>/dev/null || echo "")
        for policy in $POLICIES; do
            # Detach from roles first
            POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName==\`$policy\`].Arn" --output text)
            ATTACHED_ROLES=$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" --query 'PolicyRoles[].RoleName' --output text 2>/dev/null || echo "")
            for role in $ATTACHED_ROLES; do
                print_status "Detaching policy $policy from role $role"
                aws iam detach-role-policy --role-name "$role" --policy-arn "$POLICY_ARN" 2>/dev/null || print_warning "Could not detach policy from role"
            done
            
            print_status "Deleting IAM policy: $policy"
            aws iam delete-policy --policy-arn "$POLICY_ARN" 2>/dev/null || print_warning "Could not delete policy $policy"
        done
        
        # Delete roles
        ROLES=$(aws iam list-roles --query 'Roles[?contains(RoleName, `myapp-dev`)].RoleName' --output text 2>/dev/null || echo "")
        for role in $ROLES; do
            print_status "Deleting IAM role: $role"
            aws iam delete-role --role-name "$role" 2>/dev/null || print_warning "Could not delete role $role"
        done
        
        print_success "AWS resources cleaned"
    else
        print_warning "AWS CLI not available or not configured. Skipping AWS cleanup."
    fi
fi

# Step 7: Clean local Pulumi state (if exists)
if [[ -d "infrastructure/pulumi/.pulumi" ]]; then
    print_status "Cleaning local Pulumi state..."
    rm -rf infrastructure/pulumi/.pulumi
    print_success "Local Pulumi state cleaned"
fi

# Final verification
print_status "Verifying cleanup..."

# Check for remaining namespaces
REMAINING_NS=$(kubectl get namespaces | grep -E "(argocd|pulumi-system|myapp-dev)" || echo "")
if [[ -n "$REMAINING_NS" ]]; then
    print_warning "Some namespaces may still be terminating:"
    echo "$REMAINING_NS"
else
    print_success "All namespaces removed"
fi

# Check for remaining AWS resources
if [[ $CLEAN_AWS == true ]] && command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
    REMAINING_S3=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `myapp-dev`)].Name' --output text 2>/dev/null || echo "")
    REMAINING_SQS=$(aws sqs list-queues --queue-name-prefix myapp-dev --query 'QueueUrls' --output text 2>/dev/null || echo "")
    
    if [[ -n "$REMAINING_S3" ]] || [[ -n "$REMAINING_SQS" ]]; then
        print_warning "Some AWS resources may still exist:"
        [[ -n "$REMAINING_S3" ]] && echo "S3: $REMAINING_S3"
        [[ -n "$REMAINING_SQS" ]] && echo "SQS: $REMAINING_SQS"
    else
        print_success "All AWS resources cleaned"
    fi
fi

echo ""
print_success "🎉 Cleanup complete!"
print_status "Your cluster is now clean. You can run 'make bootstrap' to reinstall."

if [[ $CLEAN_AWS == true ]]; then
    print_warning "Note: Some AWS resources might take time to be fully deleted."
    print_status "Check AWS console to verify complete removal."
fi
