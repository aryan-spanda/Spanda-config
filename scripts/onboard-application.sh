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

replicaCount: $(if [[ "$FRONTEND_ENABLED" == "true" ]]; then echo $FRONTEND_REPLICAS; else echo $BACKEND_REPLICAS; fi)

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
  targetPort: $PRIMARY_PORT

$(if [[ "$FRONTEND_ENABLED" == "true" || "$BACKEND_ENABLED" == "true" ]]; then
cat << INGRESS_EOF
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
$(if [[ "$BACKEND_ENABLED" == "true" && "$FRONTEND_ENABLED" == "true" ]]; then
echo "    nginx.ingress.kubernetes.io/rewrite-target: /\$2"
echo "    nginx.ingress.kubernetes.io/cors-allow-origin: \"*\""
echo "    nginx.ingress.kubernetes.io/cors-allow-methods: \"GET, POST, PUT, DELETE, OPTIONS\""
fi)
  hosts:
    - host: $(if [[ -n "$FRONTEND_DOMAIN" && "$FRONTEND_DOMAIN" != "null" ]]; then echo "$FRONTEND_DOMAIN"; else echo "$APP_NAME.local"; fi)
      paths:
        - path: $(if [[ "$BACKEND_ENABLED" == "true" && "$FRONTEND_ENABLED" == "true" ]]; then echo "/api(/|\\$)(.*)"; else echo "/"; fi)
          pathType: $(if [[ "$BACKEND_ENABLED" == "true" && "$FRONTEND_ENABLED" == "true" ]]; then echo "Prefix"; else echo "Prefix"; fi)
  tls:
    - secretName: $APP_NAME-tls
      hosts:
        - $(if [[ -n "$FRONTEND_DOMAIN" && "$FRONTEND_DOMAIN" != "null" ]]; then echo "$FRONTEND_DOMAIN"; else echo "$APP_NAME.local"; fi)
INGRESS_EOF
else
echo "ingress:"
echo "  enabled: false"
fi)

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

$(if [[ "$BACKEND_ENABLED" == "true" ]]; then
cat << HEALTH_EOF
livenessProbe:
  httpGet:
    path: $HEALTH_CHECK_PATH
    port: $PRIMARY_PORT
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: $HEALTH_CHECK_PATH
    port: $PRIMARY_PORT
  initialDelaySeconds: 5
  periodSeconds: 5
HEALTH_EOF
fi)

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
$(if [[ "$FRONTEND_ENABLED" == "true" ]]; then
cat << FRONTEND_CONFIG_EOF
  frontend:
    enabled: true
    framework: "$FRONTEND_FRAMEWORK"
    port: $FRONTEND_PORT
    replicas: $FRONTEND_REPLICAS
FRONTEND_CONFIG_EOF
fi)
$(if [[ "$BACKEND_ENABLED" == "true" ]]; then
cat << BACKEND_CONFIG_EOF
  backend:
    enabled: true
    framework: "$BACKEND_FRAMEWORK"
    port: $BACKEND_PORT
    replicas: $BACKEND_REPLICAS
    healthCheck: "$BACKEND_HEALTH_CHECK"
    database: "$DATABASE_TYPE"
BACKEND_CONFIG_EOF
fi)
EOF

echo ""
echo "🎯 2. Creating values files for environments..."

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

$(if [[ "$FRONTEND_ENABLED" == "true" || "$BACKEND_ENABLED" == "true" ]]; then
cat << STAGING_INGRESS_EOF
ingress:
  hosts:
    - host: $APP_NAME-staging.local
      paths:
        - path: $(if [[ "$BACKEND_ENABLED" == "true" && "$FRONTEND_ENABLED" == "true" ]]; then echo "/api(/|\\$)(.*)"; else echo "/"; fi)
          pathType: Prefix
  tls:
    - secretName: $APP_NAME-staging-tls
      hosts:
        - $APP_NAME-staging.local
STAGING_INGRESS_EOF
fi)

# Staging-specific settings
autoscaling:
  enabled: false

# Environment variables for staging
env:
  - name: NODE_ENV
    value: "staging"
$(if [[ "$FRONTEND_ENABLED" == "true" ]]; then
echo "  - name: REACT_APP_API_URL"
echo "    value: \"https://$APP_NAME-staging.local/api\""
fi)
$(if [[ "$BACKEND_ENABLED" == "true" && "$DATABASE_TYPE" != "none" ]]; then
echo "  - name: DATABASE_URL"
echo "    valueFrom:"
echo "      secretKeyRef:"
echo "        name: $APP_NAME-secrets"
echo "        key: database-url-staging"
fi)
EOF

# 4. Create values-prod.yaml
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/values-prod.yaml" << EOF
# Production values for $APP_NAME
replicaCount: $(if [[ "$FRONTEND_ENABLED" == "true" ]]; then echo $FRONTEND_REPLICAS; else echo $BACKEND_REPLICAS; fi)

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

