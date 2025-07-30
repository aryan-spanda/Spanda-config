#!/bin/bash

# Test script to manually trigger config repository deployment
# Usage: ./test-config-deployment.sh <app-repo-url> <environment> <image-tag>

set -e

APP_REPO_URL="${1:-https://github.com/aryan-spanda/Test-Application}"
ENVIRONMENT="${2:-development}"
IMAGE_TAG="${3:-latest}"
CONFIG_REPO="${4:-aryan-spanda/Spanda-config}"

echo "🧪 Testing Config Repository Deployment Trigger"
echo "================================================"
echo "App Repository: $APP_REPO_URL"
echo "Environment: $ENVIRONMENT"
echo "Image Tag: $IMAGE_TAG"
echo "Config Repository: $CONFIG_REPO"
echo ""

# Check if GitHub CLI is available
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo "💡 Install it from: https://cli.github.com/"
    echo ""
    echo "Alternative: Use curl directly with GitHub token"
    exit 1
fi

echo "🚀 Triggering repository dispatch..."

gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/$CONFIG_REPO/dispatches \
  -f event_type='deploy-application' \
  -f "client_payload={
    \"app_repo_url\": \"$APP_REPO_URL\",
    \"app_name\": \"test-application\",
    \"image_tag\": \"$IMAGE_TAG\",
    \"environment\": \"$ENVIRONMENT\",
    \"commit_sha\": \"manual-test\"
  }"

echo "✅ Repository dispatch sent successfully!"
echo ""
echo "🔍 Check the workflow run at:"
echo "https://github.com/$CONFIG_REPO/actions"
echo ""
echo "⏱️  The workflow should start within a few seconds..."
