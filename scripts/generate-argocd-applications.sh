#!/bin/bash

set -euo pipefail

# Configuration
CONFIG_REPO_URL="https://github.com/aryan-spanda/spanda-config.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
TEMP_DIR="/tmp/platform-generation-$$"
MODULE_MAPPINGS_FILE="$BASE_DIR/cluster-config/config/module-mappings.yml"

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

# Function to parse YAML using yq
parse_yaml() {
    local file=$1
    local query=$2
    yq eval "$query" "$file" 2>/dev/null || echo ""
}

# Function to get required platform modules from platform-requirements.yml
get_required_modules() {
    local requirements_file=$1
    local modules=()
    
    # Read all platform modules that are set to true
    while IFS= read -r module; do
        if [[ -n "$module" && "$module" != "null" ]]; then
            local is_enabled=$(parse_yaml "$requirements_file" ".platform.modules.$module")
            if [[ "$is_enabled" == "true" ]]; then
                modules+=("$module")
            fi
        fi
    done < <(parse_yaml "$requirements_file" '.platform.modules | keys | .[]')
    
    printf '%s\n' "${modules[@]}"
}

# Function to generate platform module sources for ArgoCD
generate_platform_sources() {
    local app_name=$1
    local environment=$2
    local required_modules_file=$3
    local sources_yaml=""
    
    # Sort modules by priority
    local sorted_modules=()
    while IFS= read -r module; do
        if [[ -n "$module" ]]; then
            sorted_modules+=("$module")
        fi
    done < <(cat "$required_modules_file" | while read -r module; do
        priority=$(parse_yaml "$MODULE_MAPPINGS_FILE" ".platform_modules.$module.priority // 999")
        echo "$priority:$module"
    done | sort -n | cut -d':' -f2)
    
    for module in "${sorted_modules[@]}"; do
        local chart_path=$(parse_yaml "$MODULE_MAPPINGS_FILE" ".platform_modules.$module.chart_path")
        
        if [[ -n "$chart_path" && "$chart_path" != "null" ]]; then
            # Add source for this module
            sources_yaml+="  - repoURL: $CONFIG_REPO_URL
    targetRevision: main
    path: $chart_path
    helm:
      valueFiles:
        - values-$environment.yaml
      parameters:
        - name: app.name
          value: $app_name
        - name: app.environment
          value: $environment
"
        fi
    done
    
    echo "$sources_yaml"
}

