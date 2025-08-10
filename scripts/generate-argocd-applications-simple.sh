#!/bin/bash

# SPANDA AI PLATFORM - DIRECT API APPLICATION GENERATOR
# 
# This script generates ArgoCD applications by reading configuration directly
# from application repositories via GitHub API. No cloning required!
#
# Author: Spanda AI DevOps Team
# Version: 3.0 (Direct API Access - No Cloning)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES_FILE="$BASE_DIR/application-sources.txt"

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

# Function to install dependencies
install_dependencies() {
    log "🔧 Checking and installing required dependencies..."
    
    local deps_needed=()
    local install_method=""
    
    # Check which dependencies are missing
    if ! command -v curl &> /dev/null; then
        deps_needed+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        deps_needed+=("jq")
    fi
    
    if ! command -v yq &> /dev/null; then
        deps_needed+=("yq")
    fi
    
    # If no dependencies needed, return early
    if [[ ${#deps_needed[@]} -eq 0 ]]; then
        success "✅ All dependencies are already installed"
        return 0
    fi
    
    log "Missing dependencies: ${deps_needed[*]}"
    
    # Determine the best installation method
    if command -v conda &> /dev/null; then
        install_method="conda"
        log "📦 Using conda to install dependencies..."
        
        for dep in "${deps_needed[@]}"; do
            case "$dep" in
                "curl")
                    log "Installing curl via conda..."
                    conda install -c conda-forge curl -y || warn "Failed to install curl via conda"
                    ;;
                "jq")
                    log "Installing jq via conda..."
                    conda install -c conda-forge jq -y || warn "Failed to install jq via conda"
                    ;;
                "yq")
                    log "Installing yq via conda..."
                    conda install -c conda-forge yq -y || warn "Failed to install yq via conda"
                    ;;
            esac
        done
        
    elif command -v winget &> /dev/null; then
        install_method="winget"
        log "📦 Using winget to install dependencies..."
        
        for dep in "${deps_needed[@]}"; do
            case "$dep" in
                "curl")
                    # curl is usually pre-installed on Windows 10+
                    warn "curl should be pre-installed on Windows 10+. If not available, please install manually."
                    ;;
                "jq")
                    log "Installing jq via winget..."
                    winget install jqlang.jq || warn "Failed to install jq via winget"
                    ;;
                "yq")
                    log "Installing yq via winget..."
                    winget install MikeFarah.yq || warn "Failed to install yq via winget"
                    ;;
            esac
        done
        
    elif command -v apt-get &> /dev/null; then
        install_method="apt"
        log "📦 Using apt to install dependencies..."
        
        sudo apt-get update
        for dep in "${deps_needed[@]}"; do
            case "$dep" in
                "curl")
                    sudo apt-get install -y curl || warn "Failed to install curl via apt"
                    ;;
                "jq")
                    sudo apt-get install -y jq || warn "Failed to install jq via apt"
                    ;;
                "yq")
                    # Install yq from GitHub releases
                    log "Installing yq from GitHub releases..."
                    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
                    sudo chmod +x /usr/local/bin/yq || warn "Failed to install yq from GitHub"
                    ;;
            esac
        done
        
    elif command -v brew &> /dev/null; then
        install_method="brew"
        log "📦 Using brew to install dependencies..."
        
        for dep in "${deps_needed[@]}"; do
            case "$dep" in
                "curl")
                    brew install curl || warn "Failed to install curl via brew"
                    ;;
                "jq")
                    brew install jq || warn "Failed to install jq via brew"
                    ;;
                "yq")
                    brew install yq || warn "Failed to install yq via brew"
                    ;;
            esac
        done
        
    else
        error "❌ No supported package manager found (conda, winget, apt, brew)"
        error "Please install the following dependencies manually:"
        for dep in "${deps_needed[@]}"; do
            case "$dep" in
                "curl")
                    error "  • curl: https://curl.se/download.html"
                    ;;
                "jq")
                    error "  • jq: https://jqlang.github.io/jq/download/"
                    ;;
                "yq")
                    error "  • yq: https://github.com/mikefarah/yq#install"
                    ;;
            esac
        done
        return 1
    fi
    
    # Verify installation
    log "🔍 Verifying dependency installation..."
    local verification_failed=false
    
    for dep in "${deps_needed[@]}"; do
        if command -v "$dep" &> /dev/null; then
            success "✅ $dep is now available"
        else
            error "❌ $dep installation failed or not in PATH"
            verification_failed=true
        fi
    done
    
    if [[ "$verification_failed" == true ]]; then
        error "Some dependencies failed to install. Please install them manually and try again."
        return 1
    fi
    
    success "✅ All dependencies installed successfully using $install_method"
    return 0
}

