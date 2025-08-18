#!/bin/bash

# SPANDA AI PLATFORM - DYNAMIC MICROSERVICES ARGOCD GENERATOR
# 
# This script generates ArgoCD applications by reading configuration directly
# from application repositories via GitHub API. Supports unlimited microservices!
#
# Expected CI/CD Image Tags:
# - <service>-latest (global latest for any branch)
# - <service>-<branch>-latest (branch-specific latest)
# - <service>-<branch>-<sha> (specific commit builds)
# - <service>-<sha> (sha-only builds)
#
# Environment Tag Patterns:
# - dev: Tracks testing branch images (frontend-testing-latest, backend-testing-latest)
# - staging: Tracks staging branch images (frontend-staging-latest, backend-staging-latest)  
# - production: Tracks main branch images (frontend-latest, frontend-main-latest)
#
# Author: Spanda AI DevOps Team
# Version: 4.0 (Dynamic N-Microservices + Branch-Specific Tags)    echo -e "🚀 Spanda Platform - Dynamic Microservices Generator v4.0"
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
    
    log "📖 Successfully read platform-requirements.yml from $repo_name"
    
    # Debug: Show first few lines of config
    log "🔍 Debug - Config preview:"
    echo "$platform_config" | head -10 | while read line; do
        log "    $line"
    done
    
    # Parse required fields
    local app_name app_type port
    app_name=$(parse_yaml "$platform_config" ".app.name")
    app_type=$(parse_yaml "$platform_config" ".app.type")  
    port=$(parse_yaml "$platform_config" ".app.port")
    
    log "🔍 Debug - Parsed values: app_name='$app_name', app_type='$app_type', port='$port'"
    
    # Validate required fields
    if [ -z "$app_name" ]; then
        log "❌ app.name not defined in platform-requirements.yml"
        return 1
    fi
    
    if [ -z "$app_type" ]; then
        log "❌ app.type not defined in platform-requirements.yml"
        return 1
    fi
    
    # Validate app type
    case "$app_type" in
        "frontend"|"backend"|"api"|"service"|"worker"|"database"|"fullstack")
            log "✅ Valid app type: $app_type"
            ;;
        *)
            log "❌ Invalid app type: $app_type. Must be one of: frontend, backend, api, service, worker, database, fullstack"
            return 1
            ;;
    esac
    
    # Port is optional but should be numeric if provided
    if [ -n "$port" ] && ! [[ "$port" =~ ^[0-9]+$ ]]; then
        log "❌ Invalid port: $port. Must be numeric"
        return 1
    fi
    
    log "✅ Platform requirements validated successfully"
    log "📋 Application: $app_name (type: $app_type)"
    [ -n "$port" ] && log "🔌 Port: $port"
    
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

