#!/bin/bash

# GitOps Ultra - Troubleshooting Guide
# Interactive troubleshooting script for common issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}🔧 GitOps Ultra - Troubleshooting Guide${NC}"
    echo "========================================"
    echo ""
}

show_menu() {
    echo -e "${CYAN}Select an issue to troubleshoot:${NC}"
    echo ""
    echo "1. ArgoCD pods not starting"
    echo "2. Pulumi Operator issues"
    echo "3. Applications stuck syncing"
    echo "4. Pulumi Stack failures"
    echo "5. AWS resource creation issues"
    echo "6. kubectl connectivity problems"
    echo "7. Permission/RBAC issues"
    echo "8. Resource quota/limits issues"
    echo "9. Check all common issues"
    echo "0. Exit"
    echo ""
    read -p "Enter your choice (0-9): " choice
}

troubleshoot_argocd() {
    echo -e "${BLUE}🎯 Troubleshooting ArgoCD Issues${NC}"
    echo "==============================="
    echo ""
    
    if ! kubectl get namespace argocd > /dev/null 2>&1; then
        echo -e "${RED}❌ ArgoCD namespace not found${NC}"
        echo "Solution: Run 'make bootstrap' to install ArgoCD"
        return 1
    fi
    
    echo "ArgoCD pod status:"
    kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd
    
    local failing_pods=$(kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    if [[ $failing_pods -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  Found $failing_pods failing pod(s)${NC}"
        echo "Recent events:"
        kubectl get events -n argocd --sort-by=.metadata.creationTimestamp | tail -5
        echo ""
        echo -e "${CYAN}💡 Common solutions:${NC}"
        echo "  - Wait 2-5 minutes for pods to fully start"
        echo "  - Check logs: kubectl logs -l app.kubernetes.io/name=argocd-server -n argocd"
        echo "  - Restart: kubectl rollout restart deployment/argocd-server -n argocd"
    else
        echo -e "${GREEN}✅ All ArgoCD pods are running${NC}"
    fi
}

troubleshoot_pulumi() {
    echo -e "${BLUE}⚙️  Troubleshooting Pulumi Operator Issues${NC}"
    echo "========================================="
    echo ""
    
    local operator_ns=""
    if kubectl get namespace pulumi-kubernetes-operator > /dev/null 2>&1; then
        operator_ns="pulumi-kubernetes-operator"
    elif kubectl get namespace pulumi-system > /dev/null 2>&1; then
        operator_ns="pulumi-system"
    else
        echo -e "${RED}❌ Pulumi Operator namespace not found${NC}"
        echo "Solution: Run 'make bootstrap' to install the operator"
        return 1
    fi
    
    echo "Using namespace: $operator_ns"
    kubectl get pods -n "$operator_ns"
    
    if ! kubectl get crd stacks.pulumi.com > /dev/null 2>&1; then
        echo -e "${RED}❌ Pulumi Stack CRD missing${NC}"
    fi
    
    echo ""
    echo "Recent operator logs:"
    kubectl logs -l app.kubernetes.io/name=pulumi-kubernetes-operator -n "$operator_ns" --tail=10 2>/dev/null || echo "Could not fetch logs"
}

check_all_issues() {
    echo -e "${BLUE}🔍 Running Comprehensive Issue Check${NC}"
    echo "===================================="
    echo ""
    
    local issues_found=0
    
    echo "1. kubectl connectivity..."
    if ! kubectl cluster-info --request-timeout=5s > /dev/null 2>&1; then
        echo -e "  ${RED}❌ kubectl connectivity issue${NC}"
        ((issues_found++))
    else
        echo -e "  ${GREEN}✅ kubectl working${NC}"
    fi
    
    echo "2. ArgoCD..."
    if ! kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd --field-selector=status.phase=Running > /dev/null 2>&1; then
        echo -e "  ${RED}❌ ArgoCD issue detected${NC}"
        ((issues_found++))
    else
        echo -e "  ${GREEN}✅ ArgoCD working${NC}"
    fi
    
    echo "3. Pulumi Operator..."
    local operator_working=false
    for ns in "pulumi-kubernetes-operator" "pulumi-system"; do
        if kubectl get pods -n "$ns" --field-selector=status.phase=Running > /dev/null 2>&1; then
            operator_working=true
            break
        fi
    done
    if [[ $operator_working == false ]]; then
        echo -e "  ${RED}❌ Pulumi Operator issue${NC}"
        ((issues_found++))
    else
        echo -e "  ${GREEN}✅ Pulumi Operator working${NC}"
    fi
    
    echo ""
    if [[ $issues_found -eq 0 ]]; then
        echo -e "${GREEN}🎉 No major issues detected!${NC}"
    else
        echo -e "${YELLOW}⚠️  $issues_found issue(s) detected${NC}"
        echo "Run specific troubleshooting options for details."
    fi
}

main() {
    print_header
    
    if [[ $# -gt 0 ]]; then
        case "$1" in
            "argocd") troubleshoot_argocd ;;
            "pulumi") troubleshoot_pulumi ;;
            "all") check_all_issues ;;
            *) echo "Usage: $0 [argocd|pulumi|all]"; exit 1 ;;
        esac
        return
    fi
    
    while true; do
        show_menu
        case $choice in
            1) troubleshoot_argocd ;;
            2) troubleshoot_pulumi ;;
            9) check_all_issues ;;
            0) echo "Exiting..."; break ;;
            *) echo -e "${RED}Invalid choice${NC}" ;;
        esac
        echo ""; echo "Press Enter to continue..."; read; clear; print_header
    done
}

main "$@"
