# 📝 Onboarding Script Update Notes

## Current Status
The existing `onboard-application.sh` script is preserved and functional. It creates Helm charts in the config repository, which is the current pattern.

## Future Enhancement
For full GitOps compliance, the script should be updated to:

1. **Create ArgoCD Applications** in `applications/` directory instead of `landing-zone/applications/`
2. **Point to Application Repository** instead of config repo for Helm charts
3. **Generate app repository structure** templates

## Temporary Workaround
Until the script is updated:

1. **Use existing script** to create initial structure
2. **Manually move** Helm chart to application repository  
3. **Update ArgoCD Application** to point to app repo

## Script Update TODO
```bash
# Replace these paths in onboard-application.sh:
# OLD: $CONFIG_REPO_ROOT/apps/$APP_NAME/
# NEW: $CONFIG_REPO_ROOT/applications/$APP_NAME/argocd/

# Update ArgoCD Application template to point to:
# source:
#   repoURL: https://github.com/aryan-spanda/${APP_NAME}.git
#   path: charts/${APP_NAME}
```

## Current Script Functionality (Preserved)
✅ Reads `platform-requirements.yml`
✅ Creates Helm chart structure
✅ Generates environment-specific values
✅ Creates ArgoCD Applications  
✅ Supports frontend/backend patterns
✅ Database integration
✅ Health checks and ingress configuration

The script remains fully functional for current workflow patterns.
