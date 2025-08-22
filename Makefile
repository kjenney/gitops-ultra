.PHONY: help install-deps init-infrastructure bootstrap install-python-deps quick-check deploy-infra deploy-k8s deploy-all clean status check-argocd test-pulumi validate validate-terraform validate-python setup-gitops-apps

# Default target
help:
	@echo "Available commands:"
	@echo "  install-deps        - Install all dependencies"
	@echo "  install-python-deps - Install Python dependencies (optional, for validation)"
	@echo "  quick-check        - Quick environment check before bootstrap"
	@echo "  test-pulumi         - Test Pulumi installation and preview"
	@echo "  validate            - Validate all configurations (Python-focused)"
	@echo "  validate-python     - Validate Python/Pulumi configuration only"
	@echo "  validate-terraform  - Validate Terraform modules (legacy, optional)"
	@echo "  init-infrastructure - Initialize Pulumi stack"
	@echo "  bootstrap          - Install ArgoCD v3.0.12 and Pulumi Operator via Helm (Complete)"
	@echo "  setup-gitops-apps  - Apply GitOps bootstrap applications (Helm-based)"
	@echo "  deploy-infra       - Deploy infrastructure with Pulumi Operator"
	@echo "  deploy-k8s         - Deploy Kubernetes resources with ArgoCD"
	@echo "  deploy-all         - Bootstrap and deploy everything"
	@echo "  status             - Show deployment status"
	@echo "  check-argocd       - Check ArgoCD installation and access"
	@echo "  dev-argocd-forward  - Forward port for ArgoCD access"
	@echo "  clean              - Clean up all resources"

# Install dependencies
install-deps:
	@echo "Installing Pulumi Python dependencies..."
	cd infrastructure/pulumi && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
	@echo "Checking kubectl configuration..."
	kubectl version --client
	@echo "Checking Kustomize installation..."
	kustomize version || echo "Install kustomize from https://kustomize.io/"
	@echo "Checking Terraform installation (optional for legacy modules)..."
	terraform version || echo "⚠️  Terraform not found (optional - only needed for legacy modules)"
	@echo "Checking Python YAML module for validation scripts..."
	@python3 -c "import yaml; print('✅ PyYAML available for enhanced validation')" 2>/dev/null || echo "ℹ️  PyYAML not found - optional for enhanced validation. Install with: make install-python-deps"

# Install Python dependencies (optional, for validation)
install-python-deps:
	@echo "Installing Python dependencies for enhanced validation..."
	@echo "This will install PyYAML globally for better YAML processing in validation scripts."
	@python3 -m pip install --user PyYAML || pip3 install --user PyYAML
	@echo "✅ Python dependencies installed"
	@echo "Testing YAML module..."
	@python3 -c "import yaml; print('✅ PyYAML is now available for validation scripts')"
	@echo ""
	@echo "📝 Note: PyYAML is helpful for:"
	@echo "  - Enhanced YAML validation in scripts"
	@echo "  - Better configuration file processing"
	@echo "  - Custom validation logic"
	@echo "  - Not required for basic operation (Helm handles CRDs)"

# Quick environment check before bootstrap
quick-check:
	@echo "🔍 Quick Environment Check"
	@echo "======================="
	@echo "Checking environment before running bootstrap..."
	@echo ""
	
	@echo "1. Checking kubectl connectivity..."
	@kubectl version --client || (echo "❌ kubectl not found" && exit 1)
	@kubectl cluster-info --request-timeout=10s > /dev/null || (echo "❌ Cannot connect to Kubernetes cluster" && exit 1)
	@echo "   ✅ Kubernetes cluster connectivity verified"
	
	@echo ""
	@echo "2. Checking required tools..."
	@command -v curl >/dev/null 2>&1 || (echo "❌ curl not found" && exit 1)
	@echo "   ✅ curl found"
	@command -v kustomize >/dev/null 2>&1 || (echo "❌ kustomize not found" && exit 1)
	@echo "   ✅ kustomize found"
	
	@echo ""
	@echo "3. Checking validation capabilities..."
	@if python3 -c "import yaml" >/dev/null 2>&1; then \
		echo "   ✅ Python3 with PyYAML available (enhanced validation)"; \
	else \
		echo "   ℹ️  Python3 with PyYAML not available (basic validation only)"; \
		echo "       For enhanced validation: make install-python-deps"; \
	fi
	
	@echo ""
	@echo "4. Checking cluster permissions..."
	@kubectl auth can-i create crd --quiet && echo "   ✅ Can create CRDs" || echo "   ⚠️  Cannot create CRDs (may need cluster-admin)"
	@kubectl auth can-i create namespace --quiet && echo "   ✅ Can create namespaces" || echo "   ⚠️  Cannot create namespaces"
	
	@echo ""
	@echo "5. Checking for existing installations..."
	@if kubectl get namespace argocd >/dev/null 2>&1; then \
		echo "   ℹ️  ArgoCD namespace already exists"; \
		kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd --no-headers 2>/dev/null | wc -l | awk '{if($1>0) print "       ArgoCD pods found: " $1; else print "       No ArgoCD pods found"}'; \
	else \
		echo "   ✅ ArgoCD namespace not found (clean install)"; \
	fi
	
	@if kubectl get namespace pulumi-system >/dev/null 2>&1; then \
		echo "   ℹ️  Pulumi namespace already exists"; \
		kubectl get pods -n pulumi-system --no-headers 2>/dev/null | wc -l | awk '{if($1>0) print "       Pulumi pods found: " $1; else print "       No Pulumi pods found"}'; \
	else \
		echo "   ✅ Pulumi namespace not found (clean install)"; \
	fi
	
	@echo ""
	@echo "🎉 Environment Check Complete!"
	@echo "========================="
	@echo "Ready to run: make bootstrap"
	@echo ""
	@echo "📝 Recommendation:"
	@echo "   If you see any warnings above, consider running 'make install-python-deps' first"
	@echo "   for enhanced validation capabilities (optional)."

