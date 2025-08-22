.PHONY: help install-deps init-infrastructure bootstrap deploy-infra deploy-k8s deploy-all clean status check-argocd

# Default target
help:
	@echo "Available commands:"
	@echo "  install-deps        - Install all dependencies"
	@echo "  init-infrastructure - Initialize Pulumi stack"
	@echo "  bootstrap          - Install ArgoCD and Pulumi Operator"
	@echo "  deploy-infra       - Deploy infrastructure with Pulumi Operator"
	@echo "  deploy-k8s         - Deploy Kubernetes resources with ArgoCD"
	@echo "  deploy-all         - Bootstrap and deploy everything"
	@echo "  status             - Show deployment status"
	@echo "  check-argocd       - Check ArgoCD installation and access"
	@echo "  clean              - Clean up all resources"

# Install dependencies
install-deps:
	@echo "Installing Pulumi Python dependencies..."
	cd infrastructure/pulumi && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
	@echo "Checking Terraform installation..."
	terraform version
	@echo "Checking kubectl configuration..."
	kubectl version --client
	@echo "Checking Kustomize installation..."
	kustomize version || echo "Install kustomize from https://kustomize.io/"

# Initialize Pulumi stack (for local development/testing)
init-infrastructure:
	@echo "Initializing Pulumi stack..."
	cd infrastructure/pulumi && \
	source venv/bin/activate && \
	pulumi stack init dev && \
	pulumi config set aws:region us-west-2 && \
	pulumi config set project:prefix myapp-dev && \
	pulumi config set kubernetes:namespace myapp-dev

# Bootstrap ArgoCD and Pulumi Operator
bootstrap:
	@echo "=== Step 1: Installing ArgoCD ==="
	kubectl create namespace argocd || true
	kubectl apply -k argocd-install/ -n argocd
	@echo "Waiting for ArgoCD to be ready..."
	kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
	
	@echo ""
	@echo "=== Step 2: Installing Pulumi Operator ==="
	kubectl create namespace pulumi-system || true
	kubectl apply -k pulumi-operator/ -n pulumi-system
	@echo "Waiting for Pulumi Operator to be ready..."
	kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=pulumi-operator -n pulumi-system --timeout=300s
	
	@echo ""
	@echo "=== Step 3: Setting up Bootstrap Applications ==="
	kubectl apply -f bootstrap/bootstrap-apps.yaml -n argocd
	@echo "Waiting for bootstrap applications to sync..."
	sleep 30
	kubectl wait --for=condition=Synced app/argocd-installation -n argocd --timeout=300s || true
	kubectl wait --for=condition=Synced app/pulumi-operator -n argocd --timeout=300s || true
	
	@echo ""
	@echo "=== Bootstrap Complete! ==="
	@echo "ArgoCD UI will be available via LoadBalancer or Ingress"
	@echo "Run 'make check-argocd' to get access details"

# Deploy infrastructure via Pulumi Operator and ArgoCD
deploy-infra:
	@echo "Deploying infrastructure with Pulumi Operator..."
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
	kubectl get pods -n pulumi-system -l app.kubernetes.io/name=pulumi-operator || echo "Pulumi Operator not found"

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
	kubectl delete -k pulumi-operator/ -n pulumi-system --ignore-not-found=true
	kubectl delete namespace pulumi-system --ignore-not-found=true
	kubectl delete -k argocd-install/ -n argocd --ignore-not-found=true
	kubectl delete namespace argocd --ignore-not-found=true
	
	@echo ""
	@echo "=== Cleanup complete! ==="
	@echo "Note: AWS resources may still exist if they were created successfully."
	@echo "Check AWS console or run: aws s3 ls && aws sqs list-queues"

# Validate configuration files
validate:
	@echo "Validating Terraform modules..."
	cd infrastructure/terraform-modules/s3-bucket && terraform fmt -check && terraform validate
	cd infrastructure/terraform-modules/sqs-queue && terraform fmt -check && terraform validate
	@echo "Validating Kubernetes manifests..."
	kubectl apply --dry-run=client -f kubernetes/
	kubectl apply --dry-run=client -f argocd/
	@echo "Validating ArgoCD installation..."
	kubectl apply --dry-run=client -k argocd-install/
	@echo "Validating Pulumi Operator installation..."
	kubectl apply --dry-run=client -k pulumi-operator/
	@echo "Validating Pulumi Python syntax..."
	cd infrastructure/pulumi && source venv/bin/activate && python -m py_compile __main__.py
	@echo "Validation complete!"

# Development helpers
dev-argocd-forward:
	@echo "Starting ArgoCD port forwarding..."
	@echo "ArgoCD will be available at https://localhost:8080"
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
	kubectl port-forward svc/argocd-server -n argocd 8080:443

dev-logs-infrastructure:
	@echo "Following Pulumi Stack logs..."
	kubectl logs -f -l app.kubernetes.io/name=pulumi-operator -n pulumi-system

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
