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

## 🔧 **Development Workflow**

### Recommended Development Process
```bash
# 1. Setup environment
make install-deps

# 2. Test installation
make test-pulumi

# 3. Initialize stack (if needed)
make init-infrastructure

# 4. Preview changes locally
make dev-pulumi-preview

# 5. Deploy via GitOps
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
```

## 📚 **Additional Resources**

- [Pulumi Python Documentation](https://www.pulumi.com/docs/intro/languages/python/)
- [Pulumi AWS Provider](https://www.pulumi.com/registry/packages/aws/)
- [Python Virtual Environments](https://docs.python.org/3/tutorial/venv.html)
- [AWS CLI Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)

## ✅ **Success Indicators**

You know everything is working when:
- `make test-pulumi` passes all checks
- `make dev-pulumi-preview` shows your infrastructure plan
- No import errors when running Python commands
- Virtual environment contains all required packages
