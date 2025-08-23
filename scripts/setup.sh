#!/bin/bash

# GitOps Ultra - Setup Script
# Makes all scripts executable and performs initial setup

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 GitOps Ultra - Setup Script${NC}"
echo "==============================="
echo ""

echo "Making all scripts executable..."

# List of scripts to make executable
scripts=(
    "scripts/configure-repo.sh"
    "scripts/health-check.sh"
    "scripts/troubleshoot.sh"
    "scripts/verify-deployment.sh"
    "scripts/setup.sh"
    "scripts/clean-uninstall.sh"
    "scripts/python-setup.sh"
    "scripts/make-cleanup-executable.sh"
)

for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
        chmod +x "$script"
        echo -e "  ${GREEN}✅ Made $script executable${NC}"
    else
        echo -e "  ⚠️  Script not found: $script"
    fi
done

# Make Pulumi cleanup script executable if it exists
if [[ -f "infrastructure/pulumi/clean-venv.sh" ]]; then
    chmod +x "infrastructure/pulumi/clean-venv.sh"
    echo -e "  ${GREEN}✅ Made infrastructure/pulumi/clean-venv.sh executable${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Configure your repository: make configure-repo"
echo "2. Install dependencies: make install-deps"
echo "3. Run health checks: make quick-check"
echo "4. Bootstrap the system: make bootstrap"
echo ""
echo "For help: make help"
