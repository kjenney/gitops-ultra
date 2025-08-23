#!/bin/bash

echo "🧹 Cleaning up old virtual environment..."

cd "$(dirname "$0")"

# Check if we're in the right directory
if [[ ! -f "requirements.txt" || ! -f "__main__.py" ]]; then
    echo "❌ Error: This script must be run from the infrastructure/pulumi directory"
    exit 1
fi

echo "📁 Current directory: $(pwd)"

# Remove old virtual environment if it exists
if [[ -d "venv" ]]; then
    echo "🗑️  Removing old virtual environment..."
    rm -rf venv
    echo "✅ Old virtual environment removed"
else
    echo "ℹ️  No existing virtual environment found"
fi

# Remove the marker file
rm -f venv-recreate.txt

echo ""
echo "✅ Cleanup complete!"
echo "💡 Now run 'make install-deps' to create a fresh virtual environment"