# Function to discover microservices dynamically from repository structure
discover_microservices() {
    local repo_url="$1"
    local branch="$2"
    local repo_name="$3"
    local platform_config="$4"
    
    log "🔍 Discovering microservices in $repo_name" >&2
    
    # First check if microservices are explicitly defined in platform-requirements.yml
    local explicit_services=$(parse_yaml "$platform_config" '.microservices[].name' 2>/dev/null || echo "")
    if [[ -n "$explicit_services" ]]; then
        log "📋 Using explicitly defined microservices from platform-requirements.yml" >&2
        echo "$explicit_services"
        return 0
    fi
    
    # Convert GitHub URL to API URL
    local api_url=$(echo "$repo_url" | sed 's|https://github.com/|https://api.github.com/repos/|')
    
    # Get src directory contents
    local src_response=$(curl -s "$api_url/contents/src?ref=$branch" 2>/dev/null || echo "[]")
    
    # Check if src directory exists and has content
    if ! echo "$src_response" | jq -e '.[] | select(.type=="dir")' >/dev/null 2>&1; then
        log "📁 No src/ directory found, assuming single-service application" >&2
        echo "app"  # Default single service name
        return 0
    fi
    
    # Extract directory names from src/
    local microservices=()
    while IFS= read -r service; do
        if [[ -n "$service" && "$service" != "shared" ]]; then
            # Check if this directory contains a Dockerfile
            local dockerfile_check=$(curl -s "$api_url/contents/src/$service/Dockerfile?ref=$branch" 2>/dev/null || echo "")
            if echo "$dockerfile_check" | jq -e '.content' >/dev/null 2>&1; then
                microservices+=("$service")
                log "✅ Found microservice: $service (has Dockerfile)" >&2
            else
                log "⚠️  Directory $service exists but no Dockerfile found, skipping" >&2
            fi
        fi
    done < <(echo "$src_response" | jq -r '.[] | select(.type=="dir") | .name')
    
    # If no microservices found with Dockerfiles, check for single Dockerfile at root
    if [[ ${#microservices[@]} -eq 0 ]]; then
        local root_dockerfile=$(curl -s "$api_url/contents/Dockerfile?ref=$branch" 2>/dev/null || echo "")
        if echo "$root_dockerfile" | jq -e '.content' >/dev/null 2>&1; then
            log "📦 Single-service application detected (root Dockerfile)" >&2
            echo "app"
            return 0
        else
            error "❌ No Dockerfiles found in src/ directories or root" >&2
            return 1
        fi
    fi
    
    log "🎯 Discovered ${#microservices[@]} microservices: ${microservices[*]}" >&2
    printf '%s\n' "${microservices[@]}"
    return 0
}

# Function to generate dynamic image list for ArgoCD Image Updater
generate_image_list() {
    local services=("$@")
    local container_org="$1"
    local container_image="$2"
    shift 2
    local services=("$@")
    
    local image_list=""
    for service in "${services[@]}"; do
        if [[ -n "$image_list" ]]; then
            image_list+=","
        fi
        image_list+="${service}=${container_org}/${container_image}:${service}"
    done
    
    echo "$image_list"
}

# Function to generate dynamic image updater annotations
generate_image_updater_annotations() {
    local git_branch="$1"
    local image_tag_pattern="$2"
    local ignore_tags="$3"
    shift 3
    local services=("$@")
    
    for service in "${services[@]}"; do
        cat << EOF
    # ${service^} image configuration
    argocd-image-updater.argoproj.io/${service}.update-strategy: latest
    argocd-image-updater.argoproj.io/${service}.allow-tags: regexp:^${service}-${image_tag_pattern}
    argocd-image-updater.argoproj.io/${service}.helm.image-name: ${service}.image.repository
    argocd-image-updater.argoproj.io/${service}.helm.image-tag: ${service}.image.tag
    argocd-image-updater.argoproj.io/${service}.ignore-tags: ${ignore_tags}
    argocd-image-updater.argoproj.io/${service}.force-update: "false"
EOF
    done
}

# Function to generate dynamic Helm parameters
generate_helm_parameters() {
    local services=("$@")
    local container_org="$1"
    local container_image="$2"
    local image_tag_placeholder="$3"
    shift 3
    local services=("$@")
    
    for service in "${services[@]}"; do
        cat << EOF
        - name: frontend.image.repository
          value: ${container_org}/${container_image}
        - name: frontend.image.tag
          value: frontend-${image_tag_placeholder}
        - name: backend.image.repository
          value: ${container_org}/${container_image}
        - name: backend.image.tag
          value: backend-${image_tag_placeholder}
EOF
    done
}

# Function to generate ArgoCD application from repository data (Dynamic N-Microservices)
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
    [[ -z "$team" ]] && team="development-team"
    [[ -z "$app_type" ]] && app_type="application"
    [[ -z "$container_registry" ]] && container_registry="docker.io"
    [[ -z "$chart_path" ]] && chart_path="deploy/helm"
    
    # Use repo_name as app_name if not specified in config
    [[ -z "$app_name" ]] && app_name="$repo_name"
    
    # Discover microservices dynamically
    local microservices_list
    if ! microservices_list=$(discover_microservices "$repo_url" "$branch" "$repo_name" "$platform_config"); then
        error "❌ Failed to discover microservices in $repo_name"
        return 1
    fi
    
    # Convert to array
    local microservices=()
    while IFS= read -r service; do
        [[ -n "$service" ]] && microservices+=("$service")
    done <<< "$microservices_list"
    
    # Determine target revision and image tag based on environment
    local target_revision="$branch"
    local image_tag_pattern="[0-9a-f]{7,8}$"
    local image_tag_placeholder="placeholder"
    local ignore_tags=""
    
    log "🚀 Generating ArgoCD application for ${#microservices[@]} microservice(s): ${microservices[*]}" >&2
    log "🎯 Environment: $environment | Branch: $target_revision | Tag Pattern: $image_tag_pattern" >&2
    
    case "$environment" in
        "dev")
            [[ "$branch" == "main" ]] && target_revision="testing"
            image_tag_pattern="testing-latest$"
            image_tag_placeholder="testing-latest"
            ignore_tags="frontend-main-latest,frontend-staging-latest,backend-main-latest,backend-staging-latest"
            ;;
        "staging")
            target_revision="staging"
            image_tag_pattern="staging-latest$"
            image_tag_placeholder="staging-latest"
            ignore_tags="frontend-main-latest,frontend-testing-latest,backend-main-latest,backend-testing-latest"
            ;;
        "production")
            target_revision="main"
            image_tag_pattern="main-latest$"
            image_tag_placeholder="main-latest"
            ignore_tags="frontend-testing-latest,frontend-staging-latest,backend-testing-latest,backend-staging-latest"
            ;;
    esac
    
    # Generate dynamic image list with branch-specific tags
    local image_list=""
    for service in "${microservices[@]}"; do
        if [[ -n "$image_list" ]]; then
            image_list+=","
        fi
        image_list+="${service}=${container_org}/${container_image}:${service}-${image_tag_placeholder}"
    done
    
    # Generate ArgoCD application with dynamic microservices support
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
    microservices-count: "${#microservices[@]}"
  annotations:
    app.spanda.ai/generated: "true"
    app.spanda.ai/generator: "dynamic-microservices-deployment"
    app.spanda.ai/generated-at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    app.spanda.ai/microservices: "$(IFS=,; echo "${microservices[*]}")"
    app.spanda.ai/uses-platform-services: "true"
    # ArgoCD Image Updater configuration for dynamic microservices
    argocd-image-updater.argoproj.io/image-list: $image_list
    argocd-image-updater.argoproj.io/write-back-method: git:secret:argocd/argocd-image-updater-git
    argocd-image-updater.argoproj.io/git-branch: $target_revision
    # Write back to application repository, not config repository
    argocd-image-updater.argoproj.io/write-back-target: helmvalues
    argocd-image-updater.argoproj.io/git-repository: $repo_url
