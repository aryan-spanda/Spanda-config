#!/bin/bash

# Spanda Platform - General Application Onboarding Script
# This script reads platform-requirements.yml and creates all necessary GitOps files
# Usage: ./onboard-application.sh [path-to-platform-requirements.yml]

set -e

echo "🚀 Spanda Platform - Application Onboarding"
echo "============================================"

# Configuration
PLATFORM_REQUIREMENTS_FILE="${1:-platform-requirements.yml}"
CONFIG_REPO_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"  # Go up two levels from scripts/

# Check if platform-requirements.yml exists
if [[ ! -f "$PLATFORM_REQUIREMENTS_FILE" ]]; then
    echo "❌ Error: platform-requirements.yml not found at: $PLATFORM_REQUIREMENTS_FILE"
    echo ""
    echo "Usage: $0 [path-to-platform-requirements.yml]"
    echo "Example: $0 /path/to/your-app/platform-requirements.yml"
    echo ""
    echo "If no path is provided, it looks for platform-requirements.yml in current directory."
    exit 1
fi

echo "📋 Reading platform requirements from: $PLATFORM_REQUIREMENTS_FILE"
echo "📂 Config repo root: $CONFIG_REPO_ROOT"

# Check for yq
if ! command -v yq &> /dev/null; then
    echo "❌ Error: yq is required but not installed."
    echo "Install it with:"
    echo "  # On Windows (PowerShell):"
    echo "  curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_windows_amd64.exe -o yq.exe"
    echo "  # On Linux:"
    echo "  curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o yq && chmod +x yq"
    echo "  # On macOS:"
    echo "  brew install yq"
    exit 1
fi

# Parse platform requirements
APP_NAME=$(yq eval '.app.name' "$PLATFORM_REQUIREMENTS_FILE")
APP_ENVIRONMENT=$(yq eval '.app.environment' "$PLATFORM_REQUIREMENTS_FILE")
FRONTEND_ENABLED=$(yq eval '.frontend.enabled // false' "$PLATFORM_REQUIREMENTS_FILE")
BACKEND_ENABLED=$(yq eval '.backend.enabled // false' "$PLATFORM_REQUIREMENTS_FILE")
FRONTEND_FRAMEWORK=$(yq eval '.frontend.framework // "react"' "$PLATFORM_REQUIREMENTS_FILE")
BACKEND_FRAMEWORK=$(yq eval '.backend.framework // "express"' "$PLATFORM_REQUIREMENTS_FILE")
FRONTEND_PORT=$(yq eval '.frontend.config.port // 3000' "$PLATFORM_REQUIREMENTS_FILE")
BACKEND_PORT=$(yq eval '.backend.config.port // 5000' "$PLATFORM_REQUIREMENTS_FILE")
BACKEND_HEALTH_CHECK=$(yq eval '.backend.config.health_check // "/health"' "$PLATFORM_REQUIREMENTS_FILE")
FRONTEND_REPLICAS=$(yq eval '.frontend.config.replicas // 2' "$PLATFORM_REQUIREMENTS_FILE")
BACKEND_REPLICAS=$(yq eval '.backend.config.replicas // 2' "$PLATFORM_REQUIREMENTS_FILE")
FRONTEND_DOMAIN=$(yq eval '.frontend.config.domain // ""' "$PLATFORM_REQUIREMENTS_FILE")
DATABASE_TYPE=$(yq eval '.backend.database // "none"' "$PLATFORM_REQUIREMENTS_FILE")

# Validate required fields
if [[ "$APP_NAME" == "null" || -z "$APP_NAME" ]]; then
    echo "❌ Error: app.name is required in platform-requirements.yml"
    exit 1
fi

# Sanitize app name (replace spaces and special chars with hyphens)
APP_NAME=$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')

echo "📦 Creating files for application: $APP_NAME"
echo "   Environment: $APP_ENVIRONMENT"
echo "   Frontend: $FRONTEND_ENABLED ($FRONTEND_FRAMEWORK) - Port: $FRONTEND_PORT"
echo "   Backend: $BACKEND_ENABLED ($BACKEND_FRAMEWORK) - Port: $BACKEND_PORT"
echo "   Database: $DATABASE_TYPE"

# Determine primary port based on what's enabled
if [[ "$FRONTEND_ENABLED" == "true" ]]; then
    PRIMARY_PORT=$FRONTEND_PORT
    HEALTH_CHECK_PATH="/"