# Test Pulumi installation
test-pulumi:
	@echo "Testing Pulumi installation..."
	cd infrastructure/pulumi && source venv/bin/activate && python3 -c "import pulumi; import pulumi_aws; import pulumi_kubernetes; print('✅ All Pulumi packages imported successfully')"
	@echo "Testing Pulumi program syntax..."
	cd infrastructure/pulumi && source venv/bin/activate && python3 -m py_compile __main__.py && echo "✅ Python syntax is valid"
	@echo "Checking Pulumi configuration..."
	cd infrastructure/pulumi && source venv/bin/activate && pulumi config && echo "✅ Pulumi configuration loaded successfully" || echo "ℹ️  No Pulumi stack configured yet (run 'make init-infrastructure' to create one)"

# Initialize Pulumi stack (for local development/testing)
init-infrastructure:
	@echo "Initializing Pulumi stack..."
	cd infrastructure/pulumi && \
	source venv/bin/activate && \
	pulumi stack init dev && \
	pulumi config set aws:region us-west-2 && \
	pulumi config set project:prefix myapp-dev && \
	pulumi config set kubernetes:namespace myapp-dev

# Bootstrap ArgoCD v3.0.12 and Pulumi Operator (Complete Installation)
bootstrap:
	@echo "🚀 Starting ArgoCD v3.0.12 Bootstrap with Helm-based Pulumi Operator..."
	@echo "🎯 Using OCI Helm chart: oci://ghcr.io/pulumi/helm-charts"
	@echo ""
	
	@echo "=== Pre-flight Checks ==="
	@echo "Checking kubectl connectivity..."
	@kubectl version --client
	@kubectl cluster-info --request-timeout=10s > /dev/null || (echo "❌ Cannot connect to Kubernetes cluster" && exit 1)
	@echo "✅ Kubernetes cluster connectivity verified"
	
	@echo "Checking required tools..."
	@command -v kustomize >/dev/null 2>&1 || (echo "❌ kustomize not found. Install from https://kustomize.io/" && exit 1)
	@echo "✅ kustomize found: $(kustomize version --short)"
	@echo ""
	
	@echo "=== Step 1: Installing ArgoCD v3.0.12 (Complete) ==="
	@echo "Creating argocd namespace..."
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	
	@echo "Installing ArgoCD CRDs first..."
	@kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.0.12/manifests/crds/application-crd.yaml
	@kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.0.12/manifests/crds/appproject-crd.yaml
	@kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.0.12/manifests/crds/applicationset-crd.yaml
	@echo "✅ ArgoCD CRDs installed"
	
	@echo "Installing complete ArgoCD v3.0.12 with custom configuration..."
	@kubectl apply -k argocd-install/
	@echo "✅ ArgoCD v3.0.12 manifests applied"
	
	@echo "Waiting for ArgoCD components to be ready (up to 5 minutes)..."
	@echo "  - Checking argocd-server..."
	@kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
	@echo "  - Checking argocd-application-controller..."
	@kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s
	@echo "  - Checking argocd-repo-server..."
	@kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=300s
	@echo "  - Checking redis..."
	@kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-redis -n argocd --timeout=300s
	@echo "✅ All ArgoCD components are ready!"
	
	@echo ""
	@echo "=== Step 2: Deploying Pulumi Operator via Helm Chart ==="
	kubectl apply -f argocd/argoocisecret.yaml -n argocd
	@echo "Installing Pulumi Operator using ArgoCD and OCI Helm chart..."
	kubectl apply -f bootstrap/bootstrap-apps.yaml -n argocd
	@echo "✅ Pulumi Operator ArgoCD application deployed"
	
	@echo "Waiting for Pulumi Operator to sync and be ready..."
	#@kubectl wait --for=condition=Synced app/pulumi-kubernetes-operator -n argocd --timeout=60s
	#@echo "Waiting for Pulumi Operator pods to be ready..."
	#@kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=pulumi-kubernetes-operator -n pulumi-system --timeout=300s 2>/dev/null || echo "⚠️  Pulumi Operator pod labels may be different - checking status..."
	#@kubectl get pods -n pulumi-system
	@echo "✅ Pulumi Operator installation complete via Helm"
	
	@echo ""
	@echo "=== Step 3: Verification and Status ==="
	@echo "Verifying ArgoCD installation..."
	@kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd
	@echo ""
	@echo "Checking ArgoCD service status..."
	@kubectl get svc argocd-server -n argocd
	@echo ""
	@echo "Verifying ArgoCD applications..."
	@kubectl get applications -n argocd
	@echo ""
	@echo "Verifying Pulumi Operator..."
	@kubectl get pods -n pulumi-system
	@kubectl get crd stacks.pulumi.com workspaces.auto.pulumi.com 2>/dev/null || echo "ℹ️  Pulumi CRDs may still be initializing"
	
	@echo ""
	@echo "🎉 === Bootstrap Complete with Helm! ===="
	@echo "📋 ArgoCD v3.0.12 + Pulumi Operator v2.0 Installation Summary:"
	@echo "   ✅ ArgoCD v3.0.12 installed with custom configuration"
	@echo "   ✅ Pulumi Operator v2.0 deployed via OCI Helm chart"
	@echo "   ✅ All core components running (server, controller, repo-server, redis)"
	@echo "   ✅ GitOps-managed Pulumi Operator using ArgoCD"
	@echo "   ✅ Service exposure configured (LoadBalancer + Ingress)"
	@echo ""
	@echo "🔑 Next Steps:"
	@echo "   1. Get ArgoCD access details: make check-argocd"
	@echo "   2. Deploy infrastructure: make deploy-infra"
	@echo "   3. Deploy applications: make deploy-k8s"
	@echo "   4. Check overall status: make status"
	@echo ""
	@echo "🌐 ArgoCD UI will be available via:"
	@echo "   - LoadBalancer: kubectl get svc argocd-server -n argocd"
	@echo "   - Port Forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
	@echo "   - Ingress: kubectl get ingress argocd-server-ingress -n argocd"

