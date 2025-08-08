#!/bin/bash

# SPANDA AI PLATFORM - MAIN ORCHESTRATION SCRIPT
# 
# This script coordinates the two-layer platform deployment:
# 1. Platform services (from spanda terraform repo) 
# 2. Applications (from config repo)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
PLATFORM_REPO_PATH="../../spandaai-platform-deployment"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_usage() {
    echo "Spanda AI Platform - Main Orchestration Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  platform     Deploy platform services (Layer 1)"
    echo "  discover     Discover available platform services"
    echo "  applications Generate and deploy applications (Layer 2)" 
    echo "  complete     Deploy complete platform (both layers)"
    echo "  clean        Clean up all deployments"
    echo "  help         Show this help message"
    echo ""
    echo "Two-Layer Architecture:"
    echo "  Layer 1: Platform services (stable, shared infrastructure)"
    echo "  Layer 2: Applications (business apps consuming platform services)"
}

deploy_platform() {
    log "🏗️  Deploying Platform Services (Layer 1)..."
    echo "=============================================="
    
    if [[ ! -f "$PLATFORM_REPO_PATH/bare-metal/deploy-complete-platform.sh" ]]; then
        error "Platform deployment script not found"
        error "Expected: $PLATFORM_REPO_PATH/bare-metal/deploy-complete-platform.sh"
        return 1
    fi
    
    log "Executing platform deployment from spanda terraform repo..."
    cd "$PLATFORM_REPO_PATH/bare-metal"
    bash ./deploy-complete-platform.sh
    
    cd "$SCRIPT_DIR"
    success "Platform services deployed successfully"
}

discover_services() {
    log "🔍 Discovering Platform Services..."
    echo "==================================="
    
    if [[ ! -f "$PLATFORM_REPO_PATH/bare-metal/scripts/discover-platform-services.sh" ]]; then
        error "Service discovery script not found"
        return 1
    fi
    
    bash "$PLATFORM_REPO_PATH/bare-metal/scripts/discover-platform-services.sh" "$@"
}

deploy_applications() {
    log "🚀 Deploying Applications (Layer 2)..."
    echo "======================================="
    
    # First discover services to validate platform readiness
    if ! discover_services; then
        error "Platform services are not ready"
        error "Please deploy platform first: $0 platform"
        return 1
    fi
    
    log "Generating ArgoCD applications..."
    bash ./generate-argocd-applications-simple.sh
    
    log "Applying ArgoCD applications..."
    if kubectl apply -f "$BASE_DIR/applications/" -R; then
        success "Applications deployed successfully"
    else
        error "Failed to deploy applications"
        return 1
    fi
}

deploy_complete() {
    log "🎯 Complete Platform Deployment (Both Layers)..."
    echo "================================================="
    
    deploy_platform
    echo ""
    
    log "Waiting 30 seconds for platform services to stabilize..."
    sleep 30
    
    deploy_applications
    
    echo ""
    success "🎉 Complete platform deployment finished!"
    echo ""
    log "Platform Status:"
    discover_services
}

clean_deployments() {
    warn "🗑️  Cleaning Up All Deployments..."
    echo "=================================="
    
    warn "This will remove all applications and platform services"
    read -p "Are you sure? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "Cleanup cancelled"
        return 0
    fi
    
    # Clean applications first
    log "Removing applications..."
    kubectl delete -f "$BASE_DIR/applications/" -R --ignore-not-found=true
    
    # Clean platform namespaces
    log "Removing platform namespaces..."
    kubectl delete namespace platform-networking platform-security --ignore-not-found=true
    
    success "Cleanup completed"
}

main() {
    case "${1:-help}" in
        "platform")
            deploy_platform
            ;;
        "discover") 
            shift
            discover_services "$@"
            ;;
        "applications")
            deploy_applications
            ;;
        "complete")
            deploy_complete
            ;;
        "clean")
            clean_deployments
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            error "Unknown command: ${1:-}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
