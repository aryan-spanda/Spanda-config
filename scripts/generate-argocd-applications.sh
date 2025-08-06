#!/bin/bash

# =====================================================================
# Spanda Platform - ArgoCD Application Generator
# =====================================================================
# This script automatically generates ArgoCD application YAML files
# by reading platform-requirements.yml from application repositories.
#
# Usage: ./generate-argocd-applications.sh [repo-path] [repo-path] ...
# Note: Now accepts local paths instead of URLs
#
# Environment Variables:
#   ENABLE_IMAGE_UPDATER=true/false   - Enable/disable ArgoCD Image Updater (default: true)
#   DEFAULT_UPDATE_STRATEGY=strategy  - Image update strategy (default: newest-build)
#   DEFAULT_TAG_PATTERN=pattern       - Tag pattern for updates (default: testing-[commit])
#   DEFAULT_GIT_BRANCH=branch         - Git branch for write-back (default: testing)
#   DEFAULT_POLLING_INTERVAL=interval - How often to check for new images (default: 5m)
#
# Examples:
#   # Generate with Image Updater enabled (default)
#   ./generate-argocd-applications.sh ./local-app-repos/test-app
#
#   # Generate with Image Updater disabled
#   ENABLE_IMAGE_UPDATER=false ./generate-argocd-applications.sh ./local-app-repos/test-app
#
#   # Generate with custom polling interval
#   DEFAULT_POLLING_INTERVAL=2m ./generate-argocd-applications.sh
# =====================================================================

set -e

echo "🚀 Spanda Platform - ArgoCD Application Generator"
echo "================================================="
echo ""

# Check for yq dependency
if ! command -v yq &> /dev/null; then
    echo "❌ Error: yq is required but not installed."
    echo "Install it with:"
    echo "  # Windows (PowerShell):"
    echo "  Invoke-WebRequest -Uri https://github.com/mikefarah/yq/releases/latest/download/yq_windows_amd64.exe -OutFile yq.exe"
    echo "  # Linux:"
    echo "  curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o yq && chmod +x yq"
    echo "  # macOS:"
    echo "  brew install yq"
    exit 1
fi

# Configuration
CONFIG_REPO_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
APPLICATIONS_DIR="$CONFIG_REPO_ROOT/applications"

# ArgoCD Image Updater Configuration
# Set to "true" to enable automatic image updates, "false" to disable
ENABLE_IMAGE_UPDATER="${ENABLE_IMAGE_UPDATER:-true}"

# Default Image Updater settings (only used if ENABLE_IMAGE_UPDATER=true)
# For your CI/CD workflow that builds images with branch-commit pattern
DEFAULT_UPDATE_STRATEGY="${DEFAULT_UPDATE_STRATEGY:-newest-build}"
DEFAULT_TAG_PATTERN="${DEFAULT_TAG_PATTERN:-"regexp:^testing-[0-9a-f]{7,8}\\$"}"
DEFAULT_GIT_BRANCH="${DEFAULT_GIT_BRANCH:-testing}"
DEFAULT_POLLING_INTERVAL="${DEFAULT_POLLING_INTERVAL:-5m}"

# Display configuration after defaults are set
echo "📋 Configuration:"
echo "  • Image Updater: $(if [[ "$ENABLE_IMAGE_UPDATER" == "true" ]]; then echo "✅ ENABLED"; else echo "❌ DISABLED"; fi)"
if [[ "$ENABLE_IMAGE_UPDATER" == "true" ]]; then
    echo "  • Update Strategy: $DEFAULT_UPDATE_STRATEGY"
    echo "  • Tag Pattern: $DEFAULT_TAG_PATTERN"
    echo "  • Git Branch: $DEFAULT_GIT_BRANCH"
    echo "  • Polling Interval: $DEFAULT_POLLING_INTERVAL"
fi
echo ""

