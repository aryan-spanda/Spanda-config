#!/bin/bash
# =====================================================================
# Spanda Platform - Main Orchestration Script
# =====================================================================
# This script automates the complete application onboarding workflow:
# 1. Syncs all application repositories
# 2. Generates ArgoCD application manifests
# 3. Commits changes to the testing branch
# 4. Pushes to the remote repository
#
# USAGE (run from config-repo root):
# ./scripts/main.sh [app-name]
#   app-name: Optional. If provided, only processes this specific app
#             If not provided, processes all apps in local-app-repos
# =====================================================================

set -e

echo "🚀 Spanda Platform - Main Orchestration Script"
echo "=============================================="

# Configuration
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CONFIG_REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TARGET_BRANCH="testing"

# Ensure we're in the config repo root
cd "$CONFIG_REPO_ROOT"

# Get current branch after changing directory
CURRENT_BRANCH=$(git branch --show-current)

echo "📍 Working directory: $PWD"
echo "🌿 Current branch: $CURRENT_BRANCH"
echo "🎯 Target branch: $TARGET_BRANCH"

# Verify we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    echo "   Make sure you're running this from the config-repo directory"
    exit 1
fi

echo ""

# Function to extract app names from recently changed applications
get_changed_apps() {
    # Get list of applications that have changes in the applications directory
    local changed_apps=()
    
    # Check for new or modified files in applications directory
    if git status --porcelain applications/ | grep -q .; then
        # Extract unique app names from changed paths
        while IFS= read -r line; do
            if [[ "$line" =~ applications/([^/]+)/ ]]; then
                local app_name="${BASH_REMATCH[1]}"
                if [[ ! " ${changed_apps[@]} " =~ " ${app_name} " ]]; then
                    changed_apps+=("$app_name")
                fi
            fi
        done <<< "$(git status --porcelain applications/ | cut -c4-)"
    fi
    
    printf '%s\n' "${changed_apps[@]}"
}

