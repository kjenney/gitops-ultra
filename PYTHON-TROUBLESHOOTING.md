# 🐍 Python/Pulumi Troubleshooting Guide

## Common Issues and Solutions

### ❌ **Package Installation Errors**

#### Problem: `ERROR: No matching distribution found for pulumi-terraform`
```bash
ERROR: No matching distribution found for pulumi-terraform<1.0.0,>=0.9.0
```

**✅ Solution**: This has been fixed! The project now uses pure Pulumi Python packages:
```bash
# Clean install
cd infrastructure/pulumi
rm -rf venv
make install-deps
```

#### Problem: Python version compatibility
```bash
ERROR: This package requires Python '>=3.7'
```

**✅ Solution**: Ensure you have Python 3.7 or higher:
```bash
python3 --version  # Should be 3.7+
# If not, install a newer Python version
```

### ❌ **Validation Errors**

#### Problem: `make validate` fails with Terraform errors
```bash
Error: Missing required provider registry.terraform.io/hashicorp/aws
```

**✅ Solution**: Use the new Python-focused validation:
```bash
# Use the updated validation (recommended)
make validate

# Or validate Python specifically
make validate-python

# Legacy Terraform validation (optional)
make validate-terraform
```

#### Problem: Terraform modules not initialized
**✅ Solution**: The Terraform modules are now legacy/optional:
- The project uses **pure Python Pulumi** 
- Terraform modules are kept for reference only
- Use `make validate-python` for the active implementation

### ❌ **Virtual Environment Issues**

#### Problem: Virtual environment not activated
```bash
ModuleNotFoundError: No module named 'pulumi'
```

**✅ Solution**: Always activate the virtual environment:
```bash
cd infrastructure/pulumi
source venv/bin/activate  # On Unix/Mac
# or
venv\Scripts\activate     # On Windows
```

#### Problem: Virtual environment corrupted
**✅ Solution**: Recreate the virtual environment:
```bash
cd infrastructure/pulumi
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### ❌ **Pulumi Configuration Issues**

#### Problem: No Pulumi stack configured
```bash
error: no stack selected
```

**✅ Solution**: Initialize a Pulumi stack:
```bash
make init-infrastructure
# or manually:
cd infrastructure/pulumi
source venv/bin/activate
pulumi stack init dev
```

#### Problem: AWS credentials not configured
```bash
error: failed to configure AWS SDK
```

**✅ Solution**: Configure AWS credentials:
```bash
aws configure
# or set environment variables:
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_DEFAULT_REGION=us-west-2
```

### ❌ **EKS/IRSA Issues**

#### Problem: EKS cluster not found
```bash
WARNING: EKS cluster 'myapp-dev-cluster' not found
```

**✅ Solution**: This is expected if you don't have an EKS cluster yet. The infrastructure will still work:
- IRSA will be configured but won't work until cluster exists
- You can create the cluster separately
- Or modify the prefix configuration to match your existing cluster

### ❌ **Import/Syntax Errors**

#### Problem: Import errors in Python code
```bash
ImportError: No module named 'pulumi_aws'
```

**✅ Solution**: 
1. Ensure virtual environment is activated
2. Reinstall dependencies:
```bash
cd infrastructure/pulumi
source venv/bin/activate
pip install -r requirements.txt
```

#### Problem: Syntax errors in __main__.py
**✅ Solution**: Test the syntax:
```bash
make test-pulumi  # This will check syntax and imports
```

## 🧪 **Testing Your Setup**

### Quick Test Commands
```bash
# Test full installation
make install-deps

# Test Pulumi specifically  
make test-pulumi

# Validate everything (Python-focused)
make validate

# Test with preview (doesn't deploy anything)
make dev-pulumi-preview
```

### Expected Output for `make test-pulumi`
```
Testing Pulumi installation...
✅ All Pulumi packages imported successfully
✅ Python syntax is valid  
✅ Pulumi configuration loaded successfully
```

### Expected Output for `make validate`
```
🐍 Validating Python/Pulumi configuration...
✅ Python environment active
✅ All Pulumi packages available
✅ Python syntax is valid
✅ Kubernetes manifests are valid
✅ ArgoCD installation is valid
✅ Pulumi Operator installation is valid
✅ ArgoCD applications are valid
✅ Python/Pulumi validation complete!
```

## 🔧 **Development Workflow**

### Recommended Development Process
```bash
# 1. Setup environment
make install-deps

# 2. Test installation
make test-pulumi

# 3. Validate everything
make validate

# 4. Initialize stack (if needed)
make init-infrastructure

# 5. Preview changes locally
make dev-pulumi-preview

# 6. Deploy via GitOps
make deploy-all
```

### Local Development Tips
```bash
# Always activate virtual environment first
cd infrastructure/pulumi
source venv/bin/activate

# Then use Pulumi commands
pulumi config
pulumi preview
pulumi up
pulumi stack output
```

## 🏗️ **Architecture Changes**

### **What Changed**
- ❌ **Before**: TypeScript + Terraform modules via `pulumi-terraform`
- ✅ **After**: Pure Python Pulumi with native AWS resources

### **Validation Changes**
- ❌ **Old**: `make validate` required Terraform initialization
- ✅ **New**: `make validate` focuses on Python/Pulumi (much faster)
- 🔧 **Legacy**: `make validate-terraform` for old modules (optional)

### **Benefits**
- ✅ Faster validation (no Terraform init required)
- ✅ Better error messages and debugging
- ✅ Simpler dependency management
- ✅ Full Python type safety and IDE support

## 🆘 **Getting Help**

### Debug Information
```bash
# Check Python installation
python3 --version
pip3 --version

# Check virtual environment
cd infrastructure/pulumi
source venv/bin/activate
pip list | grep pulumi

# Check Pulumi installation
pulumi version
pulumi whoami
```

### Architecture Status
```bash
# Check what's active
make validate          # Python implementation (active)
make validate-terraform # Terraform modules (legacy)

# See the difference
ls infrastructure/pulumi/        # Active Python code
ls infrastructure/terraform-modules/  # Legacy modules
```

### Log Files and Diagnostics
```bash
# Pulumi logs
pulumi logs

# Check AWS configuration
aws sts get-caller-identity

# Kubernetes connectivity
kubectl cluster-info
kubectl get nodes
```

### Reset Everything
If you encounter persistent issues:
```bash
# Clean up everything
cd infrastructure/pulumi
rm -rf venv
rm -rf .pulumi
cd ../..

# Start fresh
make install-deps
make init-infrastructure
make test-pulumi
make validate
```

## 📚 **Additional Resources**

- [Pulumi Python Documentation](https://www.pulumi.com/docs/intro/languages/python/)
- [Pulumi AWS Provider](https://www.pulumi.com/registry/packages/aws/)
- [Python Virtual Environments](https://docs.python.org/3/tutorial/venv.html)
- [AWS CLI Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)

## ✅ **Success Indicators**

You know everything is working when:
- `make test-pulumi` passes all checks
- `make validate` completes successfully (Python-focused)
- `make dev-pulumi-preview` shows your infrastructure plan
- No import errors when running Python commands
- Virtual environment contains all required packages

## 🎯 **Quick Fix Checklist**

If you're having issues, try these in order:

1. **Install dependencies**: `make install-deps`
2. **Test Pulumi**: `make test-pulumi`
3. **Validate configuration**: `make validate`
4. **Initialize stack**: `make init-infrastructure`
5. **Preview locally**: `make dev-pulumi-preview`

If any step fails, check the specific error message and refer to the relevant section above.
