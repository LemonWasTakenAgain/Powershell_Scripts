# PowerShell Scripts

## Project Context

Modular collection of PowerShell scripts for Windows system administration,
DevOps, and development. Requires PowerShell 5.1+ (7+ for parallel scripts).

- GitLab: https://gitlab.steelcanvas.studio/user-projects/powershell-scripts
- GitHub: https://github.com/LemonWasTakenAgain/Powershell_Scripts

## Commands

```powershell
# Lint (requires PSScriptAnalyzer)
Invoke-ScriptAnalyzer -Path . -Recurse

# Syntax check
Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object { [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null) }
```

## Repository Structure

```
Powershell_Scripts/
  system/       # System info, updates, disk, cleanup
  network/      # Network info, port scanning, ping sweep
  backup/       # Directory backup with rotation
  git/          # Git utilities
  docker/       # Docker management
  security/     # SSL checks, local admin audit
  windows/      # Dev setup, app inventory
  monitoring/   # Monitoring scripts
```

## Key Patterns

- All scripts use comment-based help headers
- Proper error handling with try/catch
- Scripts organized by function into subdirectories

## CI Pipeline

Stages: lint -> security -> mirror
- **lint**: PowerShell syntax validation
- **security**: gitleaks secret scanning
- **mirror**: Push to GitHub backup
