#!/bin/bash

# Script to update Docker image tags in Kustomization files
# Usage: ./update-image.sh <app-name> <environment> <new-tag>
# Example: ./update-image.sh spandaai-frontend production v1.2.3

set -e

APP_NAME="$1"
ENVIRONMENT="$2"
NEW_TAG="$3"

if [ -z "$APP_NAME" ] || [ -z "$ENVIRONMENT" ] || [ -z "$NEW_TAG" ]; then
    echo "Usage: $0 <app-name> <environment> <new-tag>"
    echo "Example: $0 spandaai-frontend production v1.2.3"
    exit 1
fi

KUSTOMIZATION_FILE="apps/${APP_NAME}/overlays/${ENVIRONMENT}/kustomization.yaml"

if [ ! -f "$KUSTOMIZATION_FILE" ]; then
    echo "Error: $KUSTOMIZATION_FILE not found"
    exit 1
fi

echo "Updating $APP_NAME in $ENVIRONMENT to tag $NEW_TAG"

# Use sed to update the newTag in the kustomization.yaml file
sed -i "s/newTag: .*/newTag: $NEW_TAG/" "$KUSTOMIZATION_FILE"

echo "Updated $KUSTOMIZATION_FILE"
echo "Changes:"
git diff "$KUSTOMIZATION_FILE"

echo ""
echo "To apply changes:"
echo "git add $KUSTOMIZATION_FILE"
echo "git commit -m \"Deploy $APP_NAME $NEW_TAG to $ENVIRONMENT\""
echo "git push"
