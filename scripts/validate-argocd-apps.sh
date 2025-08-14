#!/bin/bash

# SPANDA AI PLATFORM - ArgoCD Applications Validator
# Validates ArgoCD application configurations for proper formatting

set -euo pipefail

# Colors for output
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

# Function to validate YAML syntax
validate_yaml() {
    local file="$1"
    log "Validating YAML syntax: $(basename "$file")"
    
    if ! yq eval '.' "$file" >/dev/null 2>&1; then
        error "Invalid YAML syntax in $file"
        return 1
    fi
    
    success "✅ YAML syntax is valid"
    return 0
}

# Function to validate ArgoCD Image Updater annotations
validate_image_updater_annotations() {
    local file="$1"
    log "Validating ArgoCD Image Updater annotations: $(basename "$file")"
    
    local errors=0
    
    # Check required annotations
    if ! yq eval '.metadata.annotations."argocd-image-updater.argoproj.io/image-list"' "$file" >/dev/null 2>&1; then
        error "Missing image-list annotation"
        ((errors++))
    fi
    
    if ! yq eval '.metadata.annotations."argocd-image-updater.argoproj.io/write-back-method"' "$file" >/dev/null 2>&1; then
        error "Missing write-back-method annotation"
        ((errors++))
    fi
    
    if ! yq eval '.metadata.annotations."argocd-image-updater.argoproj.io/git-branch"' "$file" >/dev/null 2>&1; then
        error "Missing git-branch annotation"
        ((errors++))
    fi
    
    # Check frontend annotations
    if ! yq eval '.metadata.annotations."argocd-image-updater.argoproj.io/frontend.allow-tags"' "$file" >/dev/null 2>&1; then
        error "Missing frontend.allow-tags annotation"
        ((errors++))
    fi
    
    # Check backend annotations
    if ! yq eval '.metadata.annotations."argocd-image-updater.argoproj.io/backend.allow-tags"' "$file" >/dev/null 2>&1; then
        error "Missing backend.allow-tags annotation"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        success "✅ All required Image Updater annotations present"
        return 0
    else
        error "❌ Found $errors annotation issues"
        return 1
    fi
}

# Function to validate Helm parameters
validate_helm_parameters() {
    local file="$1"
    log "Validating Helm parameters: $(basename "$file")"
    
    local errors=0
    local environment
    environment=$(yq eval '.metadata.labels.environment' "$file")
    
    # Expected tag patterns based on environment
    local expected_frontend_tag expected_backend_tag
    case "$environment" in
        "dev"|"development")
            expected_frontend_tag="frontend-testing-latest"
            expected_backend_tag="backend-testing-latest"
            ;;
        "staging")
            expected_frontend_tag="frontend-staging-latest"
            expected_backend_tag="backend-staging-latest"
            ;;
        "production"|"prod")
            expected_frontend_tag="frontend-main-latest"
            expected_backend_tag="backend-main-latest"
            ;;
        *)
            warn "Unknown environment: $environment"
            return 0
            ;;
    esac
    
    # Check frontend image tag
    local frontend_tag
    frontend_tag=$(yq eval '.spec.source.helm.parameters[] | select(.name == "frontend.image.tag") | .value' "$file")
    if [[ "$frontend_tag" != "$expected_frontend_tag" ]]; then
        error "Frontend image tag mismatch. Expected: $expected_frontend_tag, Got: $frontend_tag"
        ((errors++))
    fi
    
    # Check backend image tag
    local backend_tag
    backend_tag=$(yq eval '.spec.source.helm.parameters[] | select(.name == "backend.image.tag") | .value' "$file")
    if [[ "$backend_tag" != "$expected_backend_tag" ]]; then
        error "Backend image tag mismatch. Expected: $expected_backend_tag, Got: $backend_tag"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        success "✅ Helm parameters are correct for $environment environment"
        return 0
    else
        error "❌ Found $errors Helm parameter issues"
        return 1
    fi
}

# Main validation function
validate_argocd_app() {
    local file="$1"
    log "===========================================" 
    log "Validating ArgoCD Application: $(basename "$file")"
    log "==========================================="
    
    local validation_errors=0
    
    # Validate YAML syntax
    if ! validate_yaml "$file"; then
        ((validation_errors++))
    fi
    
    # Validate Image Updater annotations
    if ! validate_image_updater_annotations "$file"; then
        ((validation_errors++))
    fi
    
    # Validate Helm parameters
    if ! validate_helm_parameters "$file"; then
        ((validation_errors++))
    fi
    
    if [[ $validation_errors -eq 0 ]]; then
        success "🎉 $(basename "$file") validation passed!"
        return 0
    else
        error "💥 $(basename "$file") validation failed with $validation_errors error(s)"
        return 1
    fi
}

# Main function
main() {
    log "🚀 ArgoCD Applications Validator v1.0"
    log "======================================"
    
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local apps_dir="$script_dir/../applications/Test-Application/argocd"
    
    if [[ ! -d "$apps_dir" ]]; then
        error "Applications directory not found: $apps_dir"
        exit 1
    fi
    
    local total_errors=0
    local apps_validated=0
    
    # Validate all ArgoCD application files
    for app_file in "$apps_dir"/app-*.yaml; do
        if [[ -f "$app_file" ]]; then
            if validate_argocd_app "$app_file"; then
                ((apps_validated++))
            else
                ((total_errors++))
            fi
            echo ""
        fi
    done
    
    log "=========================================="
    log "Validation Summary:"
    log "Applications validated: $apps_validated"
    log "Applications with errors: $total_errors"
    log "=========================================="
    
    if [[ $total_errors -eq 0 ]]; then
        success "🎉 All ArgoCD applications are valid!"
        exit 0
    else
        error "💥 Found issues in $total_errors application(s)"
        exit 1
    fi
}

# Check dependencies
if ! command -v yq &> /dev/null; then
    error "yq is required but not installed. Please install yq first."
    exit 1
fi

# Run main function
main "$@"
