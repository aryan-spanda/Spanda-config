#!/bin/bash

# =============================================================================
# SPANDA AI PLATFORM - INTELLIGENT TENANT ONBOARDING SCRIPT
# =============================================================================
# This script automates the tenant onboarding process by reading from:
# 1. Central tenant-sources.yml file
# 2. Application repository platform-requirements.yml files
# 
# It intelligently discovers tenants and applies Terraform configurations.
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

info() {
    echo -e "${PURPLE}[INFO]${NC} $1"
}

# =============================================================================
# CONFIGURATION
# =============================================================================
# Updated to use the tenant infrastructure within the config repo
TENANT_ONBOARDING_TF_PATH="../tenants/infrastructure"
TENANT_SOURCES_FILE="../tenants/tenant-sources.yml"
APPLICATION_SOURCES_FILE="../application-sources.yml"

echo
log "🚀 Starting Spanda Platform Intelligent Tenant Onboarding..."
echo "==============================================================="

# =============================================================================
# PREREQUISITE CHECKS
# =============================================================================
log "🔍 Checking prerequisites..."

check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "❌ $1 is not installed. Please install it to proceed."
        return 1
    fi
    return 0
}

# Check required tools
check_command "yq" || exit 1
check_command "terraform" || exit 1
check_command "kubectl" || exit 1
check_command "curl" || exit 1
check_command "jq" || exit 1

# Check Kubernetes connectivity
if ! kubectl cluster-info &> /dev/null; then
    error "❌ Cannot connect to Kubernetes cluster. Ensure your KUBECONFIG is set correctly."
    exit 1
fi

# Check if files exist
if [[ ! -f "$TENANT_SOURCES_FILE" ]]; then
    error "❌ Tenant sources file not found: $TENANT_SOURCES_FILE"
    exit 1
fi

if [[ ! -d "$TENANT_ONBOARDING_TF_PATH" ]]; then
    error "❌ Terraform onboarding directory not found: $TENANT_ONBOARDING_TF_PATH"
    error "   Please ensure the spandaai-platform-deployment repository is cloned at the correct location."
    exit 1
fi

success "✅ All prerequisites met"

# =============================================================================
# TENANT DISCOVERY FUNCTIONS
# =============================================================================

# Function to fetch platform-requirements.yml from GitHub
fetch_platform_requirements() {
    local repo_url="$1"
    local temp_file=$(mktemp)
    
    # Convert GitHub repo URL to raw content URL
    local raw_url
    if [[ "$repo_url" =~ github\.com/([^/]+)/([^/]+) ]]; then
        local owner="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]}"
        repo="${repo%.git}"  # Remove .git suffix if present
        raw_url="https://raw.githubusercontent.com/${owner}/${repo}/main/platform-requirements.yml"
        
        log "  📥 Fetching platform-requirements.yml from $raw_url"
        
        if curl -s -f -o "$temp_file" "$raw_url"; then
            echo "$temp_file"
            return 0
        else
            warn "  ⚠️  Could not fetch platform-requirements.yml from $repo_url"
            rm -f "$temp_file"
            return 1
        fi
    else
        warn "  ⚠️  Invalid GitHub URL format: $repo_url"
        rm -f "$temp_file"
        return 1
    fi
}