elif [[ "$BACKEND_ENABLED" == "true" ]]; then
    PRIMARY_PORT=$BACKEND_PORT
    HEALTH_CHECK_PATH=$BACKEND_HEALTH_CHECK
else
    PRIMARY_PORT=3000
    HEALTH_CHECK_PATH="/health"
fi

# Create directory structure
mkdir -p "$CONFIG_REPO_ROOT/apps/$APP_NAME/templates"
mkdir -p "$CONFIG_REPO_ROOT/landing-zone/applications/$APP_NAME"

echo ""
echo "🎯 1. Creating Helm Chart structure..."

# 1. Create Chart.yaml
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/Chart.yaml" << EOF
apiVersion: v2
name: $APP_NAME
description: A Helm chart for $APP_NAME
type: application
version: 0.1.0
appVersion: "1.0.0"
keywords:
  - spandaai-platform
$(if [[ "$FRONTEND_ENABLED" == "true" ]]; then echo "  - $FRONTEND_FRAMEWORK"; fi)
$(if [[ "$BACKEND_ENABLED" == "true" ]]; then echo "  - $BACKEND_FRAMEWORK"; fi)
$(if [[ "$DATABASE_TYPE" != "none" ]]; then echo "  - $DATABASE_TYPE"; fi)
home: https://github.com/aryan-spanda/$APP_NAME
sources:
  - https://github.com/aryan-spanda/$APP_NAME
maintainers:
  - name: Application Team
    email: team@spandaai.com
EOF

# 2. Create values.yaml (default values)
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/values.yaml" << EOF
# Default values for $APP_NAME
# This is a YAML-formatted file.
# Declare variables to be substituted into your templates.

replicaCount: 2

image:
  repository: ghcr.io/aryan-spanda/$APP_NAME
  pullPolicy: IfNotPresent
  tag: "latest"

imagePullSecrets:
  - name: ghcr-secret

nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  automountServiceAccountToken: false
  annotations: {}
  name: ""

podAnnotations: {}
podLabels: {}

podSecurityContext:
  fsGroup: 2000
  runAsNonRoot: true
  runAsUser: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000

service:
  type: ClusterIP
  port: 80
  targetPort: $FRONTEND_PORT

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
  hosts:
    - host: $APP_NAME.local
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: $APP_NAME-tls
      hosts:
        - $APP_NAME.local

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

livenessProbe:
  httpGet:
    path: $BACKEND_HEALTH_CHECK
    port: $BACKEND_PORT
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: $BACKEND_HEALTH_CHECK
    port: $BACKEND_PORT
  initialDelaySeconds: 5
  periodSeconds: 5

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80

volumes: []
volumeMounts: []

nodeSelector: {}
tolerations: []
affinity: {}

# Application-specific configuration
app:
  frontend:
    enabled: $FRONTEND_ENABLED
    port: $FRONTEND_PORT
  backend:
    enabled: $BACKEND_ENABLED
    port: $BACKEND_PORT
    healthCheck: "$BACKEND_HEALTH_CHECK"
EOF

# 3. Create values-staging.yaml
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/values-staging.yaml" << EOF
# Staging values for $APP_NAME
replicaCount: 1

image:
  repository: ghcr.io/aryan-spanda/$APP_NAME
  tag: "latest"
  pullPolicy: Always

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

ingress:
  hosts:
    - host: $APP_NAME-staging.local
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: $APP_NAME-staging-tls
      hosts:
        - $APP_NAME-staging.local

# Staging-specific settings
autoscaling:
  enabled: false

# Environment variables for staging
env:
  - name: NODE_ENV
    value: "staging"
  - name: API_URL
    value: "https://$APP_NAME-staging.local/api"
EOF

# 4. Create values-prod.yaml
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/values-prod.yaml" << EOF
# Production values for $APP_NAME
replicaCount: 3

image:
  repository: ghcr.io/aryan-spanda/$APP_NAME
  tag: "latest"
  pullPolicy: IfNotPresent

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

ingress:
  hosts:
    - host: $APP_NAME.spandaai.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: $APP_NAME-prod-tls
      hosts:
        - $APP_NAME.spandaai.com

# Production-specific settings
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Environment variables for production
env:
  - name: NODE_ENV
    value: "production"
  - name: API_URL
    value: "https://$APP_NAME.spandaai.com/api"
EOF

echo ""
echo "🎯 2. Creating Helm templates..."