# Function to create commit message
create_commit_message() {
    local changed_apps=("$@")
    local commit_msg=""
    
    if [[ ${#changed_apps[@]} -eq 0 ]]; then
        commit_msg="chore: Update ArgoCD applications"
    elif [[ ${#changed_apps[@]} -eq 1 ]]; then
        commit_msg="feat(${changed_apps[0]}): Update ArgoCD manifests for ${changed_apps[0]}"
    else
        commit_msg="feat: Update ArgoCD manifests for multiple applications

Applications updated:
$(printf '- %s\n' "${changed_apps[@]}")"
    fi
    
    echo "$commit_msg"
}

# Step 1: Sync application repositories
echo "🔄 Step 1: Syncing application repositories..."
echo "============================================="
if ! ./scripts/sync-app-repos.sh; then
    echo "❌ Failed to sync application repositories"
    exit 1
fi
echo ""

# Step 2: Generate ArgoCD applications
echo "⚙️  Step 2: Generating ArgoCD applications..."
echo "============================================"
if [[ -n "$1" ]]; then
    echo "📦 Processing specific application: $1"
    if [[ -d "local-app-repos/$1" ]]; then
        if ! ./scripts/generate-argocd-applications.sh "./local-app-repos/$1"; then
            echo "❌ Failed to generate ArgoCD applications for $1"
            exit 1
        fi
    else
        echo "❌ Application directory not found: local-app-repos/$1"
        echo "Available applications:"
        ls -1 local-app-repos/ 2>/dev/null || echo "No applications found"
        exit 1
    fi
else
    echo "📦 Processing all applications..."
    if ! ./scripts/generate-argocd-applications.sh; then
        echo "❌ Failed to generate ArgoCD applications"
        exit 1
    fi
fi
echo ""

# Step 3: Check for changes and commit
echo "📋 Step 3: Checking for changes..."
echo "=================================="

# Check if there are any changes to commit
if ! git status --porcelain applications/ | grep -q .; then
    echo "✅ No changes detected in applications directory"
    echo "🎉 Process completed successfully - no updates needed"
    exit 0
fi

echo "📝 Changes detected in applications directory:"
git status --porcelain applications/
echo ""

# Get list of changed applications
readarray -t changed_apps < <(get_changed_apps)

if [[ ${#changed_apps[@]} -gt 0 ]]; then
    echo "🎯 Applications with changes:"
    printf '  - %s\n' "${changed_apps[@]}"
    echo ""
fi

# Step 4: Switch to testing branch
echo "🌿 Step 4: Switching to testing branch..."
echo "========================================"

# Check if we're already on the target branch
if [[ "$CURRENT_BRANCH" == "$TARGET_BRANCH" ]]; then
    echo "✅ Already on '$TARGET_BRANCH' branch"
    # Try to pull latest changes
    git pull origin "$TARGET_BRANCH" 2>/dev/null || echo "⚠️  Could not pull from remote (this is okay if branch doesn't exist remotely yet)"
else
    # Stash any uncommitted changes first
    if git status --porcelain | grep -q .; then
        echo "💾 Stashing current changes..."
        git stash push -m "main.sh: temporary stash before branch switch"
        STASH_CREATED=true
    else
        STASH_CREATED=false
    fi

    # Switch to testing branch
    if git show-ref --verify --quiet refs/heads/$TARGET_BRANCH; then
        echo "🔄 Switching to existing '$TARGET_BRANCH' branch..."
        git checkout "$TARGET_BRANCH"
        git pull origin "$TARGET_BRANCH" 2>/dev/null || echo "⚠️  Could not pull from remote (this is okay if branch doesn't exist remotely yet)"
    else
        echo "🆕 Creating new '$TARGET_BRANCH' branch..."
        git checkout -b "$TARGET_BRANCH"
    fi

    # Apply stashed changes if we created any
    if [[ "$STASH_CREATED" == "true" ]]; then
        echo "📤 Applying stashed changes..."
        git stash pop
    fi
fi
echo ""

# Step 5: Commit changes
echo "💾 Step 5: Committing changes..."
echo "==============================="

# Add all changes in applications directory
git add applications/

# Create commit message
commit_message=$(create_commit_message "${changed_apps[@]}")

echo "📝 Commit message:"
echo "$commit_message"
echo ""

# Commit the changes
if git commit -m "$commit_message"; then
    echo "✅ Changes committed successfully"
else
    echo "❌ Failed to commit changes"
    exit 1
fi
echo ""

# Step 6: Push to remote
echo "🚀 Step 6: Pushing to remote repository..."
echo "=========================================="

# First check if remote exists
if ! git remote | grep -q origin; then
    echo "❌ No 'origin' remote found"
    echo "💡 Please add a remote first:"
    echo "   git remote add origin https://github.com/aryan-spanda/Spanda-config.git"
    exit 1
fi

# Try to push with upstream setting for new branches
if git push origin "$TARGET_BRANCH" 2>/dev/null; then
    echo "✅ Changes pushed to remote '$TARGET_BRANCH' branch"
elif git push --set-upstream origin "$TARGET_BRANCH" 2>/dev/null; then 
    echo "✅ Changes pushed to remote '$TARGET_BRANCH' branch (new branch created)"
else
    echo "❌ Failed to push to remote repository"
    echo ""
    echo "💡 This could be due to:"
    echo "   1. Authentication issues - make sure you're logged in to GitHub"
    echo "   2. Network connectivity issues"
    echo "   3. Permission issues with the repository"
    echo ""
    echo "💡 Try pushing manually:"
    echo "   git push --set-upstream origin $TARGET_BRANCH"
    echo ""
    echo "💡 Or if the branch already exists:"
    echo "   git push origin $TARGET_BRANCH"
    
    # Don't exit here, let the user know what was accomplished
    echo ""
    echo "⚠️  Note: Your changes have been committed locally to the '$TARGET_BRANCH' branch"
    echo "   You can push them manually when the issue is resolved."
    PUSH_FAILED=true
fi

if [[ "$PUSH_FAILED" != "true" ]]; then
    # Get the remote URL for helpful output
    remote_url=$(git remote get-url origin)
    if [[ "$remote_url" == *"github.com"* ]]; then
        # Extract GitHub repo info
        repo_path=$(echo "$remote_url" | sed -E 's|.*github\.com[/:]([^/]+/[^/]+)(\.git)?.*|\1|')
        echo ""
        echo "🔗 View your changes at:"
        echo "   https://github.com/$repo_path/tree/$TARGET_BRANCH"
        
        if [[ ${#changed_apps[@]} -gt 0 ]]; then
            echo ""
            echo "📦 Applications updated:"
            for app in "${changed_apps[@]}"; do
                echo "   - $app: https://github.com/$repo_path/tree/$TARGET_BRANCH/applications/$app"
            done
        fi
    fi
fi
echo ""

# Step 7: Summary
echo "🎉 Process completed successfully!"
echo "================================="
echo "✅ Application repositories synced"
echo "✅ ArgoCD applications generated"
echo "✅ Changes committed to '$TARGET_BRANCH' branch"

if [[ "$PUSH_FAILED" == "true" ]]; then
    echo "⚠️  Changes committed locally (push failed - see above for resolution)"
else
    echo "✅ Changes pushed to remote repository"
fi

if [[ ${#changed_apps[@]} -gt 0 ]]; then
    echo ""
    echo "📋 Summary of changes:"
    for app in "${changed_apps[@]}"; do
        echo "  🎯 $app: ArgoCD manifests updated"
    done
fi

echo ""
if [[ "$PUSH_FAILED" == "true" ]]; then
    echo "💡 Next steps:"
    echo "1. Resolve the push issue (authentication, network, permissions)"
    echo "2. Push manually: git push --set-upstream origin $TARGET_BRANCH"
    echo "3. Create a pull request to merge into main branch"
    echo "4. Once merged, ArgoCD will detect and deploy the applications"
else
    echo "💡 Next steps:"
    echo "1. Review the changes in the '$TARGET_BRANCH' branch"
    echo "2. Create a pull request to merge into main branch"
    echo "3. Once merged, ArgoCD will detect and deploy the applications"
fi
