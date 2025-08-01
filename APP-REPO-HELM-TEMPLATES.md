# Helm Chart Templates for Application Repository

## For spanda-test-app/charts/test-application/

### 📄 values.yaml (Base - Environment Agnostic)
```yaml
# Base values - environment agnostic defaults
replicaCount: 2

image:
  repository: ghcr.io/aryan-spanda/test-application
  tag: "latest"
  pullPolicy: IfNotPresent

imagePullSecrets:
  - name: ghcr-secret

serviceAccount:
  create: true
  automountServiceAccountToken: false
  annotations: {}
  name: ""

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
  targetPort: 3000

# Ingress disabled by default - enabled per environment
ingress:
  enabled: false
  className: "nginx"
  host: ""
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls: []

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

# Environment variables - populated by overlays
env: []

# Health check configuration
probes:
  liveness:
    enabled: true
    path: /health
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  readiness:
    enabled: true
    path: /health
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3
```

### 📄 values-dev.yaml
```yaml
# Development environment overrides
replicaCount: 1

image:
  tag: "latest"
  pullPolicy: Always

ingress:
  enabled: true
  host: "test-application-dev.local"
  tls:
    - secretName: test-application-dev-tls
      hosts:
        - test-application-dev.local

env:
  - name: NODE_ENV
    value: "development"
  - name: LOG_LEVEL
    value: "debug"
  - name: REACT_APP_API_URL
    value: "https://test-application-dev.local/api"

resources:
  limits:
    cpu: 250m
    memory: 256Mi
  requests:
    cpu: 50m
    memory: 64Mi

probes:
  liveness:
    initialDelaySeconds: 10
  readiness:
    initialDelaySeconds: 3
```

### 📄 values-staging.yaml
```yaml
# Staging environment overrides
replicaCount: 1

image:
  tag: "latest"
  pullPolicy: Always

ingress:
  enabled: true
  host: "test-application-staging.local"
  tls:
    - secretName: test-application-staging-tls
      hosts:
        - test-application-staging.local

env:
  - name: NODE_ENV
    value: "staging"
  - name: LOG_LEVEL
    value: "info"
  - name: REACT_APP_API_URL
    value: "https://test-application-staging.local/api"

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
```

### 📄 values-prod.yaml
```yaml
# Production environment overrides
replicaCount: 2

image:
  tag: "latest"  # Will be updated by ArgoCD Image Updater
  pullPolicy: IfNotPresent

ingress:
  enabled: true
  host: "app.example.com"
  tls:
    - secretName: test-application-prod-tls
      hosts:
        - app.example.com

env:
  - name: NODE_ENV
    value: "production"
  - name: LOG_LEVEL
    value: "warn"
  - name: REACT_APP_API_URL
    value: "https://app.example.com/api"

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Anti-affinity for production
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - test-application
        topologyKey: kubernetes.io/hostname
```

## 🚚 Migration Instructions

1. **Copy Templates**: Copy all Kubernetes templates from `config-repo/apps/test-application/templates/` to `spanda-test-app/charts/test-application/templates/`

2. **Update Chart.yaml**: Copy from `config-repo/apps/test-application/Chart.yaml`

3. **Create Values**: Use the above values files in your app repository

4. **Update Templates**: Ensure templates use the new structure (e.g., `.Values.env` array format)

The templates in `config-repo/apps/test-application/templates/` should be moved to the application repository.
