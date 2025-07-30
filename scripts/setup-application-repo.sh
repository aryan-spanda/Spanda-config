#!/bin/bash

# Spanda Platform - Application Repository Setup Script
# This script sets up an existing application repository with Spanda Platform automation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if we're in an application repository
check_application_repo() {
    if [ ! -f "package.json" ]; then
        print_error "No package.json found. This doesn't appear to be a Node.js application."
        exit 1
    fi
    
    if [ ! -f "spanda-app.yaml" ]; then
        print_error "No spanda-app.yaml found. Please create this configuration file first."
        print_warning "Run: spanda init"
        exit 1
    fi
    
    print_success "Application repository structure validated"
}

# Function to create GitHub Actions workflow
create_github_workflow() {
    print_status "Creating GitHub Actions workflow..."
    
    mkdir -p .github/workflows
    
    cat > .github/workflows/auto-deploy-app.yml << 'EOF'
name: Auto Deploy Application

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

env:
  DOCKER_HUB_USERNAME: ${{ secrets.DOCKER_HUB_USERNAME }}
  DOCKER_HUB_TOKEN: ${{ secrets.DOCKER_HUB_TOKEN }}

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up Node.js
      uses: actions/setup-node@v4
      with:
        node-js-version: '18'

    - name: Parse spanda-app.yaml
      id: parse-config
      run: |
        # Extract config_repo from spanda-app.yaml
        CONFIG_REPO=$(yq eval '.platform.config_repo' spanda-app.yaml)
        APP_NAME=$(yq eval '.app.name' spanda-app.yaml)
        ENVIRONMENT=$(yq eval '.environment // "development"' spanda-app.yaml)
        
        echo "config_repo=$CONFIG_REPO" >> $GITHUB_OUTPUT
        echo "app_name=$APP_NAME" >> $GITHUB_OUTPUT
        echo "environment=$ENVIRONMENT" >> $GITHUB_OUTPUT

    - name: Login to Docker Hub
      uses: docker/login-action@v3
      with:
        username: ${{ env.DOCKER_HUB_USERNAME }}
        password: ${{ env.DOCKER_HUB_TOKEN }}

    - name: Build and push Docker images
      run: |
        APP_NAME="${{ steps.parse-config.outputs.app_name }}"
        COMMIT_SHA=$(echo $GITHUB_SHA | cut -c1-8)
        
        # Check if multi-service application
        if [ -d "backend" ] && [ -d "frontend" ]; then
          echo "Building multi-service application..."
          
          # Build backend
          docker build -f backend/Dockerfile -t $DOCKER_HUB_USERNAME/$APP_NAME-backend:$COMMIT_SHA ./backend
          docker push $DOCKER_HUB_USERNAME/$APP_NAME-backend:$COMMIT_SHA
          
          # Build frontend  
          docker build -f frontend/Dockerfile -t $DOCKER_HUB_USERNAME/$APP_NAME-frontend:$COMMIT_SHA ./frontend
          docker push $DOCKER_HUB_USERNAME/$APP_NAME-frontend:$COMMIT_SHA
          
        else
          echo "Building single-service application..."
          docker build -t $DOCKER_HUB_USERNAME/$APP_NAME:$COMMIT_SHA .
          docker push $DOCKER_HUB_USERNAME/$APP_NAME:$COMMIT_SHA
        fi

    - name: Trigger config repository deployment
      run: |
        echo "🚀 Triggering deployment to config repository..."
        echo "Config Repo: ${{ steps.parse-config.outputs.config_repo }}"
        echo "App Name: ${{ steps.parse-config.outputs.app_name }}"
        echo "Environment: ${{ steps.parse-config.outputs.environment }}"
        echo "Image Tag: $(echo $GITHUB_SHA | cut -c1-8)"
        
        RESPONSE=$(curl -s -w "%{http_code}" -X POST \
          -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}" \
          -H "Accept: application/vnd.github.v3+json" \
          https://api.github.com/repos/${{ steps.parse-config.outputs.config_repo }}/dispatches \
          -d "{
            \"event_type\": \"deploy-application\",
            \"client_payload\": {
              \"app_repo_url\": \"https://github.com/${{ github.repository }}\",
              \"app_name\": \"${{ steps.parse-config.outputs.app_name }}\",
              \"image_tag\": \"$(echo $GITHUB_SHA | cut -c1-8)\",
              \"environment\": \"${{ steps.parse-config.outputs.environment }}\",
              \"commit_sha\": \"${{ github.sha }}\"
            }
          }")
        
        HTTP_CODE="${RESPONSE: -3}"
        RESPONSE_BODY="${RESPONSE%???}"
        
        echo "HTTP Response Code: $HTTP_CODE"
        if [ "$HTTP_CODE" != "204" ]; then
          echo "❌ Failed to trigger config repository deployment"
          echo "Response: $RESPONSE_BODY"
          exit 1
        else
          echo "✅ Successfully triggered config repository deployment"
        fi
EOF

    print_success "GitHub Actions workflow created"
}

# Function to create Dockerfile for single service
create_single_service_dockerfile() {
    print_status "Creating root Dockerfile for single service..."
    
    cat > Dockerfile << 'EOF'
# Multi-stage build for Node.js application

# Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (use npm install if no lock file exists)
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi && npm cache clean --force

# Copy source code
COPY src/ ./src/

# Production stage
FROM node:18-alpine AS production

# Create app user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

# Set working directory
WORKDIR /app

# Copy dependencies from builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy source code with correct ownership
COPY --chown=nodeuser:nodejs src/ ./src/
COPY --chown=nodeuser:nodejs package*.json ./

# Create .env file if .env.example exists
COPY --chown=nodeuser:nodejs .env.example ./.env 2>/dev/null || true

# Upgrade packages for security
RUN apk upgrade --no-cache

# Switch to non-root user
USER nodeuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start the application
CMD ["node", "src/index.js"]
EOF

    print_success "Root Dockerfile created"
}