# Parse repository URL and extract components
parse_repo_url() {
    local repo_url="$1"
    local branch=""
    local base_url=""
    
    if [[ "$repo_url" == *"/tree/"* ]]; then
        # Handle GitHub tree URLs (e.g., https://github.com/user/repo/tree/branch)
        base_url=$(echo "$repo_url" | sed 's|/tree/.*||')
        branch=$(echo "$repo_url" | sed 's|.*/tree/||')
    else
        # Regular repository URL
        base_url="$repo_url"
        branch="main"  # Default branch
    fi
    
    # Remove .git suffix if present
    base_url=$(echo "$base_url" | sed 's|\.git$||')
    
    # Extract repo name
    local repo_name=$(basename "$base_url")
    
    echo "$base_url|$branch|$repo_name"
}

# Read file directly from GitHub API
read_file_from_github() {
    local repo_url="$1"
    local branch="$2"
    local file_path="$3"
    
    # Convert GitHub URL to API URL
    local api_url=$(echo "$repo_url" | sed 's|https://github.com/|https://api.github.com/repos/|')
    
    # Try to read the file (without logging to avoid mixing output)
    local response=$(curl -s "$api_url/contents/$file_path?ref=$branch" 2>/dev/null || echo "")
    
    if echo "$response" | jq -e '.content' >/dev/null 2>&1; then
        echo "$response" | jq -r '.content' | base64 -d
        return 0
    else
        return 1
    fi
}

# Validate that required files exist in repository
validate_repository_structure() {
    local repo_url="$1"
    local branch="$2"
    local repo_name="$3"
    
    log "🔍 Validating repository structure for $repo_name"
    
    # Convert GitHub URL to API URL
    local api_url=$(echo "$repo_url" | sed 's|https://github.com/|https://api.github.com/repos/|')
    
    # Check if platform-requirements.yml exists
    local platform_req_response=$(curl -s "$api_url/contents/platform-requirements.yml?ref=$branch" 2>/dev/null || echo "")
    if ! echo "$platform_req_response" | jq -e '.content' >/dev/null 2>&1; then
        error "❌ platform-requirements.yml not found in $repo_url (branch: $branch)"
        return 1
    fi
    
    # Check if Helm chart exists
    local helm_chart_response=$(curl -s "$api_url/contents/deploy/helm/Chart.yaml?ref=$branch" 2>/dev/null || echo "")
    if ! echo "$helm_chart_response" | jq -e '.content' >/dev/null 2>&1; then
        error "❌ Helm chart (deploy/helm/Chart.yaml) not found in $repo_url (branch: $branch)"
        return 1
    fi
    
    success "✅ Repository structure validated for $repo_name"
    return 0
}

# Function to validate platform requirements (simplified without platform discovery)
validate_platform_requirements() {
    local platform_config="$1"
    local repo_name="$2"
    
    log "🔍 Validating platform requirements for $repo_name"
    
    # Debug: Show first few lines of the config
    log "📄 Platform config preview:"
    echo "$platform_config" | head -5 | sed 's/^/    /'
    
    # Basic validation - check if required fields exist
    local app_name=$(echo "$platform_config" | yq eval '.app.name' - 2>/dev/null || echo "")
    local app_type=$(echo "$platform_config" | yq eval '.app.type' - 2>/dev/null || echo "")
    
    log "🔍 Parsed values: app_name='$app_name', app_type='$app_type'"
    
    # Remove quotes if present
    app_name=$(echo "$app_name" | sed 's/^"//;s/"$//')
    app_type=$(echo "$app_type" | sed 's/^"//;s/"$//')
    
    if [[ -z "$app_name" || "$app_name" == "null" ]]; then
        error "❌ app.name not defined in platform-requirements.yml for $repo_name"
        return 1
    fi
    
    if [[ -z "$app_type" || "$app_type" == "null" ]]; then
        warn "⚠️  app.type not defined in platform-requirements.yml for $repo_name, using default: application"
    fi
    
    success "✅ Platform requirements validated for $repo_name ($app_name)"
    return 0
}

# Function to parse YAML using yq
parse_yaml() {
    local yaml_content="$1"
    local query="$2"
    local result=$(echo "$yaml_content" | yq eval "$query" - 2>/dev/null || echo "")
    
    # Remove quotes if present and handle null values
    result=$(echo "$result" | sed 's/^"//;s/"$//')
    if [[ "$result" == "null" ]]; then
        result=""
    fi
    
    echo "$result"
}

