#!/bin/bash
# Auto-generate Kubernetes manifests for applications
# This script reads the simplified app config and generates all necessary YAML files

set -e

APP_CONFIG_FILE=${1:-"spanda-app.yaml"}
APP_NAME=""
ENVIRONMENT=${2:-"staging"}
IMAGE_TAG=${3:-"latest"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Function to parse YAML using yq
parse_app_config() {
    if [ ! -f "$APP_CONFIG_FILE" ]; then
        error "App configuration file '$APP_CONFIG_FILE' not found!"
    fi

    # Install yq if not available
    if ! command -v yq &> /dev/null; then
        log "Installing yq..."
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
    fi

    APP_NAME=$(yq eval '.app.name' "$APP_CONFIG_FILE")
    APP_TEAM=$(yq eval '.app.team' "$APP_CONFIG_FILE")
    APP_REPO=$(yq eval '.app.repository' "$APP_CONFIG_FILE")
    
    log "Parsed app config: $APP_NAME (team: $APP_TEAM)"
}

# Generate namespace
generate_namespace() {
    local namespace_file="apps/${APP_NAME}/namespace.yaml"
    mkdir -p "apps/${APP_NAME}"
    
    cat > "$namespace_file" << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${APP_NAME}-${ENVIRONMENT}
  labels:
    app: ${APP_NAME}
    environment: ${ENVIRONMENT}
    team: ${APP_TEAM}
    managed-by: spanda-platform
EOF
    log "Generated namespace: $namespace_file"
}

# Generate deployment
generate_deployment() {
    local deployment_file="apps/${APP_NAME}/deployment-${ENVIRONMENT}.yaml"
    local replicas=$(yq eval ".environments.${ENVIRONMENT}.replicas" "$APP_CONFIG_FILE")
    local cpu=$(yq eval ".environments.${ENVIRONMENT}.resources.cpu" "$APP_CONFIG_FILE")
    local memory=$(yq eval ".environments.${ENVIRONMENT}.resources.memory" "$APP_CONFIG_FILE")
    
    # Get number of services
    local service_count=$(yq eval '.services | length' "$APP_CONFIG_FILE")
    
    for i in $(seq 0 $((service_count - 1))); do
        local service_name=$(yq eval ".services[$i].name" "$APP_CONFIG_FILE")
        local service_port=$(yq eval ".services[$i].port" "$APP_CONFIG_FILE")
        local health_check=$(yq eval ".services[$i].healthCheck" "$APP_CONFIG_FILE")
        local service_deployment_file="apps/${APP_NAME}/${service_name}-deployment-${ENVIRONMENT}.yaml"
        
        cat > "$service_deployment_file" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}-${service_name}
  namespace: ${APP_NAME}-${ENVIRONMENT}
  labels:
    app: ${APP_NAME}
    component: ${service_name}
    environment: ${ENVIRONMENT}
    team: ${APP_TEAM}
spec:
  replicas: ${replicas}
  selector:
    matchLabels:
      app: ${APP_NAME}
      component: ${service_name}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
        component: ${service_name}
        environment: ${ENVIRONMENT}
    spec:
      containers:
      - name: ${service_name}
        image: ${APP_REPO}-${service_name}:${IMAGE_TAG}
        resources:
          requests:
            cpu: ${cpu}
            memory: ${memory}
          limits:
            cpu: ${cpu}
            memory: ${memory}
        ports:
        - containerPort: ${service_port}
          name: ${service_name}
        livenessProbe:
          httpGet:
            path: ${health_check}
            port: ${service_port}
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: ${health_check}
            port: ${service_port}
          initialDelaySeconds: 5
          periodSeconds: 5
EOF
        log "Generated deployment: $service_deployment_file"
    done
}

# Generate service
# Generate service
generate_service() {
    # Get number of services
    local service_count=$(yq eval '.services | length' "$APP_CONFIG_FILE")
    
    for i in $(seq 0 $((service_count - 1))); do
        local service_name=$(yq eval ".services[$i].name" "$APP_CONFIG_FILE")
        local service_port=$(yq eval ".services[$i].port" "$APP_CONFIG_FILE")
        local service_file="apps/${APP_NAME}/${service_name}-service-${ENVIRONMENT}.yaml"
        
        cat > "$service_file" << EOF
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}-${service_name}-service
  namespace: ${APP_NAME}-${ENVIRONMENT}
  labels:
    app: ${APP_NAME}
    component: ${service_name}
    environment: ${ENVIRONMENT}
spec:
  selector:
    app: ${APP_NAME}
    component: ${service_name}
  ports:
  - name: ${service_name}
    port: ${service_port}
    targetPort: ${service_port}
    protocol: TCP
  type: ClusterIP
