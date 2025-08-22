#!/bin/bash
set -e

echo "🚀 Setting up GitOps Infrastructure Environment"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check prerequisites
print_status "Checking prerequisites..."

# Check Python 3
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install Python 3 first."
    exit 1
fi
print_success "Python 3 is available"

# Check pip
if ! command -v pip3 &> /dev/null && ! python3 -m pip --version &> /dev/null; then
    print_error "pip is not installed. Please install pip first."
    exit 1
fi
print_success "pip is available"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi
print_success "kubectl is available"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_warning "aws CLI is not installed. Installing..."
    if command -v brew &> /dev/null; then
        brew install awscli
    else
        print_error "Please install AWS CLI manually"
        exit 1
    fi
fi
print_success "aws CLI is available"

# Check Pulumi CLI (optional)
if ! command -v pulumi &> /dev/null; then
    print_warning "Pulumi CLI is not installed. Installing..."
    curl -fsSL https://get.pulumi.com | sh
    export PATH=$PATH:$HOME/.pulumi/bin
fi
print_success "Pulumi CLI is available"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    print_warning "Terraform is not installed. Installing..."
    if command -v brew &> /dev/null; then
        brew tap hashicorp/tap
        brew install hashicorp/tap/terraform
    else
        print_error "Please install Terraform manually"
        exit 1
    fi
fi
print_success "Terraform is available"

# Check kustomize
if ! command -v kustomize &> /dev/null; then
    print_warning "Kustomize is not installed. Installing..."
    if command -v brew &> /dev/null; then
        brew install kustomize
    else
        print_error "Please install Kustomize manually from https://kustomize.io/"
        exit 1
    fi
fi
print_success "Kustomize is available"

# Install ArgoCD CLI
print_status "Installing ArgoCD CLI..."
if ! command -v argocd &> /dev/null; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install argocd
        else
            curl -sSL -o argocd-darwin-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
            sudo install -m 555 argocd-darwin-amd64 /usr/local/bin/argocd
            rm argocd-darwin-amd64
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
    else
        print_error "Unsupported OS. Please install ArgoCD CLI manually."
    fi
fi
print_success "ArgoCD CLI is available"

# Check Kubernetes cluster connectivity
print_status "Checking Kubernetes cluster connectivity..."
if kubectl cluster-info &> /dev/null; then
    print_success "Connected to Kubernetes cluster"
    kubectl cluster-info
else
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

# Check AWS credentials
print_status "Checking AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    print_success "AWS credentials are configured"
    aws sts get-caller-identity
else
    print_error "AWS credentials are not configured. Please run 'aws configure'."
    exit 1
fi

# Install Python dependencies for Pulumi
print_status "Installing Pulumi Python dependencies..."
cd infrastructure/pulumi
if [[ ! -d "venv" ]]; then
    print_status "Creating Python virtual environment..."
    python3 -m venv venv
fi
source venv/bin/activate
pip install -r requirements.txt
print_success "Pulumi Python dependencies installed"
cd ../..

# Set up Git repository URL (if needed)
print_status "Repository configuration..."
REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ -z "$REPO_URL" ]]; then
    print_warning "No Git remote origin found. Please configure Git repository URLs manually in:"
    echo "  - bootstrap/bootstrap-apps.yaml"
    echo "  - argocd/infrastructure-app.yaml"
    echo "  - argocd/kubernetes-app.yaml"
    echo "  - pulumi-operator/infrastructure-stack.yaml"
else
    print_success "Git repository URL: $REPO_URL"
    print_warning "Please verify that repository URLs in YAML files match your actual repository"
fi

# Validate configurations
print_status "Validating configurations..."
make validate
print_success "All configurations are valid"

echo ""
print_success "🎉 Setup complete!"
echo ""
print_status "Next steps:"
echo "1. Update repository URLs in YAML files if needed"
echo "2. Run 'make bootstrap' to install ArgoCD and Pulumi Operator"
echo "3. Run 'make deploy-all' to deploy infrastructure and applications"
echo "4. Run 'make check-argocd' to access ArgoCD UI"
echo ""
print_status "For help, run: make help"
echo ""
print_status "Python virtual environment created at infrastructure/pulumi/venv"
echo "To activate manually: cd infrastructure/pulumi && source venv/bin/activate"
