#!/bin/bash

# GitOps Ultra - Health Check Script
# Quick health check for the GitOps deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}🏥 GitOps Ultra - Health Check${NC}"
    echo "=============================="
    echo ""
}

check_cluster_connection() {
    echo -n "🔗 Cluster Connection: "
    if kubectl cluster-info --request-timeout=5s > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Connected${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed${NC}"
        return 1
    fi
}

check_argocd_health() {
    echo -n "🎯 ArgoCD Health: "
    local ready_pods=$(kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    local total_pods=$(kubectl get pods -n argocd -l app.kubernetes.io/part-of=argocd --no-headers 2>/dev/null | wc -l)
    
    if [[ $ready_pods -gt 0 && $ready_pods -eq $total_pods ]]; then
        echo -e "${GREEN}✅ All $total_pods pods running${NC}"
        return 0
    elif [[ $ready_pods -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  $ready_pods/$total_pods pods running${NC}"
        return 1
    else
        echo -e "${RED}❌ No pods running${NC}"
        return 1
    fi
}

check_pulumi_operator() {
    echo -n "⚙️  Pulumi Operator: "
    local namespace=""
    if kubectl get namespace pulumi-kubernetes-operator > /dev/null 2>&1; then
        namespace="pulumi-kubernetes-operator"
    elif kubectl get namespace pulumi-system > /dev/null 2>&1; then
        namespace="pulumi-system"
    else
        echo -e "${RED}❌ Namespace not found${NC}"
        return 1
    fi
    
    local ready_pods=$(kubectl get pods -n $namespace --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    local total_pods=$(kubectl get pods -n $namespace --no-headers 2>/dev/null | wc -l)
    
    if [[ $ready_pods -gt 0 && $ready_pods -eq $total_pods ]]; then
        echo -e "${GREEN}✅ All $total_pods pods running${NC}"
        return 0
    elif [[ $ready_pods -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  $ready_pods/$total_pods pods running${NC}"
        return 1
    else
        echo -e "${RED}❌ No pods running${NC}"
        return 1
    fi
}

check_applications() {
    echo -n "📱 ArgoCD Apps: "
    local synced=$(kubectl get applications -n argocd -o jsonpath='{.items[?(@.status.sync.status=="Synced")].metadata.name}' 2>/dev/null | wc -w)
    local healthy=$(kubectl get applications -n argocd -o jsonpath='{.items[?(@.status.health.status=="Healthy")].metadata.name}' 2>/dev/null | wc -w)
    local total=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
    
    if [[ $total -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No applications found${NC}"
        return 1
    elif [[ $synced -eq $total && $healthy -eq $total ]]; then
        echo -e "${GREEN}✅ All $total apps synced & healthy${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  $synced/$total synced, $healthy/$total healthy${NC}"
        return 1
    fi
}

check_stacks() {
    echo -n "🏗️  Pulumi Stacks: "
    local stacks=$(kubectl get stacks -A --no-headers 2>/dev/null | wc -l)
    
    if [[ $stacks -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No stacks found${NC}"
        return 1
    else
        echo -e "${GREEN}✅ $stacks stack(s) found${NC}"
        return 0
    fi
}

show_quick_status() {
    echo ""
    echo -e "${BLUE}📊 Quick Status Overview${NC}"
    echo "------------------------"
    
    # ArgoCD Applications (if any)
    if kubectl get applications -n argocd > /dev/null 2>&1; then
        echo -e "${BLUE}ArgoCD Applications:${NC}"
        kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status" 2>/dev/null || echo "  Unable to fetch application status"
        echo ""
    fi
    
    # Pulumi Stacks (if any)
    if kubectl get stacks -A > /dev/null 2>&1; then
        echo -e "${BLUE}Pulumi Stacks:${NC}"
        kubectl get stacks -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATE:.status.lastUpdate.state" 2>/dev/null || echo "  Unable to fetch stack status"
        echo ""
    fi
}

main() {
    print_header
    
    local checks=0
    local passed=0
    
    # Run health checks
    check_cluster_connection && ((passed++)); ((checks++))
    check_argocd_health && ((passed++)); ((checks++))
    check_pulumi_operator && ((passed++)); ((checks++))
    check_applications && ((passed++)); ((checks++))
    check_stacks && ((passed++)); ((checks++))
    
    echo ""
    echo "=============================="
    
    if [[ $passed -eq $checks ]]; then
        echo -e "${GREEN}🎉 System Health: GOOD ($passed/$checks checks passed)${NC}"
        show_quick_status
    elif [[ $passed -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  System Health: PARTIAL ($passed/$checks checks passed)${NC}"
        echo ""
        echo "Some components may still be starting up or need attention."
        echo "Run 'make verify-deployment' for detailed diagnostics."
        show_quick_status
    else
        echo -e "${RED}❌ System Health: CRITICAL (0/$checks checks passed)${NC}"
        echo ""
        echo "Multiple components are not responding."
        echo "Recommended actions:"
        echo "  1. Run 'make bootstrap' to install core components"
        echo "  2. Run 'make status' for detailed information"
        echo "  3. Run 'make verify-deployment' for comprehensive checks"
    fi
    
    echo ""
    echo -e "${BLUE}💡 Useful Commands:${NC}"
    echo "  make status              # Detailed status information"
    echo "  make check-argocd        # ArgoCD access information"
    echo "  make verify-deployment   # Comprehensive verification"
    echo "  make dev-argocd-forward  # Access ArgoCD UI locally"
}

main "$@"