$(if [[ "$FRONTEND_ENABLED" == "true" || "$BACKEND_ENABLED" == "true" ]]; then
cat << PROD_INGRESS_EOF
ingress:
  hosts:
    - host: $(if [[ -n "$FRONTEND_DOMAIN" && "$FRONTEND_DOMAIN" != "null" ]]; then echo "$FRONTEND_DOMAIN"; else echo "$APP_NAME.spandaai.com"; fi)
      paths:
        - path: $(if [[ "$BACKEND_ENABLED" == "true" && "$FRONTEND_ENABLED" == "true" ]]; then echo "/api(/|\\$)(.*)"; else echo "/"; fi)
          pathType: Prefix
  tls:
    - secretName: $APP_NAME-prod-tls
      hosts:
        - $(if [[ -n "$FRONTEND_DOMAIN" && "$FRONTEND_DOMAIN" != "null" ]]; then echo "$FRONTEND_DOMAIN"; else echo "$APP_NAME.spandaai.com"; fi)
PROD_INGRESS_EOF
fi)

# Production-specific settings
autoscaling:
  enabled: true
  minReplicas: $(if [[ "$FRONTEND_ENABLED" == "true" ]]; then echo $FRONTEND_REPLICAS; else echo $BACKEND_REPLICAS; fi)
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Environment variables for production
env:
  - name: NODE_ENV
    value: "production"
$(if [[ "$FRONTEND_ENABLED" == "true" ]]; then
echo "  - name: REACT_APP_API_URL"
echo "    value: \"https://$(if [[ -n "$FRONTEND_DOMAIN" && "$FRONTEND_DOMAIN" != "null" ]]; then echo "$FRONTEND_DOMAIN"; else echo "$APP_NAME.spandaai.com"; fi)/api\""
fi)
$(if [[ "$BACKEND_ENABLED" == "true" && "$DATABASE_TYPE" != "none" ]]; then
echo "  - name: DATABASE_URL"
echo "    valueFrom:"
echo "      secretKeyRef:"
echo "        name: $APP_NAME-secrets"
echo "        key: database-url-prod"
fi)
EOF

echo ""
echo "🎯 3. Creating Helm templates..."

# 5. Create deployment template
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/templates/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "$APP_NAME.fullname" . }}
  labels:
    {{- include "$APP_NAME.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "$APP_NAME.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "$APP_NAME.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "$APP_NAME.serviceAccountName" . }}
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

# 10. Create ConfigMap template (if database or complex config needed)
if [[ "$DATABASE_TYPE" != "none" || "$BACKEND_ENABLED" == "true" ]]; then
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/templates/configmap.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "$APP_NAME.fullname" . }}-config
  labels:
    {{- include "$APP_NAME.labels" . | nindent 4 }}
data:
$(if [[ "$DATABASE_TYPE" != "none" ]]; then
echo "  database-type: \"$DATABASE_TYPE\""
fi)
$(if [[ "$BACKEND_ENABLED" == "true" ]]; then
echo "  backend-framework: \"$BACKEND_FRAMEWORK\""
echo "  health-check-path: \"$BACKEND_HEALTH_CHECK\""
fi)
$(if [[ "$FRONTEND_ENABLED" == "true" ]]; then
echo "  frontend-framework: \"$FRONTEND_FRAMEWORK\""
fi)
  app-name: "$APP_NAME"
  environment: "{{ .Values.app.environment | default \"production\" }}"
EOF
fi

# 11. Create _helpers.tpl
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
echo "🎯 4. Creating ArgoCD Application definitions..."

# 12. Create staging ArgoCD Application
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
    $(if [[ "$FRONTEND_ENABLED" == "true" ]]; then echo "app-type: frontend"; fi)
    $(if [[ "$BACKEND_ENABLED" == "true" ]]; then echo "app-type: backend"; fi)
    $(if [[ "$DATABASE_TYPE" != "none" ]]; then echo "database: $DATABASE_TYPE"; fi)
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

# 13. Create production ArgoCD Application
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
    $(if [[ "$FRONTEND_ENABLED" == "true" ]]; then echo "app-type: frontend"; fi)
    $(if [[ "$BACKEND_ENABLED" == "true" ]]; then echo "app-type: backend"; fi)
    $(if [[ "$DATABASE_TYPE" != "none" ]]; then echo "database: $DATABASE_TYPE"; fi)
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
echo "🎯 5. Creating application-specific files..."

# 14. Copy the platform-requirements.yml to the app directory for reference
cp "$PLATFORM_REQUIREMENTS_FILE" "$CONFIG_REPO_ROOT/apps/$APP_NAME/platform-requirements.yml"

# 15. Create a copy of this script for the specific application
cp "$0" "$CONFIG_REPO_ROOT/apps/$APP_NAME/onboard-$APP_NAME.sh"
chmod +x "$CONFIG_REPO_ROOT/apps/$APP_NAME/onboard-$APP_NAME.sh"

