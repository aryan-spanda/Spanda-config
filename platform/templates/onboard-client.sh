#!/bin/bash

# Spanda Platform Client Onboarding Script
# This script sets up a new client application with minimal configuration

set -e

echo "🚀 Spanda Platform - Client Onboarding"
echo "======================================"
echo "We'll help you set up your application in 2 minutes!"
echo ""

# Get client inputs
read -p "📝 Enter your application name (e.g., my-awesome-app): " APP_NAME
read -p "🐳 Enter your Docker Hub username/organization: " DOCKER_ORG
read -p "🌐 Enter your application port (default: 3000): " APP_PORT
APP_PORT=${APP_PORT:-3000}

# Validate inputs
if [[ -z "$APP_NAME" || -z "$DOCKER_ORG" ]]; then
    echo "❌ Error: Application name and Docker org are required"
    exit 1
fi

echo ""
echo "📦 Creating your application configuration..."

# Create only the files the client needs
mkdir -p .github/workflows

# 1. Platform modules configuration (the ONLY platform file clients need)
curl -s https://raw.githubusercontent.com/aryan-spanda/spanda-config/main/platform/templates/client-platform-modules-template.yaml \
    | sed "s/my-awesome-app/${APP_NAME}/g" \
    | sed "s/myorg\\/my-awesome-app/${DOCKER_ORG}\/${APP_NAME}/g" \
    | sed "s/3000/${APP_PORT}/g" \
    > platform-modules.yaml

# 2. GitHub Actions workflow (simple build and push)
curl -s https://raw.githubusercontent.com/aryan-spanda/spanda-config/main/platform/templates/github-actions-template.yml \
    > .github/workflows/deploy.yml

# 3. Create sample Dockerfile if it doesn't exist
if [[ ! -f "Dockerfile" ]]; then
    cat > Dockerfile << EOF
# Sample Dockerfile - customize for your application
FROM node:18-alpine
WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm install

# Copy application code
COPY . .

# Expose your application port
EXPOSE ${APP_PORT}

# Start your application
CMD ["npm", "start"]
EOF
fi

# 4. Create .gitignore if it doesn't exist
if [[ ! -f ".gitignore" ]]; then
    cat > .gitignore << EOF
node_modules/
npm-debug.log*
.env
.env.local
dist/
build/
*.log
EOF
fi

echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "� Files created:"
echo "   ├── platform-modules.yaml     # ← Platform configuration (edit this)"
echo "   ├── .github/workflows/deploy.yml  # ← CI/CD pipeline"
echo "   ├── Dockerfile               # ← Container definition (customize)"
echo "   └── .gitignore              # ← Git ignore rules"
echo ""
echo "🔑 Required GitHub Secrets (add these to your repo settings):"
echo "   • DOCKERHUB_USERNAME: ${DOCKER_ORG}"
echo "   • DOCKERHUB_TOKEN: <your-docker-hub-access-token>"
echo "   • GITOPS_PAT: <github-pat-for-deployment>"
echo ""
echo "📝 What to do next:"
echo "   1. Customize your Dockerfile for your application"
echo "   2. Edit platform-modules.yaml to select infrastructure modules"
echo "   3. Add the GitHub secrets above to your repository"
echo "   4. Push your code: git add . && git commit -m 'Initial setup' && git push"
echo ""
echo "🎉 That's it! Your app will be deployed automatically with platform infrastructure!"
echo ""
echo "💡 Need help? Check the platform documentation or contact the platform team."
