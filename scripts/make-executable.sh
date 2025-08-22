#!/bin/bash

# Make all scripts executable
chmod +x scripts/setup.sh
chmod +x scripts/update-repo-urls.sh
chmod +x scripts/health-check.sh
chmod +x scripts/troubleshoot.sh
chmod +x scripts/clean-uninstall.sh

echo "✅ All scripts are now executable"
echo ""
echo "Available scripts:"
echo "  ./scripts/setup.sh              - Initial environment setup"
echo "  ./scripts/update-repo-urls.sh   - Update Git repository URLs in YAML files"
echo "  ./scripts/health-check.sh       - Check overall system health"
echo "  ./scripts/troubleshoot.sh       - Troubleshoot specific components"
echo "  ./scripts/clean-uninstall.sh    - Complete cleanup and uninstall"