$(for service in "${microservices[@]}"; do
    cat << SERVICE_EOF
    # ${service^} image configuration
    argocd-image-updater.argoproj.io/${service}.update-strategy: digest
    argocd-image-updater.argoproj.io/${service}.allow-tags: regexp:^${service}-${image_tag_pattern}
    argocd-image-updater.argoproj.io/${service}.helm.image-name: ${service}.image.repository
    argocd-image-updater.argoproj.io/${service}.helm.image-tag: ${service}.image.tag
    argocd-image-updater.argoproj.io/${service}.force-update: "true"
SERVICE_EOF
done)
spec:
  project: spanda-applications
  source:
    repoURL: $repo_url
    targetRevision: $target_revision
    path: $chart_path
    helm:
      releaseName: $(echo "$app_name-$environment" | tr '[:upper:]' '[:lower:]')
      valueFiles:
        - values.yaml
        - values-$environment.yaml
      parameters:
$(for service in "${microservices[@]}"; do
    cat << PARAM_EOF
        - name: ${service}.image.repository
          value: $container_org/$container_image
        - name: ${service}.image.tag
          value: ${service}-$image_tag_placeholder
PARAM_EOF
done)
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
      value: 'Dynamic Microservices Generator'
    - name: 'Platform Services'
      value: 'Uses shared platform services'
    - name: 'Environment'
      value: '$environment'
    - name: 'Team'
      value: '$team'
    - name: 'Architecture'
      value: 'Microservices (${#microservices[@]} services: $(IFS=, ; echo "${microservices[*]}"))'
    - name: 'Discovered Services'
      value: '$(IFS=, ; echo "${microservices[*]}")'
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