EOF
        log "Generated service: $service_file"
    done
}

# Generate ingress if enabled
generate_ingress() {
    local ingress_enabled=$(yq eval ".environments.${ENVIRONMENT}.ingress.enabled" "$APP_CONFIG_FILE")
    
    if [ "$ingress_enabled" = "true" ]; then
        local ingress_file="apps/${APP_NAME}/ingress-${ENVIRONMENT}.yaml"
        local domain=$(yq eval ".environments.${ENVIRONMENT}.ingress.domain" "$APP_CONFIG_FILE")
        local service_count=$(yq eval '.services | length' "$APP_CONFIG_FILE")
        
        cat > "$ingress_file" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}-ingress
  namespace: ${APP_NAME}-${ENVIRONMENT}
  labels:
    app: ${APP_NAME}
    environment: ${ENVIRONMENT}
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - ${domain}
    secretName: ${APP_NAME}-tls
  rules:
  - host: ${domain}
    http:
      paths:
EOF

        # Generate paths for each service
        for i in $(seq 0 $((service_count - 1))); do
            local service_name=$(yq eval ".services[$i].name" "$APP_CONFIG_FILE")
            local service_path=$(yq eval ".services[$i].path" "$APP_CONFIG_FILE")
            local service_port=$(yq eval ".services[$i].port" "$APP_CONFIG_FILE")
            
            cat >> "$ingress_file" << EOF
      - path: ${service_path}
        pathType: Prefix
        backend:
          service:
            name: ${APP_NAME}-${service_name}-service
            port:
              number: ${service_port}
EOF
        done
        
        log "Generated ingress: $ingress_file"
    fi
}

# Generate ArgoCD application
generate_argocd_application() {
    local argocd_file="landing-zone/applications/${APP_NAME}-${ENVIRONMENT}.yaml"
    mkdir -p "landing-zone/applications"
    
    cat > "$argocd_file" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}-${ENVIRONMENT}
  namespace: argocd
  labels:
    app: ${APP_NAME}
    environment: ${ENVIRONMENT}
    team: ${APP_TEAM}
spec:
  project: default
  source:
    repoURL: https://github.com/aryan-spanda/Spanda-config
    targetRevision: HEAD
    path: apps/${APP_NAME}
  destination:
    server: https://kubernetes.default.svc
    namespace: ${APP_NAME}-${ENVIRONMENT}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
    log "Generated ArgoCD application: $argocd_file"
}

# Generate platform modules configuration
generate_platform_modules() {
    local platform_file="platform/applications/${APP_NAME}-platform.yaml"
    mkdir -p "platform/applications"
    
    cat > "$platform_file" << EOF
# Platform modules configuration for ${APP_NAME}
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${APP_NAME}-platform-config
  namespace: spanda-platform
  labels:
    app: ${APP_NAME}
    component: platform-config
data:
  app-name: "${APP_NAME}"
  environment: "${ENVIRONMENT}"
  team: "${APP_TEAM}"
  
  # Platform module enablement
  networking: "$(yq eval '.platform.networking' "$APP_CONFIG_FILE")"
  monitoring: "$(yq eval '.platform.monitoring' "$APP_CONFIG_FILE")"
  security: "$(yq eval '.platform.security' "$APP_CONFIG_FILE")"
  storage: "$(yq eval '.platform.storage' "$APP_CONFIG_FILE")"
  logging: "$(yq eval '.platform.logging' "$APP_CONFIG_FILE")"
  autoscaling: "$(yq eval '.platform.autoscaling' "$APP_CONFIG_FILE")"
  
  # Application specific configuration
  image-repository: "${APP_REPO}"
  replicas: "$(yq eval ".environments.${ENVIRONMENT}.replicas" "$APP_CONFIG_FILE")"
  namespace: "${APP_NAME}-${ENVIRONMENT}"
EOF
    log "Generated platform modules config: $platform_file"
}

# Main execution
main() {
    log "Starting automatic YAML generation for Spanda platform..."
    log "Environment: $ENVIRONMENT"
    log "Image tag: $IMAGE_TAG"
    
    parse_app_config
    
    log "Generating Kubernetes manifests..."
    generate_namespace
    generate_deployment
    generate_service
    generate_ingress
    generate_argocd_application
    generate_platform_modules
    
    log "✅ Successfully generated all YAML files for ${APP_NAME}!"
    log "Files created in:"
    log "  - apps/${APP_NAME}/"
    log "  - landing-zone/applications/"
    log "  - platform/applications/"
}

# Run main function
main "$@"
