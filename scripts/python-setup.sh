#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐍 GitOps Ultra - Python Setup${NC}"
echo "================================="

# Make scripts executable
chmod +x infrastructure/pulumi/clean-venv.sh
chmod +x infrastructure/pulumi/cleanup-deprecated.sh

echo -e "${GREEN}✅ Made Python scripts executable${NC}"

# Check if virtual environment needs cleanup
if [[ -d "infrastructure/pulumi/venv" ]]; then
    echo -e "${YELLOW}⚠️  Found existing virtual environment${NC}"
    read -p "🤔 Clean up old virtual environment? (recommended) (y/N): " confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        ./infrastructure/pulumi/clean-venv.sh
    fi
fi

echo ""
echo -e "${GREEN}🚀 Ready to install dependencies!${NC}"
echo ""
echo "Next steps:"
echo "1. Run: make install-deps"
echo "2. Test: make test-pulumi"
echo "3. Deploy: make deploy-all"
echo ""
echo "For troubleshooting, see: PYTHON-TROUBLESHOOTING.md"
