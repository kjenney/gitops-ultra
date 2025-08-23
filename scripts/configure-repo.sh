#!/bin/bash

# Repository Configuration Script
# This script helps you configure the GitOps Ultra project with your actual Git repository

set -e

REPO_URL=""
DEFAULT_BRANCH="main"
CURRENT_DIR=$(pwd)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 GitOps Ultra Repository Configuration${NC}"
echo "======================================"
echo ""

# Function to check if we're in the right directory
check_directory() {
    if [[ ! -f "Makefile" ]] || [[ ! -d "bootstrap" ]] || [[ ! -d "infrastructure" ]]; then
        echo -e "${RED}❌ Error: This script must be run from the gitops-ultra project root directory${NC}"
        echo "   Please navigate to the directory containing the Makefile and try again."
        exit 1
    fi
}

# Function to get repository URL from user
get_repo_url() {
    echo -e "${YELLOW}📝 Enter your Git repository URL:${NC}"
    echo "   Examples:"
    echo "   - https://github.com/your-org/gitops-ultra"
    echo "   - https://gitlab.com/your-org/gitops-ultra"
    echo "   - git@github.com:your-org/gitops-ultra.git"
    echo ""
    read -p "Repository URL: " REPO_URL
    
    if [[ -z "$REPO_URL" ]]; then
        echo -e "${RED}❌ Repository URL cannot be empty${NC}"
        exit 1
    fi
}

# Function to get default branch
get_branch() {
    echo ""
    echo -e "${YELLOW}🌿 What is your default branch name?${NC}"
    read -p "Default branch (default: main): " input_branch
    if [[ -n "$input_branch" ]]; then
        DEFAULT_BRANCH="$input_branch"
    fi
}

# Function to update files with repository URL
update_files() {
    echo ""
    echo -e "${BLUE}🔄 Updating configuration files...${NC}"
    
    # Files that need repo URL updates
    files_to_update=(
        "bootstrap/bootstrap-apps.yaml"
        "bootstrap/core/namespaces.yaml"
        "bootstrap/core/infrastructure.yaml"
        "argocd/infrastructure-app.yaml"
        "argocd/kubernetes-app.yaml"
        "infrastructure/stacks/infrastructure-stack.yaml"
    )
    
    for file in "${files_to_update[@]}"; do
        if [[ -f "$file" ]]; then
            echo "  📄 Updating $file"
            # Update repository URL
            sed -i.bak "s|https://github.com/your-org/gitops-ultra|$REPO_URL|g" "$file"
            # Update branch name
            sed -i.bak "s|branch: main|branch: $DEFAULT_BRANCH|g" "$file"
            # Clean up backup files
            rm -f "$file.bak"
        else
            echo -e "  ${YELLOW}⚠️  File not found: $file${NC}"
        fi
    done
}

# Function to update Pulumi configuration
update_pulumi_config() {
    echo ""
    echo -e "${BLUE}🔧 Updating Pulumi configuration...${NC}"
    
    if [[ -f "infrastructure/pulumi/Pulumi.dev.yaml" ]]; then
        echo "  📄 Found Pulumi.dev.yaml"
        # You might want to update any repository references here too
    fi
}

# Function to show next steps
show_next_steps() {
    echo ""
    echo -e "${GREEN}✅ Configuration complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "1. 🔐 Update secrets in infrastructure/stacks/infrastructure-stack.yaml:"
    echo "   - Generate a strong Pulumi passphrase"
    echo "   - Encode it with: echo -n 'your-passphrase' | base64"
    echo "   - Update the 'passphrase' field in the secret"
    echo ""
    echo "2. ☁️  Configure AWS credentials (choose one):"
    echo "   - Use IRSA (recommended for EKS)"
    echo "   - Add AWS credentials to the secret"
    echo "   - Use AWS profiles or environment variables"
    echo ""
    echo "3. 🚀 Deploy the infrastructure:"
    echo "   make quick-check    # Verify prerequisites"
    echo "   make bootstrap      # Install ArgoCD and operators"
    echo "   make deploy-infra   # Deploy infrastructure"
    echo "   make deploy-k8s     # Deploy applications"
    echo ""
    echo "4. 🔍 Monitor the deployment:"
    echo "   make status         # Check overall status"
    echo "   make check-argocd   # Get ArgoCD access info"
    echo ""
    echo -e "${YELLOW}💡 Remember to commit and push your changes to your Git repository!${NC}"
}

# Main execution
main() {
    check_directory
    get_repo_url
    get_branch
    update_files
    update_pulumi_config
    show_next_steps
}

# Run the script
main