# Function to discover tenants from application repositories
discover_tenants_from_apps() {
    log "🔍 Discovering tenants from application repositories..."
    
    if [[ ! -f "$APPLICATION_SOURCES_FILE" ]]; then
        warn "⚠️  Application sources file not found: $APPLICATION_SOURCES_FILE"
        return 0
    fi
    
    local discovered_tenants=()
    
    while IFS= read -r repo_url; do
        # Skip empty lines and comments
        [[ -z "$repo_url" || "$repo_url" =~ ^[[:space:]]*# ]] && continue
        
        log "  🔍 Scanning repository: $repo_url"
        
        local temp_file
        if temp_file=$(fetch_platform_requirements "$repo_url"); then
            # Extract tenant information
            local tenant_name
            local git_org
            
            if tenant_name=$(yq e '.app.tenant' "$temp_file" 2>/dev/null) && [[ "$tenant_name" != "null" && -n "$tenant_name" ]]; then
                # Extract git org from repo URL
                if [[ "$repo_url" =~ github\.com/([^/]+)/ ]]; then
                    git_org="${BASH_REMATCH[1]}"
                    
                    info "  ✨ Found tenant '$tenant_name' in repository (org: $git_org)"
                    
                    # Extract modules from platform-requirements.yml
                    local modules_yaml
                    modules_yaml=$(yq e '.modules' -o=json "$temp_file" 2>/dev/null || echo "[]")
                    
                    # Check if tenant already exists in tenant-sources.yml
                    local tenant_exists
                    tenant_exists=$(yq e ".tenants[] | select(.name == \"$tenant_name\") | .name" "$TENANT_SOURCES_FILE" 2>/dev/null || echo "")
                    
                    if [[ -z "$tenant_exists" ]]; then
                        discovered_tenants+=("$tenant_name:$git_org:$modules_yaml")
                        info "  🆕 New tenant discovered: $tenant_name with modules"
                    else
                        info "  ✅ Tenant '$tenant_name' already defined in tenant-sources.yml"
                        # Update modules for existing tenant
                        log "  🔄 Updating modules for existing tenant '$tenant_name'"
                        yq e "(.tenants[] | select(.name == \"$tenant_name\") | .modules) = $modules_yaml" -i "$TENANT_SOURCES_FILE"
                        success "  ✅ Updated modules for tenant '$tenant_name'"
                    fi
                fi
            fi
            
            rm -f "$temp_file"
        fi
    done < "$APPLICATION_SOURCES_FILE"
    
    # Auto-add discovered tenants with default quotas
    if [[ ${#discovered_tenants[@]} -gt 0 ]]; then
        log "📝 Auto-adding discovered tenants with default quotas..."
        
        for tenant_info in "${discovered_tenants[@]}"; do
            # Parse tenant_info which is in format: tenant_name:git_org:modules_json
            # Need to handle the fact that modules_json might contain colons
            local tenant_name=$(echo "$tenant_info" | cut -d':' -f1)
            local git_org=$(echo "$tenant_info" | cut -d':' -f2)
            local modules_json=$(echo "$tenant_info" | cut -d':' -f3-)
            
            # Get default quotas from discovery settings
            local cpu_quota=$(yq e '.discovery.default_quotas.cpu_quota' "$TENANT_SOURCES_FILE")
            local memory_quota=$(yq e '.discovery.default_quotas.memory_quota' "$TENANT_SOURCES_FILE")
            local storage_quota=$(yq e '.discovery.default_quotas.storage_quota' "$TENANT_SOURCES_FILE")
            local gpu_quota=$(yq e '.discovery.default_quotas.gpu_quota' "$TENANT_SOURCES_FILE")
            
            log "  ➕ Adding tenant '$tenant_name' with default quotas and modules"
            
            # Add to tenant-sources.yml with modules
            yq e ".tenants += [{\"name\": \"$tenant_name\", \"git_org\": \"$git_org\", \"description\": \"Auto-discovered tenant\", \"cpu_quota\": \"$cpu_quota\", \"memory_quota\": \"$memory_quota\", \"storage_quota\": \"$storage_quota\", \"gpu_quota\": \"$gpu_quota\", \"environments\": [\"dev\", \"staging\", \"production\"], \"modules\": $modules_json}]" -i "$TENANT_SOURCES_FILE"
            
            success "  ✅ Added tenant '$tenant_name' with modules to tenant-sources.yml"
        done
    fi
}

# =============================================================================
# TERRAFORM OPERATIONS
# =============================================================================

# Function to onboard a single tenant
onboard_tenant() {
    local name="$1"
    local git_org="$2"
    local cpu_quota="$3"
    local memory_quota="$4"
    local storage_quota="$5"
    local gpu_quota="$6"
    local environments="$7"
    local modules_json="$8"
    
    log "🏗️  Processing tenant: $name"
    
    # Check if the tenant's ArgoCD AppProject already exists
    if kubectl get appproject "$name" -n argocd --ignore-not-found 2>/dev/null | grep -q "$name"; then
        success "  ✅ Tenant '$name' already exists in the cluster. Skipping."
        return 0
    fi
    
    info "  ✨ New tenant detected. Applying Terraform configuration..."
    
    # Create temporary .tfvars file for this tenant
    local tfvars_file=$(mktemp)
    cat > "$tfvars_file" <<EOF
tenant_name    = "$name"
tenant_git_org = "$git_org"
cpu_quota      = "$cpu_quota"
memory_quota   = "$memory_quota"
storage_quota  = "$storage_quota"
gpu_quota      = "$gpu_quota"
EOF

    # Add modules to tfvars if provided and not empty
    if [[ -n "$modules_json" && "$modules_json" != "null" && "$modules_json" != "[]" ]]; then
        echo "modules = $modules_json" >> "$tfvars_file"
        log "  📦 Added modules configuration for tenant '$name'"
    else
        echo "modules = []" >> "$tfvars_file"
        log "  📦 No modules specified for tenant '$name'"
    fi
    
    log "  📄 Generated Terraform variables for '$name'"
    
    # Run Terraform apply for this specific tenant
    log "  🚀 Applying Terraform configuration..."
    if (cd "$TENANT_ONBOARDING_TF_PATH" && terraform apply -var-file="$tfvars_file" -auto-approve); then
        success "  ✅ Successfully onboarded tenant: $name"
        
        # Verify the deployment
        log "  🔍 Verifying tenant deployment..."
        
        # Check ArgoCD project
        if kubectl get appproject "$name" -n argocd >/dev/null 2>&1; then
            success "    ✅ ArgoCD project created"
        else
            warn "    ⚠️  ArgoCD project not found"
        fi
        
        # Check namespaces
        local namespace_count=$(kubectl get namespaces -l "spanda.ai/tenant=$name" --no-headers 2>/dev/null | wc -l)
        success "    ✅ Created $namespace_count tenant namespaces"
        
    else
        error "  ❌ Failed to onboard tenant: $name"
        rm -f "$tfvars_file"
        return 1
    fi
    
    # Clean up
    rm -f "$tfvars_file"
    return 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Initialize Terraform
log "🔧 Initializing Terraform..."
if ! (cd "$TENANT_ONBOARDING_TF_PATH" && terraform init -upgrade); then
    error "❌ Terraform initialization failed"
    exit 1
fi
success "✅ Terraform initialized"

# Discover tenants from application repositories if enabled
if [[ "$(yq e '.discovery.enabled' "$TENANT_SOURCES_FILE")" == "true" ]]; then
    if [[ "$(yq e '.discovery.scan_application_repos' "$TENANT_SOURCES_FILE")" == "true" ]]; then
        discover_tenants_from_apps
    fi
fi

# Process tenants from tenant-sources.yml
log "📋 Processing tenants from: $TENANT_SOURCES_FILE"

tenant_count=$(yq e '.tenants | length' "$TENANT_SOURCES_FILE")
log "Found $tenant_count tenant(s) to process"

if [[ "$tenant_count" -eq 0 ]]; then
    warn "⚠️  No tenants found in $TENANT_SOURCES_FILE"
    exit 0
fi

echo
log "🏭 Starting tenant onboarding process..."
echo "======================================="

failed_tenants=()
successful_tenants=()

for i in $(seq 0 $((tenant_count - 1))); do
    # Extract tenant details
    name=$(yq e ".tenants[$i].name" "$TENANT_SOURCES_FILE")
    git_org=$(yq e ".tenants[$i].git_org" "$TENANT_SOURCES_FILE")
    cpu_quota=$(yq e ".tenants[$i].cpu_quota" "$TENANT_SOURCES_FILE")
    memory_quota=$(yq e ".tenants[$i].memory_quota" "$TENANT_SOURCES_FILE")
    storage_quota=$(yq e ".tenants[$i].storage_quota" "$TENANT_SOURCES_FILE")
    gpu_quota=$(yq e ".tenants[$i].gpu_quota // \"0\"" "$TENANT_SOURCES_FILE")
    environments=$(yq e ".tenants[$i].environments" "$TENANT_SOURCES_FILE")
    
    # Extract modules as JSON string for Terraform
    modules_json=$(yq e ".tenants[$i].modules // [] | to_json" "$TENANT_SOURCES_FILE")
    
    echo
    log "[$((i+1))/$tenant_count] Processing tenant: $name"
    echo "----------------------------------------"
    
    if onboard_tenant "$name" "$git_org" "$cpu_quota" "$memory_quota" "$storage_quota" "$gpu_quota" "$environments" "$modules_json"; then
        successful_tenants+=("$name")
    else
        failed_tenants+=("$name")
    fi
done

# =============================================================================
# SUMMARY REPORT
# =============================================================================
echo
echo "============================================="
log "🎉 TENANT ONBOARDING PROCESS COMPLETE"
echo "============================================="

echo
log "📊 SUMMARY:"
success "  ✅ Successfully onboarded: ${#successful_tenants[@]} tenant(s)"
if [[ ${#successful_tenants[@]} -gt 0 ]]; then
    for tenant in "${successful_tenants[@]}"; do
        echo "    • $tenant"
    done
fi

if [[ ${#failed_tenants[@]} -gt 0 ]]; then
    error "  ❌ Failed to onboard: ${#failed_tenants[@]} tenant(s)"
    for tenant in "${failed_tenants[@]}"; do
        echo "    • $tenant"
    done
fi

echo
log "🔍 VERIFICATION COMMANDS:"
echo "  # List tenant namespaces:"
echo "  kubectl get namespaces -l spanda.ai/managed-by=tenant-factory"
echo
echo "  # List ArgoCD projects:"
echo "  kubectl get appprojects -n argocd"
echo
echo "  # Check resource quotas:"
echo "  kubectl get resourcequotas --all-namespaces"

echo
log "📝 NEXT STEPS:"
echo "1. Update application repositories with tenant information"
echo "2. Regenerate ArgoCD applications:"
echo "   cd scripts && ./generate-argocd-applications-simple.sh"
echo "3. Deploy applications:"
echo "   kubectl apply -f ../applications/"

echo
success "🎊 Tenant onboarding complete! Happy multi-tenant deployments!"
