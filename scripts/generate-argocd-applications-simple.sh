#!/bin/bash

# SPANDA AI PLATFORM - SIMPLE APPLICATION GENERATOR
# 
# This script generates simple ArgoCD applications that consume existing
# platform services instead of provisioning platform modules per application.
#
# Author: Spanda AI DevOps Team
# Version: 2.0 (Simplified for Platform Services)

set -euo pipefail

# Configuration
APP_REPO_BASE="https://github.com/aryan-spanda"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM_DISCOVERY_SCRIPT="../../spandaai-platform-deployment/bare-metal/discover-platform-services.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to validate platform requirements
validate_platform_requirements() {
    local app_name=$1
    local app_dir="../local-app-repos/$app_name"
    local requirements_file="$app_dir/platform-requirements.yml"
    
    if [[ ! -f "$requirements_file" ]]; then
        warn "No platform requirements file found for $app_name"
        return 0
    fi
    
    log "Validating platform requirements for $app_name"
    
    # Use platform discovery script to validate requirements
    if [[ -f "$PLATFORM_DISCOVERY_SCRIPT" ]]; then
        if bash "$PLATFORM_DISCOVERY_SCRIPT" "$requirements_file"; then
            success "All required platform services are available for $app_name"
            return 0
        else
            error "Some required platform services are not available for $app_name"
            error "Please ensure platform modules are deployed first"
            return 1
        fi
    else
        warn "Platform discovery script not found, skipping validation"
        return 0
    fi
}

# Platform service integration is handled via Helm values and service discovery
# ConfigMaps are created by the application's Helm chart, not by ArgoCD application definitions

# Function to parse YAML using yq
parse_yaml() {
    local file=$1
    local query=$2
    yq eval "$query" "$file" 2>/dev/null || echo ""
}

# Function to generate simple ArgoCD application (no platform modules)
generate_simple_app() {
    local app_name=$1
    local environment=$2
    local app_config_file=$3
    
    # Parse application configuration
    local repo_url=$(parse_yaml "$app_config_file" '.app.repoURL')
    local chart_path=$(parse_yaml "$app_config_file" '.app.chartPath')
    local team=$(parse_yaml "$app_config_file" '.app.team')
    local app_type=$(parse_yaml "$app_config_file" '.app.type')
    local container_registry=$(parse_yaml "$app_config_file" '.container.registry')
    local container_org=$(parse_yaml "$app_config_file" '.container.organization')
    local container_image=$(parse_yaml "$app_config_file" '.container.image')
    
    # Determine target revision and image tag based on environment
    local target_revision="main"
    local image_tag_pattern="^main-[0-9a-f]{7,8}$"
    local image_tag_placeholder="main-placeholder"
    
    case "$environment" in
        "dev")
            target_revision="testing"
            image_tag_pattern="^testing-[0-9a-f]{7,8}$"
            image_tag_placeholder="testing-placeholder"
            ;;
        "staging")
            target_revision="staging"
            image_tag_pattern="^staging-[0-9a-f]{7,8}$"
            image_tag_placeholder="staging-placeholder"
            ;;
        "production")
            target_revision="main"
            image_tag_pattern="^v[0-9]+\\.[0-9]+\\.[0-9]+$"
            image_tag_placeholder="v1.0.0"
            ;;
    esac
    
    # Generate simple ArgoCD application (platform services are separate)
    cat << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $(echo "$app_name-$environment" | tr '[:upper:]' '[:lower:]')
  namespace: argocd
  labels:
    app.kubernetes.io/name: $(echo "$app_name" | tr '[:upper:]' '[:lower:]')
    app.kubernetes.io/part-of: spandaai-applications
    team: $team
    environment: $environment
    app-type: $app_type
  annotations:
    app.spanda.ai/generated: "true"
    app.spanda.ai/generator: "simple-application-deployment"
    app.spanda.ai/generated-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    app.spanda.ai/uses-platform-services: "true"
    # ArgoCD Image Updater configuration
    argocd-image-updater.argoproj.io/image-list: $(echo "$app_name" | tr '[:upper:]' '[:lower:]')=$container_org/$container_image
    argocd-image-updater.argoproj.io/write-back-method: git:secret:argocd/argocd-image-updater-git
    argocd-image-updater.argoproj.io/git-branch: $target_revision
    argocd-image-updater.argoproj.io/$(echo "$app_name" | tr '[:upper:]' '[:lower:]').update-strategy: latest
    argocd-image-updater.argoproj.io/$(echo "$app_name" | tr '[:upper:]' '[:lower:]').allow-tags: regexp:$image_tag_pattern
    argocd-image-updater.argoproj.io/$(echo "$app_name" | tr '[:upper:]' '[:lower:]').helm.image-name: image.repository
    argocd-image-updater.argoproj.io/$(echo "$app_name" | tr '[:upper:]' '[:lower:]').helm.image-tag: image.tag
    argocd-image-updater.argoproj.io/$(echo "$app_name" | tr '[:upper:]' '[:lower:]').ignore-tags: latest,main
    argocd-image-updater.argoproj.io/$(echo "$app_name" | tr '[:upper:]' '[:lower:]').force-update: "false"