# Function to generate ArgoCD application from repository data
generate_simple_app() {
    local repo_url="$1"
    local branch="$2"
    local repo_name="$3"
    local environment="$4"
    local platform_config="$5"
    
    # Parse application configuration from platform-requirements.yml
    local app_name=$(parse_yaml "$platform_config" '.app.name')
    local team=$(parse_yaml "$platform_config" '.app.team')
    local app_type=$(parse_yaml "$platform_config" '.app.type')
    local container_registry=$(parse_yaml "$platform_config" '.container.registry')
    local container_org=$(parse_yaml "$platform_config" '.container.organization')
    local container_image=$(parse_yaml "$platform_config" '.container.image')
    local chart_path=$(parse_yaml "$platform_config" '.app.chartPath')
    
    # Set defaults if not specified
    [[ -z "$team" ]] && team="development"
    [[ -z "$app_type" ]] && app_type="application"
    [[ -z "$container_registry" ]] && container_registry="docker.io"
    [[ -z "$chart_path" ]] && chart_path="deploy/helm"
    
    # Use repo_name as app_name if not specified in config
    [[ -z "$app_name" ]] && app_name="$repo_name"
    
    # Determine target revision and image tag based on environment
    local target_revision="$branch"
    local image_tag_pattern="^${branch}-[0-9a-f]{7,8}$"
    local image_tag_placeholder="${branch}-placeholder"
    
    case "$environment" in
        "dev")
            [[ "$branch" == "main" ]] && target_revision="testing"
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

