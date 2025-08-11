#!/bin/bash

# Setup Git credentials for ArgoCD Image Updater
# This enables Git write-back for automatic image updates with commit history

set -euo pipefail

echo "🔧 Setting up Git credentials for ArgoCD Image Updater"
echo "======================================================"

# Check if we're in the right directory
if [[ ! -f "../applications/test-application/argocd/app-dev.yaml" ]]; then
    echo "❌ Please run this script from the config-repo/scripts directory"
    exit 1
fi

echo "📋 For Git write-back, we need Git credentials."
echo "   This will allow ArgoCD Image Updater to commit tag updates to your repository."
echo ""

# Check if secret already exists
if kubectl get secret argocd-image-updater-git -n argocd >/dev/null 2>&1; then
    echo "✅ Git secret already exists. Deleting old one..."
    kubectl delete secret argocd-image-updater-git -n argocd
fi

echo "🔑 Please provide your Git credentials:"
echo ""

# Get GitHub username
read -p "GitHub Username: " GIT_USERNAME

# Get GitHub Personal Access Token
echo "GitHub Personal Access Token (with repo permissions):"
echo "Create one at: https://github.com/settings/tokens"
read -s -p "Token: " GIT_TOKEN
echo ""

# Repository URL
GIT_REPO_URL="https://github.com/aryan-spanda/spanda-config.git"

echo ""
echo "🔑 Creating Git secret for ArgoCD Image Updater..."

# Create the Git credentials secret
kubectl create secret generic argocd-image-updater-git \
    --from-literal=username="$GIT_USERNAME" \
    --from-literal=password="$GIT_TOKEN" \
    --from-literal=url="$GIT_REPO_URL" \
    -n argocd

# Label the secret so ArgoCD Image Updater can find it
kubectl label secret argocd-image-updater-git \
    -n argocd \
    argocd.argoproj.io/secret-type=repository

echo "✅ Git secret created successfully!"
echo ""

echo "🔄 Restarting ArgoCD Image Updater to pick up the new configuration..."
kubectl rollout restart deployment/argocd-image-updater -n argocd

echo "⏳ Waiting for Image Updater to restart..."
kubectl rollout status deployment/argocd-image-updater -n argocd --timeout=60s

echo ""
echo "🎉 Setup complete! ArgoCD Image Updater will now:"
echo "   • Scan for new Docker images matching your tag pattern"
echo "   • Update image tags in Git repository"
echo "   • Commit changes with automatic commit messages"
echo "   • ArgoCD will sync and deploy the changes"
echo ""
echo "📊 Monitor the process with:"
echo "   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f"
echo ""
echo "🔍 Check Git commits at:"
echo "   https://github.com/aryan-spanda/spanda-config/commits/testing"
echo ""
