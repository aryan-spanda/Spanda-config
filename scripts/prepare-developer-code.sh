#!/bin/bash

# 🛠️ Spanda Platform - Developer Code Preparation Script
# This script helps developers prepare their application code for Spanda Platform
# It does NOT create deployment configuration - that's handled by the platform team

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo "🛠️ Spanda Platform - Developer Code Preparation"
echo "=============================================="
echo "This script helps you prepare your application code for Spanda Platform."
echo "It does NOT create deployment configs - the platform team handles that."
echo ""

# Check if we're in a Node.js project
if [ ! -f "package.json" ]; then
    print_error "No package.json found. This doesn't appear to be a Node.js application."
    exit 1
fi

print_success "Node.js application detected"

# Check required endpoints
print_status "Checking required application endpoints..."

# Check if app has health endpoint
if grep -r "/health" src/ 2>/dev/null | head -1; then
    print_success "Health endpoint found"
else
    print_warning "Health endpoint not found in src/"
    echo "          Your app needs a GET /health endpoint for Kubernetes health checks"
fi

# Check if app has metrics endpoint (optional)
if grep -r "/metrics" src/ 2>/dev/null | head -1; then
    print_success "Metrics endpoint found"
else
    print_warning "Metrics endpoint not found (optional but recommended)"
    echo "          Consider adding GET /metrics for monitoring"
fi

# Create optimized Dockerfile if it doesn't exist
if [ ! -f "Dockerfile" ]; then
    print_status "Creating production-ready Dockerfile..."
    
    cat > Dockerfile << 'EOF'
# Multi-stage build for Node.js application
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi && npm cache clean --force
COPY src/ ./src/

# Production stage
FROM node:18-alpine AS production

# Create app user for security
RUN addgroup -g 1001 -S nodejs && adduser -S nodeuser -u 1001

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nodeuser:nodejs src/ ./src/
COPY --chown=nodeuser:nodejs package*.json ./
COPY --chown=nodeuser:nodejs .env.example ./.env 2>/dev/null || true

# Security updates
RUN apk upgrade --no-cache

USER nodeuser
EXPOSE 3000

# Health check for Kubernetes
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
EOF

    print_success "Dockerfile created"
else
    print_warning "Dockerfile already exists - not overwriting"
fi

# Create .dockerignore if it doesn't exist
if [ ! -f ".dockerignore" ]; then
    print_status "Creating .dockerignore..."
    
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

    print_success ".dockerignore created"
else
    print_warning ".dockerignore already exists - not overwriting"
fi

# Check for multi-service structure
if [ -d "backend" ] && [ -d "frontend" ]; then
    print_status "Multi-service application detected (backend + frontend)"
    
    # Create backend Dockerfile if needed
    if [ ! -f "backend/Dockerfile" ]; then
        print_status "Creating backend Dockerfile..."
        mkdir -p backend
        cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi && npm cache clean --force

FROM node:18-alpine AS production
RUN addgroup -g 1001 -S nodejs && adduser -S nodeuser -u 1001
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nodeuser:nodejs src/ ./src/
COPY --chown=nodeuser:nodejs package*.json ./
COPY --chown=nodeuser:nodejs .env.example ./.env 2>/dev/null || true
RUN apk upgrade --no-cache
USER nodeuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
CMD ["node", "src/index.js"]
EOF
        print_success "Backend Dockerfile created"
    fi
    
    # Create frontend Dockerfile if needed
    if [ ! -f "frontend/Dockerfile" ]; then
        print_status "Creating frontend Dockerfile..."
        mkdir -p frontend
        cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY public/ ./public/
COPY src/ ./src/
RUN npm run build

FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
        print_success "Frontend Dockerfile created"
    fi
    
    # Create nginx config for frontend
    if [ ! -f "frontend/nginx.conf" ]; then
        print_status "Creating nginx configuration..."
        cat > frontend/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

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
}
EOF
        print_success "Nginx configuration created"
    fi
fi

# Generate example application info (for platform team reference)
APP_NAME=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

cat > application-info.md << EOF
# Application Information for Spanda Platform Team

## Application Details
- **Name**: $APP_NAME
- **Repository**: $(git remote get-url origin 2>/dev/null || echo "Please provide your repository URL")
- **Structure**: $([ -d "backend" ] && [ -d "frontend" ] && echo "Multi-service (backend + frontend)" || echo "Single service")
- **Main Port**: 3000 (backend), 80 (frontend)

## Endpoints Required
- ✅ Health check: GET /health
- 📊 Metrics (optional): GET /metrics

## Platform Team Actions Needed
1. Create ArgoCD application in Spanda-config repository
2. Generate Helm chart with appropriate values
3. Set up monitoring and ingress configuration
4. Configure CI/CD pipeline integration

## Developer Contact
- **Email**: [Your email here]
- **Team**: [Your team name]
- **Environment Needed**: staging/production

---
**Generated by**: Spanda Platform Developer Preparation Script
**Date**: $(date)
EOF

echo ""
print_success "✅ Code preparation complete!"
echo ""
echo "📋 Summary of what was created:"
echo "  • Dockerfile (production-ready)"
echo "  • .dockerignore (optimized)"
if [ -d "backend" ] && [ -d "frontend" ]; then
    echo "  • backend/Dockerfile"
    echo "  • frontend/Dockerfile + nginx.conf"
fi
echo "  • application-info.md (for platform team)"
echo ""
echo "🚀 Next Steps:"
echo "1. Test your Docker build locally:"
echo "   docker build -t $APP_NAME:test ."
echo ""
echo "2. Ensure your app has required endpoints:"
echo "   • GET /health - returns 200 OK when app is healthy"
echo "   • GET /metrics - Prometheus metrics (optional)"
echo ""
echo "3. Contact the Spanda Platform team:"
echo "   • Send them the application-info.md file"
echo "   • They will onboard your app to the platform"
echo ""
echo "⚠️  Important: Do NOT create deployment configs yourself!"
echo "   The platform team handles all Kubernetes/Helm configuration"
echo "   This maintains security and consistency across the platform"
echo ""
print_success "Ready for platform onboarding! 🎉"
