# Main Script Usage Guide

## Overview
The `main.sh` script is the primary orchestration tool for the Spanda Platform team. It automates the complete application onboarding workflow.

## Usage

### Run from the config-repo directory:
```bash
cd config-repo
```

### Process all applications:
```bash
./scripts/main.sh
```

### Process a specific application:
```bash
./scripts/main.sh Test-Application
```

## What the script does:

1. **🔄 Syncs repositories** - Updates all local app repository clones
2. **⚙️ Generates ArgoCD manifests** - Creates deployment configurations
3. **📋 Checks for changes** - Identifies what needs to be committed
4. **🌿 Switches to testing branch** - Ensures we're on the correct branch
5. **💾 Commits changes** - Commits with descriptive messages
6. **🚀 Pushes to remote** - Uploads to GitHub testing branch

## Prerequisites

- Must be run from the `config-repo` directory
- Git repository must have `origin` remote configured
- SSH key or GitHub authentication must be set up
- `yq` command-line tool must be installed for YAML processing

## Troubleshooting

### Authentication Issues
If push fails due to authentication:
```bash
# Make sure your SSH key is loaded
ssh-add ~/.ssh/id_rsa

# Or use GitHub CLI to authenticate
gh auth login
```

### Missing yq Tool
```bash
# Windows (PowerShell)
Invoke-WebRequest -Uri https://github.com/mikefarah/yq/releases/latest/download/yq_windows_amd64.exe -OutFile yq.exe

# Linux/WSL
curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o yq && chmod +x yq

# macOS
brew install yq
```

### Manual Push
If automatic push fails, you can push manually:
```bash
git push --set-upstream origin testing
```

## Success Indicators

✅ **Successful run shows:**
- All repositories synced
- ArgoCD applications generated
- Changes committed to testing branch
- Changes pushed to remote repository
- GitHub links for reviewing changes

## Example Output

```
🚀 Spanda Platform - Main Orchestration Script
==============================================
📍 Working directory: /path/to/config-repo
🌿 Current branch: testing
🎯 Target branch: testing

🔄 Step 1: Syncing application repositories...
[... sync output ...]

⚙️ Step 2: Generating ArgoCD applications...
[... generation output ...]

📋 Step 3: Checking for changes...
🎯 Applications with changes:
  - test-application

🌿 Step 4: Switching to testing branch...
✅ Already on 'testing' branch

💾 Step 5: Committing changes...
📝 Commit message:
feat(test-application): Update ArgoCD manifests for test-application

✅ Changes committed successfully

🚀 Step 6: Pushing to remote repository...
✅ Changes pushed to remote 'testing' branch

🔗 View your changes at:
   https://github.com/aryan-spanda/Spanda-config/tree/testing

📦 Applications updated:
   - test-application: https://github.com/aryan-spanda/Spanda-config/tree/testing/applications/test-application

🎉 Process completed successfully!
```