# Function to generate ArgoCD applications for a local repository
generate_argocd_for_repo() {
    local repo_path="$1"
    
    # Convert to absolute path if relative
    if [[ ! "$repo_path" = /* ]]; then
        repo_path="$(realpath "$repo_path")"
    fi
    
    echo "📥 Processing local repository: $repo_path"
    
    # Check if directory exists
    if [[ ! -d "$repo_path" ]]; then
        echo "❌ Directory not found: $repo_path"
        return 1
    fi
    
    # Check if platform-requirements.yml exists
    if [[ ! -f "$repo_path/platform-requirements.yml" ]]; then
        echo "⏭️  No platform-requirements.yml found in $repo_path"
        return 0
    fi
    
    echo "✅ Found platform-requirements.yml"
    
    # Extract application details
    APP_NAME=$(yq eval '.app.name' "$repo_path/platform-requirements.yml")
    REPO_URL=$(yq eval '.app.repoURL' "$repo_path/platform-requirements.yml")
    CHART_PATH=$(yq eval '.app.chartPath' "$repo_path/platform-requirements.yml")
    
    # Extract container registry details
    CONTAINER_REGISTRY=$(yq eval '.container.registry // "docker.io"' "$repo_path/platform-requirements.yml")
    CONTAINER_ORG=$(yq eval '.container.organization // "aryanpola"' "$repo_path/platform-requirements.yml")
    CONTAINER_IMAGE=$(yq eval '.container.image // .app.name' "$repo_path/platform-requirements.yml")
    
    # Build full image reference
    if [[ "$CONTAINER_REGISTRY" == "docker.io" ]]; then
        # For Docker Hub, don't include registry prefix
        IMAGE_REFERENCE="$CONTAINER_ORG/$CONTAINER_IMAGE"
    else
        # For other registries, include registry
        IMAGE_REFERENCE="$CONTAINER_REGISTRY/$CONTAINER_ORG/$CONTAINER_IMAGE"
    fi
    
    if [[ "$APP_NAME" == "null" || -z "$APP_NAME" ]]; then
        echo "❌ Error: app.name is required in platform-requirements.yml"
        return 1
    fi
    
    echo "  📦 App Name: $APP_NAME"
    echo "  📂 Chart Path: $CHART_PATH"
    echo "  🐳 Container Image: $IMAGE_REFERENCE"
    
    # Create application directory
    APP_DIR="$APPLICATIONS_DIR/$APP_NAME/argocd"
    mkdir -p "$APP_DIR"
    
    # Read environments array
    ENVIRONMENTS=$(yq eval '.environments[]' "$repo_path/platform-requirements.yml")
    
    if [[ -z "$ENVIRONMENTS" ]]; then
        echo "❌ Error: No environments specified in platform-requirements.yml"
        return 1
    fi
    
    echo "  🌍 Environments: $(echo "$ENVIRONMENTS" | tr '\n' ' ')"
    
    # Generate ArgoCD application for each environment
    echo "$ENVIRONMENTS" | while read -r env; do
        [[ -z "$env" ]] && continue
        
        # Determine namespace based on environment
        local namespace
        case "$env" in
            "dev") namespace="development" ;;
            "staging") namespace="staging" ;;
            "prod"|"production") namespace="production" ;;
            *) namespace="$env" ;;
        esac
        
        # Determine sync policy - more controlled approach
        local sync_policy
        if [[ "$env" == "prod" || "$env" == "production" ]]; then
            sync_policy="manual"
        elif [[ "$env" == "staging" ]]; then
            sync_policy="manual"  # Manual sync for staging too for better control
        else
            sync_policy="auto"    # Only auto-sync for dev environment
        fi
        
        echo "    🔄 Generating ArgoCD app for $env environment..."
        
        # Determine application type from platform-requirements.yml or default
        local app_type
        app_type=$(yq eval '.app.type // "fullstack"' "$repo_path/platform-requirements.yml")
        
        # Determine team from platform-requirements.yml or default
        local team
        team=$(yq eval '.app.team // "platform-team"' "$repo_path/platform-requirements.yml")
        
        # Generate ArgoCD Application YAML
        cat > "$APP_DIR/app-$env.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME-$env
  namespace: argocd
  labels:
    app.kubernetes.io/name: $APP_NAME
    app.kubernetes.io/part-of: spandaai-platform
    team: $team
    environment: $env
    app-type: $app_type
  annotations:
    app.spanda.ai/generated: "true"
    app.spanda.ai/generator: "platform-automation"
    app.spanda.ai/generated-at: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"$(if [[ "$ENABLE_IMAGE_UPDATER" == "true" ]]; then echo "
    # ArgoCD Image Updater configuration - ENABLED
    argocd-image-updater.argoproj.io/image-list: $APP_NAME=$IMAGE_REFERENCE
    argocd-image-updater.argoproj.io/$APP_NAME.update-strategy: $DEFAULT_UPDATE_STRATEGY
    argocd-image-updater.argoproj.io/$APP_NAME.allow-tags: $DEFAULT_TAG_PATTERN
    argocd-image-updater.argoproj.io/$APP_NAME.polling-interval: $DEFAULT_POLLING_INTERVAL
    argocd-image-updater.argoproj.io/write-back-method: git:secret:argocd/argocd-image-updater-git
    argocd-image-updater.argoproj.io/git-branch: $DEFAULT_GIT_BRANCH
    argocd-image-updater.argoproj.io/$APP_NAME.helm.image-name: image.repository
    argocd-image-updater.argoproj.io/$APP_NAME.helm.image-tag: image.tag"; else echo "
    # ArgoCD Image Updater configuration - DISABLED
    # To enable automatic image updates, set ENABLE_IMAGE_UPDATER=true
    # argocd-image-updater.argoproj.io/image-list: $APP_NAME=$IMAGE_REFERENCE
    # argocd-image-updater.argoproj.io/$APP_NAME.update-strategy: $DEFAULT_UPDATE_STRATEGY
    # argocd-image-updater.argoproj.io/$APP_NAME.allow-tags: $DEFAULT_TAG_PATTERN
    # argocd-image-updater.argoproj.io/$APP_NAME.polling-interval: $DEFAULT_POLLING_INTERVAL
    # argocd-image-updater.argoproj.io/write-back-method: git:secret:argocd/argocd-image-updater-git
    # argocd-image-updater.argoproj.io/git-branch: $DEFAULT_GIT_BRANCH
    # argocd-image-updater.argoproj.io/$APP_NAME.helm.image-name: image.repository
    # argocd-image-updater.argoproj.io/$APP_NAME.helm.image-tag: image.tag"; fi)
spec:
  project: spanda-applications
  source:
    repoURL: $REPO_URL
    targetRevision: HEAD  # Use HEAD for latest commit, more stable than branch name
    path: $CHART_PATH
    helm:
      valueFiles:
        - values-$env.yaml
      parameters:
        - name: image.repository
          value: $IMAGE_REFERENCE
        - name: image.tag
          value: latest  # Default tag, should be overridden by CI/CD or manual updates
  destination:
    server: https://kubernetes.default.svc
    namespace: $namespace
  syncPolicy:$(if [[ "$sync_policy" == "auto" ]]; then echo "
    automated:
      selfHeal: true
      prune: true"; fi)
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m$(if [[ "$env" == "prod" || "$env" == "production" ]]; then echo "
  revisionHistoryLimit: 10"; fi)
  info:
    - name: 'Generated By'
      value: 'Platform Automation'
    - name: 'Source Repository'
      value: '$REPO_URL'
    - name: 'Chart Path'
      value: '$CHART_PATH'
    - name: 'Environment'
      value: '$env'
    - name: 'Team'
      value: '$team'
    - name: 'Application Type'
      value: '$app_type'
EOF
        
        echo "    ✅ Generated: $APP_DIR/app-$env.yaml"
    done
    
    # Create a README for the application
    cat > "$APP_DIR/../README.md" << EOF
# $APP_NAME - ArgoCD Applications

This directory contains ArgoCD application definitions for \`$APP_NAME\`.

## 📁 Structure
\`\`\`
applications/$APP_NAME/
├── README.md           # This file
└── argocd/            # ArgoCD application manifests
$(ls -1 "$APP_DIR" | sed 's/^/    ├── /')
\`\`\`

## 🚀 Deployment

### Apply ArgoCD Applications
\`\`\`bash
# Apply all environments
kubectl apply -f applications/$APP_NAME/argocd/

# Apply specific environment
kubectl apply -f applications/$APP_NAME/argocd/app-dev.yaml
\`\`\`

### Sync Applications
\`\`\`bash
# Sync all environments
$(echo "$ENVIRONMENTS" | while read -r env; do [[ -n "$env" ]] && echo "argocd app sync $APP_NAME-$env"; done)

# Sync specific environment
argocd app sync $APP_NAME-dev
\`\`\`

## 📋 Application Details

- **Repository**: $REPO_URL
- **Chart Path**: $CHART_PATH
- **Environments**: $(echo "$ENVIRONMENTS" | tr '\n' ' ')

## 🔄 Auto-Generated

These files were automatically generated from \`platform-requirements.yml\`.
To update, run the sync and generation process:

\`\`\`bash
cd config-repo
./scripts/sync-app-repos.sh
./scripts/generate-argocd-applications.sh ./local-app-repos/$APP_NAME
\`\`\`
EOF
    
    echo "  📝 Generated README: $APP_DIR/../README.md"
    echo "  ✅ ArgoCD applications generated for $APP_NAME"
}

# Main execution
if [[ $# -eq 0 ]]; then
    echo "📋 No local paths specified. Processing all repositories in local-app-repos/..."
    
    LOCAL_REPOS_DIR="$CONFIG_REPO_ROOT/local-app-repos"
    if [[ ! -d "$LOCAL_REPOS_DIR" ]]; then
        echo "❌ Error: $LOCAL_REPOS_DIR not found."
        echo "   Please run ./scripts/sync-app-repos.sh first to sync repositories."
        exit 1
    fi
    
    # Process all directories in local-app-repos
    REPOS=()
    for repo_dir in "$LOCAL_REPOS_DIR"/*; do
        if [[ -d "$repo_dir" ]]; then
            REPOS+=("$repo_dir")
        fi
    done
else
    # Use provided local paths
    REPOS=("$@")
fi

echo "🔍 Processing ${#REPOS[@]} repositories..."
echo ""

# Process each repository
for repo in "${REPOS[@]}"; do
    generate_argocd_for_repo "$repo"
    echo ""
done

echo "🎉 ArgoCD application generation complete!"
echo ""
echo "📁 Generated applications in: $APPLICATIONS_DIR"
echo ""
echo "� Configuration Summary:"
echo "  • Image Updater: $(if [[ "$ENABLE_IMAGE_UPDATER" == "true" ]]; then echo "✅ ENABLED - Automatic image updates active"; else echo "❌ DISABLED - Manual image updates required"; fi)"
echo "  • Sync Policy: Dev=Auto, Staging=Manual, Production=Manual"
echo ""
echo "�🚀 Next steps:"
echo "1. Review the generated ArgoCD applications"
echo "2. Apply them to your cluster:"
echo "   kubectl apply -f $APPLICATIONS_DIR/*/argocd/"
echo "3. Check ArgoCD UI for application status"
echo ""
if [[ "$ENABLE_IMAGE_UPDATER" == "true" ]]; then
    echo "� Image updates are ENABLED - ArgoCD will automatically update images every $DEFAULT_POLLING_INTERVAL"
    echo "   • Strategy: $DEFAULT_UPDATE_STRATEGY"
    echo "   • Tag Pattern: $DEFAULT_TAG_PATTERN"
    echo "   • To disable automatic updates:"
    echo "   ENABLE_IMAGE_UPDATER=false ./scripts/generate-argocd-applications.sh"
else
    echo "💡 Image updates are DISABLED - Manual image updates required."
    echo "   To enable automatic image updates:"
    echo "   ENABLE_IMAGE_UPDATER=true ./scripts/generate-argocd-applications.sh"
fi
echo ""
echo "💡 To add a new application:"
echo "1. Add the repository URL to application-sources.txt"
echo "2. Run: cd config-repo && ./scripts/sync-app-repos.sh"
echo "3. Run: ./scripts/generate-argocd-applications.sh ./local-app-repos/<app-name>"
