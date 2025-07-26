#!/bin/bash

# Script to validate all Kustomization files
# Usage: ./validate-kustomize.sh

set -e

echo "Validating Kustomization files..."

# Find all kustomization.yaml files
find apps/ -name "kustomization.yaml" -type f | while read -r file; do
    echo "Validating: $file"
    
    # Get the directory containing the kustomization.yaml
    dir=$(dirname "$file")
    
    # Run kustomize build to validate
    if kustomize build "$dir" > /dev/null 2>&1; then
        echo "✅ $file is valid"
    else
        echo "❌ $file has errors:"
        kustomize build "$dir"
        exit 1
    fi
done

echo "All Kustomization files are valid! ✅"