spec:
  project: spanda-applications
  source:
    repoURL: $repo_url
    targetRevision: $target_revision
    path: $chart_path
    helm:
      releaseName: $(echo "$app_name-$environment" | tr '[:upper:]' '[:lower:]')
      valueFiles:
        - values-$environment.yaml
      parameters:
        - name: image.repository
          value: $container_org/$container_image
        - name: image.tag
          value: $image_tag_placeholder
        - name: platform.servicesEnabled
          value: "true"
  destination:
    server: https://kubernetes.default.svc
    namespace: $(echo "$app_name-$environment" | tr '[:upper:]' '[:lower:]')
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 2m
  info:
    - name: 'Generated By'
      value: 'Simple Application Generator'
    - name: 'Platform Services'
      value: 'Uses shared platform services'
    - name: 'Environment'
      value: '$environment'
    - name: 'Team'
      value: '$team'
EOF
}

# Function to create and apply ArgoCD Image Updater configuration
create_argocd_image_updater_config() {
    log "Creating ArgoCD Image Updater configuration..."
    
    local config_file="$BASE_DIR/argocd-image-updater-config.yaml"
    
    cat << 'EOF' > "$config_file"
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-image-updater-config
  namespace: argocd
data:
  registries.conf: |
    registries:
    - name: Docker Hub
      api_url: https://registry-1.docker.io
      prefix: docker.io
      ping: yes
      default: yes
      
  argocd.conf: |
    argocd.server_addr: argocd-server.argocd.svc.cluster.local:443
    argocd.insecure: false
    argocd.grpc_web: true
    
  log.level: "info"
  interval: "300s"
  kube.events: "true"
  kube.events.namespace: "argocd"
EOF
    
    success "Created ArgoCD Image Updater config: $config_file"
}

# Function to apply all generated applications
apply_applications() {
    local auto_apply=${1:-false}
    
    if [[ "$auto_apply" != "true" ]]; then
        echo ""
        read -p "Do you want to apply the generated applications to Kubernetes? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Skipping application deployment"
            return 0
        fi
    fi
    
    log "Applying ArgoCD Image Updater configuration..."
    if kubectl apply -f "$BASE_DIR/argocd-image-updater-config.yaml"; then
        success "ArgoCD Image Updater configuration applied"
    else
        error "Failed to apply ArgoCD Image Updater configuration"
        return 1
    fi
    
    log "Applying ArgoCD applications..."
    local applied_count=0
    local failed_count=0
    
    # Apply all application YAML files
    for app_file in "$BASE_DIR/applications"/*/*/*.yaml; do
        if [[ -f "$app_file" ]]; then
            log "Applying: $(basename "$app_file")"
            if kubectl apply -f "$app_file"; then
                success "Applied: $(basename "$app_file")"
                applied_count=$((applied_count + 1))
            else
                error "Failed to apply: $(basename "$app_file")"
                failed_count=$((failed_count + 1))
            fi
        fi
    done
    
    echo ""
    if [[ $failed_count -eq 0 ]]; then
        success "All applications applied successfully! ($applied_count applications)"
    else
        warn "Applied $applied_count applications, failed $failed_count"
    fi
    
    # Restart ArgoCD Image Updater to pick up new config
    log "Restarting ArgoCD Image Updater to apply new configuration..."
    if kubectl rollout restart deployment/argocd-image-updater -n argocd; then
        success "ArgoCD Image Updater restarted"
    else
        warn "Failed to restart ArgoCD Image Updater (may not be deployed yet)"
    fi
}