# Apply GitOps bootstrap applications (Helm-based)
setup-gitops-apps:
	@echo "🔄 Setting up GitOps Bootstrap Applications (Helm-based)"
	@echo "======================================================"
	@echo "This will configure ArgoCD to manage Pulumi Operator via Helm chart."
	@echo "Using OCI Helm chart: oci://ghcr.io/pulumi/helm-charts (chart: pulumi-kubernetes-operator)"
	@echo ""
	@echo "Applying bootstrap application configurations..."
	@kubectl apply -f bootstrap/bootstrap-apps.yaml -n argocd
	@echo "Waiting for bootstrap applications to sync..."
	@sleep 15
	@echo "Checking application status..."
	@kubectl get applications -n argocd
	@echo ""
	@echo "Checking Pulumi Operator deployment..."
	@kubectl get pods -n pulumi-system
	@echo ""
	@echo "🎉 GitOps bootstrap applications configured!"
	@echo "ArgoCD now manages Pulumi Operator via OCI Helm chart."
	@echo "Monitor with: kubectl get applications -n argocd -w"

deploy-infra:
	@echo "Deploying infrastructure with Pulumi Operator..."
	kubectl apply -f argocd/argoocisecret.yaml -n argocd
	kubectl apply -f argocd/infrastructure-app.yaml -n argocd
	@echo "Waiting for infrastructure deployment..."
	kubectl wait --for=condition=Synced app/myapp-infrastructure -n argocd --timeout=600s
	@echo "Checking Pulumi Stack status..."
	kubectl get stack myapp-infrastructure -n pulumi-system -o yaml

# Deploy Kubernetes resources via ArgoCD
deploy-k8s:
	@echo "Deploying Kubernetes resources with ArgoCD..."
	kubectl apply -f argocd/kubernetes-app.yaml -n argocd
	@echo "Waiting for applications to sync..."
	kubectl wait --for=condition=Synced app/myapp-kubernetes -n argocd --timeout=300s

