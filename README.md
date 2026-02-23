# Powershell_Scripts

A collection of general-purpose PowerShell scripts for Windows system administration, DevOps, and development environments.

All scripts follow PowerShell best practices: comment-based help, `[CmdletBinding()]`, `-WhatIf`/`-DryRun` support where appropriate, and meaningful error output.

---

## Requirements

- PowerShell 5.1+ (most scripts) or PowerShell 7+ (parallel scripts)
- Some scripts require running as Administrator — noted in the table below
- External tools (winget, docker, git, robocopy) are checked at runtime with clear error messages

---

## Structure

```
Powershell_Scripts/
├── system/          # System info, updates, disk, cleanup
├── network/         # Network info, port scanning, ping sweep
├── backup/          # Directory backup with rotation
├── git/             # Git repository utilities
├── docker/          # Docker container/image management
├── security/        # SSL checks, local admin audit
└── windows/         # Windows-specific: dev setup, app inventory
```

---

## Scripts

### system/

| Script | Description | Admin? |
|--------|-------------|:------:|
| `Get-SystemInfo.ps1` | CPU, memory, disk, network, and top processes summary | No |
| `Update-System.ps1` | Update Windows, winget, Chocolatey, Scoop, npm | Yes |
| `Get-DiskUsage.ps1` | Disk usage breakdown sorted by size, with largest files | No |
| `Invoke-Cleanup.ps1` | Remove temp files, browser caches, Windows logs, Recycle Bin | Yes |

```powershell
# Examples
.\system\Get-SystemInfo.ps1
.\system\Update-System.ps1 -SkipWindowsUpdate          # winget/choco/scoop only
.\system\Get-DiskUsage.ps1 -Path C:\Users\User -Depth 2
.\system\Invoke-Cleanup.ps1 -DryRun                    # preview what would be deleted
```

### network/

| Script | Description | Admin? |
|--------|-------------|:------:|
| `Get-NetworkInfo.ps1` | Adapters, IPs, routes, DNS, external IP, listening ports | No |
| `Test-Ports.ps1` | Test TCP port connectivity to a host | No |
| `Invoke-PingSweep.ps1` | Discover live hosts in a /24 subnet (parallel) | No |

```powershell
.\network\Get-NetworkInfo.ps1
.\network\Test-Ports.ps1 -TargetHost 192.168.1.1 -Ports 22,80,443
.\network\Invoke-PingSweep.ps1 -Subnet 192.168.1 -Workers 100
```

### backup/

| Script | Description | Admin? |
|--------|-------------|:------:|
| `Backup-Directory.ps1` | Robocopy snapshot backup with timestamps and rotation | No |

```powershell
.\backup\Backup-Directory.ps1 -Source C:\Projects -Destination D:\Backups
.\backup\Backup-Directory.ps1 -Source C:\Data -Destination E:\Backups -Keep 14 -Compress
```

### git/

| Script | Description | Admin? |
|--------|-------------|:------:|
| `Invoke-PullAll.ps1` | Pull all git repos found under a directory | No |

```powershell
.\git\Invoke-PullAll.ps1
.\git\Invoke-PullAll.ps1 -RootPath C:\Projects -Depth 4
```

### docker/

| Script | Description | Admin? |
|--------|-------------|:------:|
| `Invoke-DockerCleanup.ps1` | Remove stopped containers, dangling images, unused volumes | No |

```powershell
.\docker\Invoke-DockerCleanup.ps1
.\docker\Invoke-DockerCleanup.ps1 -All -DryRun
```

### security/

| Script | Description | Admin? |
|--------|-------------|:------:|
| `Test-SslExpiry.ps1` | Check SSL certificate expiry for domains | No |
| `Get-LocalAdmins.ps1` | Audit local admin accounts and recent logon events | Yes |

```powershell
.\security\Test-SslExpiry.ps1 -Domains google.com,github.com,myapp.local:8443
.\security\Get-LocalAdmins.ps1
```

### windows/

| Script | Description | Admin? |
|--------|-------------|:------:|
| `Set-DevEnvironment.ps1` | Bootstrap a Windows dev environment (winget, WSL2, Git, VS Code, etc.) | Yes |
| `Get-InstalledApps.ps1` | List installed apps from registry, winget, Scoop, Chocolatey | No |

```powershell
.\windows\Set-DevEnvironment.ps1
.\windows\Set-DevEnvironment.ps1 -Minimal -InstallWSL
.\windows\Get-InstalledApps.ps1 -Filter "*python*"
.\windows\Get-InstalledApps.ps1 -Source winget
```

---

## Execution Policy

If scripts are blocked by execution policy, run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or unblock a specific script:

```powershell
Unblock-File -Path .\script.ps1
```

---

## License

MIT
