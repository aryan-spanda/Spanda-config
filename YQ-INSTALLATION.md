# YQ Installation Guide for Windows

## **Option 1: Install yq via PowerShell (Recommended)**

```powershell
# Using Chocolatey (if installed)
choco install yq

# Using Scoop (if installed)  
scoop install yq

# Using winget (Windows 11/10)
winget install mikefarah.yq
```

## **Option 2: Manual Installation**

1. **Download yq**: Go to https://github.com/mikefarah/yq/releases
2. **Download**: `yq_windows_amd64.exe`
3. **Rename**: to `yq.exe`
4. **Add to PATH**: Place in a directory that's in your PATH (e.g., `C:\Windows\System32`)

## **Option 3: Test Installation**

```bash
yq --version
```

Should output something like: `yq (https://github.com/mikefarah/yq/) version 4.x.x`

## **Alternative: Use Without yq**

If you can't install yq, you can still use the scripts by modifying them to use basic bash/grep parsing instead of yq. The scripts will detect if yq is missing and provide simplified functionality.

## **Verify Everything Works**

```bash
cd "C:\Users\aryan\OneDrive\Documents\spanda docs\config-repo"
./scripts/deploy-platform-services.sh help
```