# Function to show usage
show_usage() {
    echo "Simple Application Generator v2.0"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script generates simple ArgoCD applications that consume"
    echo "existing platform services instead of provisioning modules."
    echo ""
    echo "OPTIONS:"
    echo "  --apply, -a     Automatically apply generated applications to Kubernetes"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - Platform services must be deployed first"
    echo "  - Use: ./deploy-platform-services.sh deploy"
    echo ""
    echo "Examples:"
    echo "  $0              # Generate applications (prompt to apply)"
    echo "  $0 --apply      # Generate and auto-apply applications"
    echo ""
    echo "Generated applications will:"
    echo "  ✅ Use shared platform services"
    echo "  ✅ Deploy faster (no infrastructure provisioning)"
    echo "  ✅ Have simpler configuration"
    echo "  ✅ Support conservative image auto-updates (5min polling)"
    echo "  ✅ Include ArgoCD Image Updater configuration"
}

# Main function - simplified without platform modules
main() {
    if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        show_usage
        return 0
    fi
    
    log "🚀 Simple Application Generator v2.0 (Platform Services Separate)"
    echo "=================================================================="
    
    # Check dependencies
    if ! command -v yq &> /dev/null; then
        error "yq is required but not installed. Please install yq."
        exit 1
    fi
    
    # Validate platform services are available
    log "Checking platform services availability..."
    if [[ -f "$PLATFORM_DISCOVERY_SCRIPT" ]]; then
        if ! bash "$PLATFORM_DISCOVERY_SCRIPT"; then
            error "Platform services are not fully deployed"
            error "Please run platform deployment first:"
            error "  cd ../../spandaai-platform-deployment/bare-metal"
            error "  ./deploy-complete-platform.sh"
            exit 1
        fi
    else
        warn "Platform discovery script not found, skipping platform validation"
    fi
    
    # Process applications
    local apps_dir="$BASE_DIR/local-app-repos"
    if [[ ! -d "$apps_dir" ]]; then
        error "Local app repositories directory not found: $apps_dir"
        error "Expected: $apps_dir"
        exit 1
    fi
    
    local app_count=0
    local env_count=0
    
    for app_dir in "$apps_dir"/*; do
        if [[ -d "$app_dir" ]]; then
            local app_name=$(basename "$app_dir")
            log "Processing application: $app_name"
            app_count=$((app_count + 1))
            
            # Validate platform requirements for this app
            if ! validate_platform_requirements "$app_name"; then
                error "Skipping $app_name due to unmet platform requirements"
                continue
            fi
            
            local requirements_file="$app_dir/platform-requirements.yml"
            
            if [[ -f "$requirements_file" ]]; then
                # Get environments from requirements
                local environments=($(parse_yaml "$requirements_file" '.environments[]'))
                
                if [[ ${#environments[@]} -eq 0 ]]; then
                    warn "No environments found for $app_name, skipping"
                    continue
                fi
                
                # Generate simple ArgoCD applications for each environment
                for env in "${environments[@]}"; do
                    if [[ -n "$env" && "$env" != "null" ]]; then
                        log "Generating simple ArgoCD application for $app_name-$env"
                        
                        local output_file="$BASE_DIR/applications/$app_name/argocd/app-$env.yaml"
                        mkdir -p "$(dirname "$output_file")"
                        
                        # Generate app manifest (ConfigMaps handled by Helm chart)
                        generate_simple_app "$app_name" "$env" "$requirements_file" > "$output_file"
                        
                        success "Generated: $output_file"
                        env_count=$((env_count + 1))
                    fi
                done
            else
                warn "No platform-requirements.yml found for $app_name, skipping"
            fi
        fi
    done
    
    echo ""
    success "Simple application generation completed!"
    log "Generated $env_count applications across $app_count repositories"
    
    # Create ArgoCD Image Updater configuration
    create_argocd_image_updater_config
    
    echo ""
    warn "📋 IMPORTANT: Platform services must be deployed first!"
    echo "   Run: ./deploy-platform-services.sh deploy"
    echo ""
    
    # Check for auto-apply flag
    local auto_apply=false
    if [[ "${1:-}" == "--apply" || "${1:-}" == "-a" ]]; then
        auto_apply=true
    fi
    
    # Apply applications
    apply_applications "$auto_apply"
    
    echo ""
    log "🎯 Applications will consume existing platform services"
    log "   - Faster deployment (no infrastructure provisioning)"
    log "   - Shared platform resources"
    log "   - Independent lifecycle management"
    log "   - Conservative image update polling (5 minutes)"
}

# Run main function
main "$@"