# Function to create backend Dockerfile
create_backend_dockerfile() {
    if [ ! -d "backend" ]; then
        return
    fi
    
    print_status "Creating backend Dockerfile..."
    
    cat > backend/Dockerfile << 'EOF'
# Multi-stage build for Node.js backend

# Build stage  
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (use npm install if no lock file exists)
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi && npm cache clean --force

# Production stage
FROM node:18-alpine AS production

# Create app user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

# Set working directory  
WORKDIR /app

# Copy dependencies from builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy source code with correct ownership
COPY --chown=nodeuser:nodejs src/ ./src/
COPY --chown=nodeuser:nodejs package*.json ./

# Create .env file if .env.example exists
COPY --chown=nodeuser:nodejs .env.example ./.env 2>/dev/null || true

# Upgrade packages for security
RUN apk upgrade --no-cache

# Switch to non-root user
USER nodeuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start the application
CMD ["node", "src/index.js"]
EOF

    print_success "Backend Dockerfile created"
}

# Function to create frontend Dockerfile
create_frontend_dockerfile() {
    if [ ! -d "frontend" ]; then
        return
    fi
    
    print_status "Creating frontend Dockerfile..."
    
    cat > frontend/Dockerfile << 'EOF'
# Multi-stage build for React application

# Build stage
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --omit=dev

# Copy source code
COPY public/ ./public/
COPY src/ ./src/

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built application
COPY --from=builder /app/build /usr/share/nginx/html

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

    print_success "Frontend Dockerfile created"
}

# Function to create .dockerignore files
create_dockerignore_files() {
    print_status "Creating .dockerignore files..."
    
    # Root .dockerignore
    cat > .dockerignore << 'EOF'
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
coverage/
.nyc_output/
build/
dist/
*.log
.DS_Store
.vscode/
.idea/
*.swp
*.swo
*~
.git/
.github/
README.md
.gitignore
EOF

    # Backend .dockerignore
    if [ -d "backend" ]; then
        cat > backend/.dockerignore << 'EOF'
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
coverage/
.nyc_output/
*.log
.DS_Store
.vscode/
.idea/
*.swp
*.swo
*~
EOF
    fi

    # Frontend .dockerignore
    if [ -d "frontend" ]; then
        cat > frontend/.dockerignore << 'EOF'
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
coverage/
.nyc_output/
build/
dist/
*.log
.DS_Store
.vscode/
.idea/
*.swp
*.swo
*~
EOF
    fi

    print_success ".dockerignore files created"
}

# Function to create nginx config for frontend
create_nginx_config() {
    if [ ! -d "frontend" ]; then
        return
    fi
    
    print_status "Creating nginx configuration for frontend..."
    
    cat > frontend/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Handle client routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF

    print_success "Nginx configuration created"
}

# Function to setup package-lock.json files
setup_package_locks() {
    print_status "Setting up package-lock.json files..."
    
    # Root package-lock.json
    if [ -f "package.json" ] && [ ! -f "package-lock.json" ]; then
        print_status "Generating root package-lock.json..."
        npm install --package-lock-only
    fi
    
    # Backend package-lock.json
    if [ -d "backend" ] && [ -f "backend/package.json" ] && [ ! -f "backend/package-lock.json" ]; then
        print_status "Generating backend package-lock.json..."
        cd backend
        npm install --package-lock-only
        cd ..
    fi
    
    # Frontend package-lock.json
    if [ -d "frontend" ] && [ -f "frontend/package.json" ] && [ ! -f "frontend/package-lock.json" ]; then
        print_status "Generating frontend package-lock.json..."
        cd frontend
        npm install --package-lock-only
        cd ..
    fi
    
    print_success "Package-lock.json files setup complete"
}

# Function to create .gitignore if it doesn't exist
create_gitignore() {
    if [ ! -f ".gitignore" ]; then
        print_status "Creating .gitignore file..."
        
        cat > .gitignore << 'EOF'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Build outputs
build/
dist/
coverage/
.nyc_output/

# Logs
*.log

# Editor files
.DS_Store
.vscode/
.idea/
*.swp
*.swo
*~

# Runtime data
pids
*.pid
*.seed
*.pid.lock
EOF

        print_success ".gitignore file created"
    fi
}

# Main execution
main() {
    echo "🚀 Spanda Platform - Application Repository Setup"
    echo "=================================================="
    echo
    
    # Check if we're in the right place
    check_application_repo
    
    # Create all necessary files
    create_github_workflow
    create_single_service_dockerfile
    create_backend_dockerfile
    create_frontend_dockerfile
    create_dockerignore_files
    create_nginx_config
    create_gitignore
    setup_package_locks
    
    echo
    print_success "✅ Application repository setup complete!"
    echo
    print_status "Next steps:"
    echo "1. Configure GitHub secrets:"
    echo "   - DOCKER_HUB_USERNAME"
    echo "   - DOCKER_HUB_TOKEN"
    echo "   - GITHUB_TOKEN (usually auto-configured)"
    echo
    echo "2. Commit and push your changes:"
    echo "   git add ."
    echo "   git commit -m 'Add Spanda Platform automation'"
    echo "   git push origin main"
    echo
    echo "3. Your application will automatically deploy on the next push! 🎉"
}

# Run the main function
main "$@"