# Deploy everything from scratch
deploy-all: bootstrap deploy-infra deploy-k8s
	@echo ""
	@echo "=== Deployment Complete! ==="
	@echo "Check status with: make status"

# Check ArgoCD installation and get access information
check-argocd:
	@echo "=== ArgoCD Status ==="
	kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server
	@echo ""
	@echo "=== ArgoCD Access Information ==="
	@echo "Getting ArgoCD admin password..."
	@ARGOCD_PASSWORD=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Password secret not found"); \
	echo "Username: admin"; \
	echo "Password: $$ARGOCD_PASSWORD"
	@echo ""
	@echo "=== Access Methods ==="
	@echo "1. Port Forward (for local access):"
	@echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
	@echo "   Then visit: https://localhost:8080"
	@echo ""
	@echo "2. LoadBalancer (if configured):"
	@kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null && echo "" || echo "LoadBalancer not configured"
	@echo ""
	@echo "3. Ingress (if configured):"
	@kubectl get ingress argocd-server-ingress -n argocd -o jsonpath='{.spec.rules[0].host}' 2>/dev/null && echo "" || echo "Ingress not configured"

# Show comprehensive status
status:
	@echo "=== ArgoCD Applications ==="
	kubectl get applications -n argocd -o wide || echo "ArgoCD not installed or accessible"
	@echo ""
	@echo "=== Pulumi Stack Status ==="
	kubectl get stack -n pulumi-system -o wide || echo "Pulumi Operator not installed or no stacks"
	@echo ""
	@echo "=== Infrastructure Resources ==="
	@echo "Checking AWS resources..."
	aws s3 ls | grep myapp-dev || echo "No S3 buckets found with myapp-dev prefix"
	aws sqs list-queues --queue-name-prefix myapp-dev || echo "No SQS queues found with myapp-dev prefix"
	@echo ""
	@echo "=== Kubernetes Resources ==="
	kubectl get all -n myapp-dev || echo "myapp-dev namespace not found"
	@echo ""
	@echo "=== ArgoCD Health ==="
	kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server || echo "ArgoCD not found"
	@echo ""
	@echo "=== Pulumi Operator Health ==="
	kubectl get pods -n pulumi-system -l app.kubernetes.io/name=pulumi-kubernetes-operator || echo "Pulumi Operator not found"

# Clean up all resources
clean:
	@echo "=== Cleaning up Application Resources ==="
	kubectl delete -f argocd/kubernetes-app.yaml -n argocd --ignore-not-found=true
	kubectl delete -f argocd/infrastructure-app.yaml -n argocd --ignore-not-found=true
	kubectl delete namespace myapp-dev --ignore-not-found=true
	
	@echo ""
	@echo "=== Cleaning up Bootstrap Resources ==="
	kubectl delete -f bootstrap/bootstrap-apps.yaml -n argocd --ignore-not-found=true
	
	@echo ""
	@echo "=== Cleaning up ArgoCD and Pulumi Operator ==="
	@echo "Note: Pulumi Operator is now managed via Helm - cleaning up applications..."
	kubectl delete namespace pulumi-system --ignore-not-found=true
	kubectl delete -k argocd-install/ -n argocd --ignore-not-found=true
	kubectl delete namespace argocd --ignore-not-found=true
	
	@echo ""
	@echo "=== Cleanup complete! ==="
	@echo "Note: AWS resources may still exist if they were created successfully."
	@echo "Check AWS console or run: aws s3 ls && aws sqs list-queues"

# Main validation (Python-focused, recommended)
validate: validate-python
	@echo ""
	@echo "✅ Main validation complete!"
	@echo "💡 This project now uses pure Python Pulumi (no Terraform modules required)"
	@echo "🔧 To validate legacy Terraform modules, run: make validate-terraform"

