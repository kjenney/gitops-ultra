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

echo "🔧 Updating Git Repository URLs"
echo "==============================="

# Get current repository URL
REPO_URL=$(git remote get-url origin 2>/dev/null || echo "")

if [[ -z "$REPO_URL" ]]; then
    print_error "No Git remote origin found. Please add your repository:"
    echo "git remote add origin https://github.com/your-org/your-repo.git"
    exit 1
fi

print_status "Current repository URL: $REPO_URL"

# Confirm with user
read -p "Update all YAML files with this repository URL? (y/N): " confirm
if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    print_warning "Skipping repository URL update"
    exit 0
fi

# Files to update
files=(
    "bootstrap/bootstrap-apps.yaml"
    "argocd/infrastructure-app.yaml"
    "argocd/kubernetes-app.yaml"
    "pulumi-operator/infrastructure-stack.yaml"
)

# Update each file
for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
        print_status "Updating $file..."
        # Replace placeholder URL with actual repository URL
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s|https://github.com/your-org/your-repo.git|$REPO_URL|g" "$file"
        else
            # Linux
            sed -i "s|https://github.com/your-org/your-repo.git|$REPO_URL|g" "$file"
        fi
        print_success "Updated $file"
    else
        print_warning "File not found: $file"
    fi
done

print_success "🎉 Repository URLs updated successfully!"
print_status "You can now run: make bootstrap"