# 5. Create deployment template
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/templates/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "{{APP_NAME}}.fullname" . }}
  labels:
    {{- include "{{APP_NAME}}.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "{{APP_NAME}}.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "{{APP_NAME}}.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "{{APP_NAME}}.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          {{- if .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml .Values.livenessProbe | nindent 12 }}
          {{- end }}
          {{- if .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml .Values.readinessProbe | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- with .Values.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
EOF

# Replace placeholder in deployment template
sed -i "s/{{APP_NAME}}/$APP_NAME/g" "$CONFIG_REPO_ROOT/apps/$APP_NAME/templates/deployment.yaml"

# 6. Create service template
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/templates/service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: {{ include "$APP_NAME.fullname" . }}
  labels:
    {{- include "$APP_NAME.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
      protocol: TCP
      name: http
  selector:
    {{- include "$APP_NAME.selectorLabels" . | nindent 4 }}
EOF

# 7. Create ingress template
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/templates/ingress.yaml" << EOF
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "$APP_NAME.fullname" . }}
  labels:
    {{- include "$APP_NAME.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if and .Values.ingress.className (semverCompare ">=1.18-0" .Capabilities.KubeVersion.GitVersion) }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            {{- if and .pathType (semverCompare ">=1.18-0" \$.Capabilities.KubeVersion.GitVersion) }}
            pathType: {{ .pathType }}
            {{- end }}
            backend:
              {{- if semverCompare ">=1.19-0" \$.Capabilities.KubeVersion.GitVersion }}
              service:
                name: {{ include "$APP_NAME.fullname" \$ }}
                port:
                  number: {{ \$.Values.service.port }}
              {{- else }}
              serviceName: {{ include "$APP_NAME.fullname" \$ }}
              servicePort: {{ \$.Values.service.port }}
              {{- end }}
          {{- end }}
    {{- end }}
{{- end }}
EOF

# 8. Create ServiceAccount template
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/templates/serviceaccount.yaml" << EOF
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "$APP_NAME.serviceAccountName" . }}
  labels:
    {{- include "$APP_NAME.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.serviceAccount.automountServiceAccountToken }}
{{- end }}
EOF

# 9. Create HPA template
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/templates/hpa.yaml" << EOF
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "$APP_NAME.fullname" . }}
  labels:
    {{- include "$APP_NAME.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "$APP_NAME.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
EOF

# 10. Create _helpers.tpl
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/templates/_helpers.tpl" << EOF
{{/*
Expand the name of the chart.
*/}}
{{- define "$APP_NAME.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "$APP_NAME.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- \$name := default .Chart.Name .Values.nameOverride }}
{{- if contains \$name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name \$name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "$APP_NAME.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "$APP_NAME.labels" -}}
helm.sh/chart: {{ include "$APP_NAME.chart" . }}
{{ include "$APP_NAME.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: spandaai-platform
{{- end }}

{{/*
Selector labels
*/}}
{{- define "$APP_NAME.selectorLabels" -}}
app.kubernetes.io/name: {{ include "$APP_NAME.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "$APP_NAME.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "$APP_NAME.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
EOF

echo ""
echo "🎯 3. Creating ArgoCD Application definitions..."

# 11. Create staging ArgoCD Application
cat > "$CONFIG_REPO_ROOT/landing-zone/applications/$APP_NAME/staging.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME-staging
  namespace: argocd
  annotations:
    # ArgoCD Image Updater configuration for staging
    argocd-image-updater.argoproj.io/image-list: $APP_NAME-app=ghcr.io/aryan-spanda/$APP_NAME
    argocd-image-updater.argoproj.io/$APP_NAME-app.update-strategy: latest
    argocd-image-updater.argoproj.io/$APP_NAME-app.allow-tags: regexp:^(latest|[a-f0-9]{8})$
    argocd-image-updater.argoproj.io/$APP_NAME-app.helm.image-name: image.repository
    argocd-image-updater.argoproj.io/$APP_NAME-app.helm.image-tag: image.tag
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/git-branch: main
    argocd.argoproj.io/sync-wave: "5"
  labels:
    app.kubernetes.io/name: $APP_NAME
    app.kubernetes.io/part-of: spandaai-platform
    team: application-team
    environment: staging
spec:
  project: default
  source:
    repoURL: https://github.com/aryan-spanda/config-repo.git
    targetRevision: main
    path: apps/$APP_NAME
    helm:
      valueFiles:
        - values-staging.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: $APP_NAME-staging
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
  revisionHistoryLimit: 5
EOF

# 12. Create production ArgoCD Application
cat > "$CONFIG_REPO_ROOT/landing-zone/applications/$APP_NAME/prod.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME-prod
  namespace: argocd
  annotations:
    # ArgoCD Image Updater configuration
    argocd-image-updater.argoproj.io/image-list: $APP_NAME-app=ghcr.io/aryan-spanda/$APP_NAME
    argocd-image-updater.argoproj.io/$APP_NAME-app.update-strategy: latest
    argocd-image-updater.argoproj.io/$APP_NAME-app.allow-tags: regexp:^(latest|main-.+)$
    argocd-image-updater.argoproj.io/$APP_NAME-app.helm.image-name: image.repository
    argocd-image-updater.argoproj.io/$APP_NAME-app.helm.image-tag: image.tag
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/git-branch: main
  labels:
    app.kubernetes.io/name: $APP_NAME
    app.kubernetes.io/part-of: spandaai-platform
    team: application-team
    environment: production
spec:
  project: default
  source:
    repoURL: https://github.com/aryan-spanda/config-repo.git
    targetRevision: main
    path: apps/$APP_NAME
    helm:
      valueFiles:
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: $APP_NAME
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
  revisionHistoryLimit: 10
EOF

echo ""
echo "🎯 4. Creating GitHub Actions workflow template..."

# 13. Create deploy-gitops.yml template for the application repo
cat > "$CONFIG_REPO_ROOT/scripts/deploy-gitops-template.yml" << EOF
# GitHub Actions Workflow Template for $APP_NAME
# Copy this file to your application repository at: .github/workflows/deploy-gitops.yml

name: Build and Deploy $APP_NAME

on:
  push:
    branches: [ main, develop ]
    paths-ignore:
      - 'README.md'
      - 'docs/**'
      - '.gitignore'
      - 'LICENSE'

permissions:
  contents: read
  packages: write
  security-events: write

jobs:
  call-platform-workflow:
    name: Deploy via Platform Workflow
    uses: aryan-spanda/spandaai-workflows/.github/workflows/build-and-deploy.yml@main
    with:
      app-name: "$APP_NAME"
      dockerfile-path: "Dockerfile"
      docker-context: "."
      helm-chart-path: "apps/$APP_NAME"
      config-repo: "aryan-spanda/config-repo"
      platform-requirements-file: "platform-requirements.yml"
    secrets:
      GHCR_TOKEN: \${{ secrets.GITHUB_TOKEN }}
      CONFIG_REPO_PAT: \${{ secrets.CONFIG_REPO_PAT }}
EOF

echo ""
echo "✅ Setup completed successfully!"
echo ""
echo "📁 Files created in config-repo:"
echo "   ├── apps/$APP_NAME/"
echo "   │   ├── Chart.yaml                     # ← Helm chart definition"
echo "   │   ├── values.yaml                    # ← Default values"
echo "   │   ├── values-staging.yaml            # ← Staging configuration"
echo "   │   ├── values-prod.yaml               # ← Production configuration"
echo "   │   └── templates/                     # ← Kubernetes manifests"
echo "   │       ├── deployment.yaml"
echo "   │       ├── service.yaml"
echo "   │       ├── ingress.yaml"
echo "   │       ├── serviceaccount.yaml"
echo "   │       ├── hpa.yaml"
echo "   │       └── _helpers.tpl"
echo "   └── landing-zone/applications/$APP_NAME/"
echo "       ├── staging.yaml                   # ← ArgoCD Application (staging)"
echo "       └── prod.yaml                      # ← ArgoCD Application (production)"
echo ""
echo "📝 Template created:"
echo "   └── scripts/deploy-gitops-template.yml  # ← Copy to your app repo"
echo ""
echo "🚀 Next Steps:"
echo "   1. Copy scripts/deploy-gitops-template.yml to your application repo:"
echo "      cp \"$CONFIG_REPO_ROOT/scripts/deploy-gitops-template.yml\" \"[YOUR_APP_REPO]/.github/workflows/deploy-gitops.yml\""
echo ""
echo "   2. Commit and push the config-repo changes:"
echo "      cd \"$CONFIG_REPO_ROOT\""
echo "      git add ."
echo "      git commit -m \"Add $APP_NAME application configuration\""
echo "      git push"
echo ""
echo "   3. Your application will be automatically deployed by ArgoCD!"
echo ""
echo "🎉 Application onboarding complete for: $APP_NAME"
echo ""
echo "💡 The app-of-apps.yaml will automatically discover your new applications"
echo "   and deploy them to both staging and production environments."
