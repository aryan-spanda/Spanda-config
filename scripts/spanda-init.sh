#!/bin/bash

# Spanda Platform - Application Initialization Script
# Creates the minimal spanda-app.yaml configuration file

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[INPUT]${NC} $1"
}

# Function to create spanda-app.yaml with user input
create_spanda_config() {
    echo "🚀 Spanda Platform - Application Configuration"
    echo "=============================================="
    echo
    
    # Get application name
    print_warning "Enter your application name (lowercase, no spaces):"
    read -r app_name
    
    # Get description
    print_warning "Enter application description:"
    read -r app_description
    
    # Get environment
    print_warning "Enter environment (development/staging/production) [default: development]:"
    read -r environment
    environment=${environment:-development}
    
    # Get config repository
    print_warning "Enter config repository (owner/repo-name) [default: aryan-spanda/Spanda-config]:"
    read -r config_repo
    config_repo=${config_repo:-aryan-spanda/Spanda-config}
    
    # Detect if multi-service
    multi_service="false"
    if [ -d "backend" ] && [ -d "frontend" ]; then
        multi_service="true"
        print_status "Detected multi-service application (backend + frontend)"
    else
        print_status "Detected single-service application"
    fi
    
    # Create spanda-app.yaml
    print_status "Creating spanda-app.yaml configuration..."
    
    if [ "$multi_service" = "true" ]; then
        cat > spanda-app.yaml << EOF
# Spanda Platform Application Configuration
apiVersion: spanda.io/v1
kind: Application

# Application metadata
app:
  name: $app_name
  description: "$app_description"
  version: "1.0.0"

# Environment configuration  
environment: $environment

# Platform configuration
platform:
  config_repo: $config_repo
  auto_deploy: true
  multi_service: true

# Services configuration
services:
  backend:
    type: "nodejs"
    port: 3000
    dockerfile: "backend/Dockerfile"
    healthcheck: "/health"
    resources:
      cpu: "500m"
      memory: "512Mi"
    replicas: 2
    
  frontend:
    type: "nginx"
    port: 80
    dockerfile: "frontend/Dockerfile" 
    resources:
      cpu: "100m"
      memory: "128Mi"
    replicas: 2

# Platform modules to use
modules:
  - monitoring
  - logging
  - ingress

# Ingress configuration
ingress:
  enabled: true
  domain: "$app_name.dev.spanda.io"
  tls: true
  
# Database configuration (if needed)
# database:
#   type: "postgresql"
#   version: "13"
#   storage: "10Gi"

# Environment variables (non-sensitive)
env:
  NODE_ENV: $environment
  API_URL: "https://$app_name-api.dev.spanda.io"
  
# Secrets (will be injected securely)
# secrets:
#   - DATABASE_URL
#   - JWT_SECRET
#   - API_KEY
EOF
    else
        cat > spanda-app.yaml << EOF
# Spanda Platform Application Configuration
apiVersion: spanda.io/v1
kind: Application

# Application metadata
app:
  name: $app_name
  description: "$app_description"
  version: "1.0.0"

# Environment configuration
environment: $environment

# Platform configuration
platform:
  config_repo: $config_repo
  auto_deploy: true
  multi_service: false

# Service configuration
service:
  type: "nodejs"
  port: 3000
  dockerfile: "Dockerfile"
  healthcheck: "/health"
  resources:
    cpu: "500m"
    memory: "512Mi"
  replicas: 2

# Platform modules to use
modules:
  - monitoring
  - logging
  - ingress

# Ingress configuration
ingress:
  enabled: true
  domain: "$app_name.dev.spanda.io"
  tls: true

# Environment variables (non-sensitive)
env:
  NODE_ENV: $environment
  
# Secrets (will be injected securely)
# secrets:
#   - DATABASE_URL
#   - JWT_SECRET
EOF
    fi
    
    print_success "spanda-app.yaml created successfully!"
    echo
    print_status "Next steps:"
    echo "1. Review and customize spanda-app.yaml"
    echo "2. Run: bash <(curl -s https://platform.spanda.io/setup.sh)"
    echo "3. Push your code to GitHub"
    echo "4. Watch your application deploy automatically! 🎉"
}

# Main execution
create_spanda_config