# Function to generate ArgoCD application manifest
generate_argocd_app() {
    local app_name=$1
    local environment=$2
    local app_config_file=$3
    local required_modules_file=$4
    
    # Parse application configuration
    local repo_url=$(parse_yaml "$app_config_file" '.app.repoURL')
    local chart_path=$(parse_yaml "$app_config_file" '.app.chartPath')
    local team=$(parse_yaml "$app_config_file" '.app.team')
    local app_type=$(parse_yaml "$app_config_file" '.app.type')
    local container_registry=$(parse_yaml "$app_config_file" '.container.registry')
    local container_org=$(parse_yaml "$app_config_file" '.container.organization')
    local container_image=$(parse_yaml "$app_config_file" '.container.image')
    
    # Generate platform module sources
    local platform_sources=$(generate_platform_sources "$app_name" "$environment" "$required_modules_file")
    
    # Determine target revision and image tag pattern based on environment
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
    
    # Generate the ArgoCD application manifest
    cat << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $(echo "$app_name-$environment" | tr '[:upper:]' '[:lower:]')
  namespace: argocd
  labels:
    app.kubernetes.io/name: $(echo "$app_name" | tr '[:upper:]' '[:lower:]')
    app.kubernetes.io/part-of: spandaai-platform
    team: $team
    environment: $environment
    app-type: $app_type
  annotations:
    app.spanda.ai/generated: "true"
    app.spanda.ai/generator: "platform-automation"
    app.spanda.ai/generated-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    # ArgoCD Image Updater configuration
    argocd-image-updater.argoproj.io/image-list: $(echo "$app_name" | tr '[:upper:]' '[:lower:]')=$container_org/$container_image
    argocd-image-updater.argoproj.io/write-back-method: git:secret:argocd/argocd-image-updater-git
    argocd-image-updater.argoproj.io/git-branch: $target_revision
    argocd-image-updater.argoproj.io/$(echo "$app_name" | tr '[:upper:]' '[:lower:]').update-strategy: newest-build
    argocd-image-updater.argoproj.io/$(echo "$app_name" | tr '[:upper:]' '[:lower:]').allow-tags: regexp:$image_tag_pattern
    argocd-image-updater.argoproj.io/$(echo "$app_name" | tr '[:upper:]' '[:lower:]').helm.image-name: image.repository
    argocd-image-updater.argoproj.io/$(echo "$app_name" | tr '[:upper:]' '[:lower:]').helm.image-tag: image.tag
spec:
  project: spanda-applications
  sources:
$platform_sources  # Application source (highest priority - deployed last)
  - repoURL: $repo_url
    targetRevision: $target_revision
    path: $chart_path
    helm:
      valueFiles:
        - values-$environment.yaml
      parameters:
        - name: image.repository
          value: $container_org/$container_image
        - name: image.tag
          value: $image_tag_placeholder
  destination:
    server: https://kubernetes.default.svc
    namespace: $environment
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  info:
    - name: 'Generated By'
      value: 'Platform Automation'
    - name: 'Source Repository'
      value: '$repo_url'
    - name: 'Chart Path'
      value: '$chart_path'
    - name: 'Environment'
      value: '$environment'
    - name: 'Team'
      value: '$team'
    - name: 'Application Type'
      value: '$app_type'
    - name: 'Platform Modules'
      value: '$(cat "$required_modules_file" | tr '\n' ',' | sed 's/,$//')'
EOF
}

# Main function
main() {
    log "Starting ArgoCD application generation with platform modules..."
    
    # Check dependencies
    if ! command -v yq &> /dev/null; then
        error "yq is required but not installed. Please install yq."
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        error "git is required but not installed."
        exit 1
    fi
    
    # Check if module mappings file exists
    if [[ ! -f "$MODULE_MAPPINGS_FILE" ]]; then
        error "Module mappings file not found: $MODULE_MAPPINGS_FILE"
        exit 1
    fi
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Get list of applications from the local-app-repos directory
    local apps_dir="$BASE_DIR/local-app-repos"
    if [[ ! -d "$apps_dir" ]]; then
        error "Local app repositories directory not found: $apps_dir"
        exit 1
    fi
    
    for app_dir in "$apps_dir"/*; do
        if [[ -d "$app_dir" ]]; then
            local app_name=$(basename "$app_dir")
            log "Processing application: $app_name"
            
            # Look for platform-requirements.yml in the local app repository directory
            local requirements_file="$app_dir/platform-requirements.yml"
            
            if [[ -f "$requirements_file" ]]; then
                # Get required modules
                local modules_file="$TEMP_DIR/${app_name}_modules.txt"
                get_required_modules "$requirements_file" > "$modules_file"
                
                if [[ ! -s "$modules_file" ]]; then
                    warn "No platform modules required for $app_name"
                    echo "" > "$modules_file"
                fi
                
                # Get environments from requirements
                local environments=($(parse_yaml "$requirements_file" '.environments[]'))
                
                # Generate ArgoCD applications for each environment
                for env in "${environments[@]}"; do
                    if [[ -n "$env" && "$env" != "null" ]]; then
                        log "Generating ArgoCD application for $app_name-$env"
                        
                        # Output to the applications directory for ArgoCD discovery
                        local output_file="$BASE_DIR/applications/$app_name/argocd/app-$env.yaml"
                        mkdir -p "$(dirname "$output_file")"
                        
                        generate_argocd_app "$app_name" "$env" "$requirements_file" "$modules_file" > "$output_file"
                        
                        success "Generated: $output_file"
                    fi
                done
            else
                warn "No platform-requirements.yml found for $app_name, skipping..."
                continue
            fi
        fi
    done
    
    success "ArgoCD application generation completed!"
}

# Run main function
main "$@"