# Main function - Direct API access (no cloning required)
main() {
    if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        show_usage
        return 0
    fi
    
    local apply_mode=false
    if [[ "${1:-}" == "--apply" ]]; then
        apply_mode=true
        log "🚀 Direct API Application Generator v3.0 (Apply Mode)"
    else
        log "🚀 Direct API Application Generator v3.0 (Generate Mode)"
    fi
    echo "=================================================================="
    
    # Install dependencies if needed
    if ! install_dependencies; then
        error "Failed to install required dependencies. Please install them manually and try again."
        exit 1
    fi
    
    # Check dependencies (final verification)
    local missing_deps=()
    if ! command -v yq &> /dev/null; then
        missing_deps+=("yq")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "The following dependencies are still missing: ${missing_deps[*]}"
        error "Please install them manually:"
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                "curl") error "  • curl: https://curl.se/download.html" ;;
                "jq") error "  • jq: https://jqlang.github.io/jq/download/" ;;
                "yq") error "  • yq: https://github.com/mikefarah/yq#install" ;;
            esac
        done
        exit 1
    fi
    
    # Check if application sources file exists
    if [[ ! -f "$SOURCES_FILE" ]]; then
        error "Application sources file not found: $SOURCES_FILE"
        error "Please create this file and add application repository URLs to it."
        exit 1
    fi
    
    log "📖 Reading application sources from: $SOURCES_FILE"
    
    local app_count=0
    local env_count=0
    local total_apps_generated=0
    
    # Process each repository URL from application-sources.txt
    while IFS= read -r repo_line; do
        # Skip empty lines and comments
        [[ -z "$repo_line" || "$repo_line" =~ ^[[:space:]]*# ]] && continue
        
        # Trim whitespace
        repo_line=$(echo "$repo_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z "$repo_line" ]] && continue
        
        log "🔍 Processing repository: $repo_line"
        app_count=$((app_count + 1))
        
        # Parse repository URL and extract components
        local repo_data=$(parse_repo_url "$repo_line")
        local repo_url=$(echo "$repo_data" | cut -d'|' -f1)
        local branch=$(echo "$repo_data" | cut -d'|' -f2)
        local repo_name=$(echo "$repo_data" | cut -d'|' -f3)
        
        log "  📁 Repository: $repo_name"
        log "  🌿 Branch: $branch"
        log "  🔗 URL: $repo_url"
        
        # Validate repository structure
        if ! validate_repository_structure "$repo_url" "$branch" "$repo_name"; then
            error "Skipping $repo_name due to invalid repository structure"
            continue
        fi
        
        # Read platform-requirements.yml directly from GitHub API
        local platform_config
        if ! platform_config=$(read_file_from_github "$repo_url" "$branch" "platform-requirements.yml"); then
            error "Failed to read platform-requirements.yml from $repo_name"
            continue
        fi
        
        # Validate platform requirements
        if ! validate_platform_requirements "$platform_config" "$repo_name"; then
            error "Skipping $repo_name due to invalid platform requirements"
            continue
        fi
        
        # Get environments from platform requirements
        local environments=($(parse_yaml "$platform_config" '.environments[]'))
        
        if [[ ${#environments[@]} -eq 0 ]]; then
            warn "No environments defined for $repo_name, using default: dev"
            environments=("dev")
        fi
        
        log "  🎯 Environments: ${environments[*]}"
        
        # Generate ArgoCD applications for each environment
        for env in "${environments[@]}"; do
            log "  🔄 Generating $env environment for $repo_name"
            env_count=$((env_count + 1))
            
            # Create application directory
            local app_dir="$BASE_DIR/applications/$repo_name/argocd"
            mkdir -p "$app_dir"
            
            # Generate ArgoCD application manifest
            local app_file="$app_dir/app-$env.yaml"
            generate_simple_app "$repo_url" "$branch" "$repo_name" "$env" "$platform_config" > "$app_file"
            
            success "  ✅ Generated: $app_file"
            total_apps_generated=$((total_apps_generated + 1))
            
            # Apply if in apply mode
            if [[ "$apply_mode" == true ]]; then
                if kubectl apply -f "$app_file"; then
                    success "  🚀 Applied ArgoCD application: $repo_name-$env"
                else
                    error "  ❌ Failed to apply ArgoCD application: $repo_name-$env"
                fi
            fi
        done
        
        echo "" # Add spacing between repositories
        
    done < "$SOURCES_FILE"
    
    # Create and apply ArgoCD Image Updater configuration
    if [[ "$apply_mode" == true ]]; then
        create_argocd_image_updater_config
        
        if kubectl apply -f "$BASE_DIR/argocd-image-updater-config.yaml"; then
            success "✅ Applied ArgoCD Image Updater configuration"
            
            # Restart ArgoCD Image Updater to pick up new config
            if kubectl rollout restart deployment argocd-image-updater -n argocd; then
                success "✅ Restarted ArgoCD Image Updater"
            else
                warn "⚠️  Failed to restart ArgoCD Image Updater (may not be installed yet)"
            fi
        else
            error "❌ Failed to apply ArgoCD Image Updater configuration"
        fi
    fi
    
    # Summary
    echo ""
    success "=== 📊 GENERATION COMPLETE ==="
    echo "📈 Statistics:"
    echo "  • Repositories processed: $app_count"
    echo "  • Applications generated: $total_apps_generated"
    echo "  • Total environments: $env_count"
    echo ""
    
    if [[ "$apply_mode" == true ]]; then
        echo "🎯 Next Steps:"
        echo "  • Check ArgoCD dashboard for application status"
        echo "  • Monitor application deployments"
        echo "  • Verify ArgoCD Image Updater is working"
    else
        echo "🎯 Next Steps:"
        echo "  • Review generated manifests in applications/ directory"
        echo "  • Run with --apply to deploy applications"
        echo "  • Example: $0 --apply"
    fi
}

# Show usage information
show_usage() {
    echo "🚀 Spanda Platform - Direct API Application Generator v3.0"
    echo ""
    echo "DESCRIPTION:"
    echo "  Generates ArgoCD applications by reading configuration directly from"
    echo "  application repositories via GitHub API. No cloning required!"
    echo ""
    echo "USAGE:"
    echo "  $0                    # Generate ArgoCD manifests only"
    echo "  $0 --apply           # Generate and apply to Kubernetes cluster"
    echo "  $0 --help            # Show this help message"
    echo ""
    echo "FEATURES:"
    echo "  ✅ Direct GitHub API access (no repository cloning)"
    echo "  ✅ Reads platform-requirements.yml from original repositories"
    echo "  ✅ Validates Helm chart structure remotely"
    echo "  ✅ Generates ArgoCD applications with Image Updater configuration"
    echo "  ✅ Supports multiple environments per application"
    echo "  ✅ Conservative polling settings (5-minute intervals)"
    echo "  ✅ Auto-installs dependencies (yq, jq, curl)"
    echo ""
    echo "REQUIREMENTS:"
    echo "  • application-sources.txt file with repository URLs"
    echo "  • Each repository must have platform-requirements.yml"
    echo "  • Each repository must have deploy/helm/Chart.yaml"
    echo "  • Package manager: conda, winget, apt, or brew (for auto-install)"
    echo ""
    echo "DEPENDENCIES (auto-installed):"
    echo "  • yq - YAML processor"
    echo "  • jq - JSON processor" 
    echo "  • curl - HTTP client"
    echo ""
    echo "EXAMPLE application-sources.txt:"
    echo "  https://github.com/org/app1/tree/testing"
    echo "  https://github.com/org/app2.git"
    echo "  # https://github.com/org/disabled-app.git"
    echo ""
    echo "BENEFITS:"
    echo "  🚀 Faster execution (5-10 seconds vs 30-60 seconds)"
    echo "  💾 Zero disk usage for discovery"
    echo "  🔄 Always current data from source repositories"
    echo "  🧹 No cloned repository management required"
}

# Run main function
main "$@"