echo ""
echo "🎯 6. Creating GitHub Actions workflow template..."

# 16. Create deploy-gitops.yml template for the application repo
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/deploy-gitops-template.yml" << EOF
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
      - '*.md'

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
      # Application-specific settings
      frontend-enabled: "$FRONTEND_ENABLED"
      backend-enabled: "$BACKEND_ENABLED"
      primary-port: "$PRIMARY_PORT"
      health-check-path: "$HEALTH_CHECK_PATH"
    secrets:
      GHCR_TOKEN: \${{ secrets.GITHUB_TOKEN }}
      CONFIG_REPO_PAT: \${{ secrets.CONFIG_REPO_PAT }}
EOF

# 17. Create README for the application
cat > "$CONFIG_REPO_ROOT/apps/$APP_NAME/README.md" << EOF
# $APP_NAME

Generated by Spanda Platform Onboarding Script

## Application Configuration

- **Name**: $APP_NAME
- **Environment**: $APP_ENVIRONMENT
- **Frontend**: $FRONTEND_ENABLED ($FRONTEND_FRAMEWORK)
- **Backend**: $BACKEND_ENABLED ($BACKEND_FRAMEWORK)
- **Database**: $DATABASE_TYPE
- **Primary Port**: $PRIMARY_PORT

## Files Generated

### Helm Chart
- \`Chart.yaml\` - Helm chart definition
- \`values.yaml\` - Default values
- \`values-staging.yaml\` - Staging environment values
- \`values-prod.yaml\` - Production environment values
- \`templates/\` - Kubernetes manifest templates

### ArgoCD Applications
- \`../../landing-zone/applications/$APP_NAME/staging.yaml\` - Staging deployment
- \`../../landing-zone/applications/$APP_NAME/prod.yaml\` - Production deployment

### Templates for Application Repository
- \`deploy-gitops-template.yml\` - Copy to your app repo as \`.github/workflows/deploy-gitops.yml\`

## Usage

1. Copy \`deploy-gitops-template.yml\` to your application repository
2. Ensure your application repository has a \`Dockerfile\`
3. Commit and push changes to trigger deployment
4. Monitor deployment in ArgoCD

## Customization

Edit the values files to customize:
- Resource limits and requests
- Replica counts
- Ingress configuration
- Environment variables
- Health check settings

## Generated from Platform Requirements

This configuration was generated from:
\`\`\`yaml
$(cat "$PLATFORM_REQUIREMENTS_FILE")
\`\`\`
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
echo "   │   ├── platform-requirements.yml     # ← Original requirements (reference)"
echo "   │   ├── onboard-$APP_NAME.sh          # ← App-specific onboarding script"
echo "   │   ├── deploy-gitops-template.yml    # ← Copy to your app repo"
echo "   │   ├── README.md                     # ← Documentation"
echo "   │   └── templates/                     # ← Kubernetes manifests"
echo "   │       ├── deployment.yaml"
echo "   │       ├── service.yaml"
echo "   │       ├── ingress.yaml"
echo "   │       ├── serviceaccount.yaml"
echo "   │       ├── hpa.yaml"
$(if [[ "$DATABASE_TYPE" != "none" || "$BACKEND_ENABLED" == "true" ]]; then echo "   │       ├── configmap.yaml"; fi)
echo "   │       └── _helpers.tpl"
echo "   └── landing-zone/applications/$APP_NAME/"
echo "       ├── staging.yaml                   # ← ArgoCD Application (staging)"
echo "       └── prod.yaml                      # ← ArgoCD Application (production)"
echo ""
echo "🚀 Next Steps:"
echo "   1. Copy the GitHub Actions workflow to your application repository:"
echo "      cp \"$CONFIG_REPO_ROOT/apps/$APP_NAME/deploy-gitops-template.yml\" \"[YOUR_APP_REPO]/.github/workflows/deploy-gitops.yml\""
echo ""
echo "   2. Ensure your application repository has:"
echo "      - Dockerfile (for containerization)"
echo "      - platform-requirements.yml (the source file you used)"
echo ""
echo "   3. Commit and push the config-repo changes:"
echo "      cd \"$CONFIG_REPO_ROOT\""
echo "      git add ."
echo "      git commit -m \"Add $APP_NAME application configuration\""
echo "      git push"
echo ""
echo "   4. Your application will be automatically deployed by ArgoCD!"
echo ""
echo "🎉 Application onboarding complete for: $APP_NAME"
echo ""
echo "💡 The app-of-apps.yaml will automatically discover your new applications"
echo "   and deploy them to both staging and production environments."
echo ""
echo "🔧 Application-specific script created at:"
echo "   $CONFIG_REPO_ROOT/apps/$APP_NAME/onboard-$APP_NAME.sh"
echo ""
echo "📖 For more information, see:"
echo "   $CONFIG_REPO_ROOT/apps/$APP_NAME/README.md"
