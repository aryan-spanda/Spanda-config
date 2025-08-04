#!/bin/bash
# =====================================================================
# Spanda Platform - Application Repository Synchronizer
# =====================================================================
# This script clones or updates local copies of all application repos
# listed in 'application-sources.txt'. The local clones are stored
# in a central folder for the platform team to use.
#
# USAGE (run from the config repo root):
# cd config-repo && ./scripts/sync-app-repos.sh
# =====================================================================

set -e

echo "🔄 Starting Application Repository Sync..."
echo "========================================="

# --- Configuration ---
CONFIG_REPO_ROOT=$(pwd)
# All app repos will be cloned into a folder named 'local-app-repos' within config-repo
APPS_CLONE_DIR="$CONFIG_REPO_ROOT/local-app-repos"
# The master list of repositories to sync
SOURCES_FILE="$CONFIG_REPO_ROOT/application-sources.txt"

# --- Pre-flight Checks ---
if [[ ! -f "$SOURCES_FILE" ]]; then
    echo "❌ Error: Master list not found at '$SOURCES_FILE'"
    echo "   Please create this file and add application repository URLs to it."
    exit 1
fi

mkdir -p "$APPS_CLONE_DIR"
echo "📂 Syncing repositories into: $APPS_CLONE_DIR"
echo ""

# --- Main Logic ---
# Read each repository URL from the sources file
while IFS= read -r repo_url; do
    # Skip empty lines and comments
    [[ -z "$repo_url" || "$repo_url" =~ ^[[:space:]]*# ]] && continue
    
    # Trim whitespace
    repo_url=$(echo "$repo_url" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$repo_url" ]] && continue

    # Extract the repository name and branch from the URL
    if [[ "$repo_url" == *"/tree/"* ]]; then
        # Handle GitHub tree URLs (e.g., https://github.com/user/repo/tree/branch)
        base_url=$(echo "$repo_url" | sed 's|/tree/.*||')
        branch=$(echo "$repo_url" | sed 's|.*/tree/||')
        repo_url="$base_url.git"
    else
        branch="main"
    fi
    
    repo_name=$(basename "$repo_url" .git)
    clone_path="$APPS_CLONE_DIR/$repo_name"

    echo "--- Processing: $repo_name (branch: $branch) ---"

    # If the directory already exists, pull the latest changes
    if [ -d "$clone_path" ]; then
        echo "   Directory exists. Fetching latest changes..."
        cd "$clone_path"
        git fetch origin
        git checkout "$branch" 2>/dev/null || git checkout -b "$branch" "origin/$branch"
        git pull origin "$branch"
        cd "$CONFIG_REPO_ROOT"
    # Otherwise, clone the repository
    else
        echo "   Cloning new repository..."
        git clone "$repo_url" "$clone_path" --depth 1 --branch "$branch"
    fi
    echo "   ✅ Synced successfully."
    echo ""
done < "$SOURCES_FILE"

echo "🎉 Repository sync complete!"