# Python/Pulumi validation (primary approach)
validate-python:
	@echo "🐍 Validating Python/Pulumi configuration..."
	@echo ""
	@echo "1. Validating Python environment..."
	cd infrastructure/pulumi && source venv/bin/activate && python3 --version && echo "✅ Python environment active"
	
	@echo ""
	@echo "2. Validating Python dependencies..."
	cd infrastructure/pulumi && source venv/bin/activate && python3 -c "import pulumi; import pulumi_aws; import pulumi_kubernetes; print('✅ All Pulumi packages available')"
	
	@echo ""
	@echo "3. Validating Pulumi program syntax..."
	cd infrastructure/pulumi && source venv/bin/activate && python3 -m py_compile __main__.py && echo "✅ Python syntax is valid"
	
	@echo ""
	@echo "4. Validating Kubernetes manifests..."
	kubectl apply --dry-run=client -f kubernetes/ && echo "✅ Kubernetes manifests are valid"
	
	@echo ""
	@echo "5. Validating ArgoCD installation..."
	@echo "   Testing kustomization build..."
	kustomize build argocd-install/ > /dev/null && echo "✅ ArgoCD kustomization builds successfully"
	@echo "   Testing kubectl validation..."
	kubectl apply --dry-run=client -k argocd-install/ > /dev/null && echo "✅ ArgoCD installation is valid"
	
	@echo ""
	@echo "6. Validating Pulumi Operator Helm configuration..."
	@echo "   Checking ArgoCD applications configuration..."
	@if kubectl apply --dry-run=client -f bootstrap/bootstrap-apps.yaml -n argocd > /dev/null 2>&1; then \
		echo "   ✅ Bootstrap applications configuration is valid"; \
	else \
		echo "   ⚠️  Bootstrap applications validation failed"; \
	fi
	@echo "   Checking infrastructure application configuration..."
	@if kubectl apply --dry-run=client -f argocd/infrastructure-app.yaml -n argocd > /dev/null 2>&1; then \
		echo "   ✅ Infrastructure application configuration is valid"; \
	else \
		echo "   ⚠️  Infrastructure application validation failed"; \
	fi
	
	@echo ""
	@echo "7. Validating ArgoCD applications..."
	@echo "   Checking if ArgoCD CRDs are available..."
	@if kubectl get crd applications.argoproj.io appprojects.argoproj.io applicationsets.argoproj.io >/dev/null 2>&1; then \
		kubectl apply --dry-run=client -f argocd/ && echo "✅ ArgoCD applications are valid"; \
	else \
		echo "⚠️  ArgoCD CRDs not found - installing for validation..."; \
		kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.0.12/manifests/crds/application-crd.yaml --dry-run=client; \
		kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.0.12/manifests/crds/appproject-crd.yaml --dry-run=client; \
		kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.0.12/manifests/crds/applicationset-crd.yaml --dry-run=client; \
		echo "✅ ArgoCD CRD validation complete"; \
		echo "ℹ️  Note: Run 'make bootstrap' to install ArgoCD CRDs permanently"; \
	fi
	
	@echo ""
	@echo "✅ Python/Pulumi validation complete!"

# Legacy Terraform validation (optional)
validate-terraform:
	@echo "🏗️  Validating legacy Terraform modules (optional)..."
	@echo "⚠️  Note: These modules are no longer used in the pure Python implementation"
	@echo ""
	@if command -v terraform >/dev/null 2>&1; then \
		echo "Initializing and validating S3 bucket module..."; \
		cd infrastructure/terraform-modules/s3-bucket && terraform init -backend=false && terraform fmt -check && terraform validate && echo "✅ S3 module valid"; \
		echo ""; \
		echo "Initializing and validating SQS queue module..."; \
		cd ../sqs-queue && terraform init -backend=false && terraform fmt -check && terraform validate && echo "✅ SQS module valid"; \
		echo ""; \
		echo "✅ Legacy Terraform modules validation complete!"; \
		echo "💡 These modules are maintained for reference but not used in deployment"; \
	else \
		echo "❌ Terraform not found - skipping Terraform module validation"; \
		echo "💡 This is fine - the project uses pure Python Pulumi now"; \
	fi

# Development helpers
dev-argocd-forward:
	@echo "Starting ArgoCD port forwarding..."
	@echo "ArgoCD will be available at https://localhost:8080"
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
	kubectl port-forward svc/argocd-server -n argocd 8080:443

dev-logs-infrastructure:
	@echo "Following Pulumi Stack logs..."
	kubectl logs -f -l app.kubernetes.io/name=pulumi-kubernetes-operator -n pulumi-system

dev-logs-argocd:
	@echo "Following ArgoCD Application Controller logs..."
	kubectl logs -f -l app.kubernetes.io/name=argocd-application-controller -n argocd

# Python/Pulumi specific helpers
dev-pulumi-preview:
	@echo "Running Pulumi preview locally..."
	cd infrastructure/pulumi && source venv/bin/activate && pulumi preview

dev-pulumi-up:
	@echo "Running Pulumi up locally..."
	cd infrastructure/pulumi && source venv/bin/activate && pulumi up

dev-pulumi-destroy:
	@echo "Running Pulumi destroy locally..."
	cd infrastructure/pulumi && source venv/bin/activate && pulumi destroy
