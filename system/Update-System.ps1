#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Update Windows, winget packages, and optional package managers.
.DESCRIPTION
    Installs Windows Updates, updates all winget packages, and optionally
    updates Chocolatey and Scoop packages if installed.
.PARAMETER WindowsUpdateOnly
    Only install Windows Updates, skip package managers.
.PARAMETER SkipWindowsUpdate
    Skip Windows Updates, only update package managers.
.PARAMETER Reboot
    Automatically reboot if required after Windows Updates.
.EXAMPLE
    .\Update-System.ps1
.EXAMPLE
    .\Update-System.ps1 -SkipWindowsUpdate
.EXAMPLE
    .\Update-System.ps1 -Reboot
#>

[CmdletBinding()]
param(
    [switch]$WindowsUpdateOnly,
    [switch]$SkipWindowsUpdate,
    [switch]$Reboot
)

function Write-Info    { Write-Host "[INFO]  $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN]  $args" -ForegroundColor Yellow }
function Write-Section { Write-Host "`n--- $args ---" -ForegroundColor White }

$RebootRequired = $false

# Windows Update
if (-not $SkipWindowsUpdate) {
    Write-Section "Windows Update"
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Info "Installing PSWindowsUpdate module..."
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -ErrorAction Stop
    }
    Import-Module PSWindowsUpdate -ErrorAction Stop
    Write-Info "Checking for updates..."
    $updates = Get-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot
    if ($updates.Count -eq 0) {
        Write-Info "No Windows Updates available."
    } else {
        Write-Info "Installing $($updates.Count) update(s)..."
        Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot | ForEach-Object {
            Write-Host "  $($_.Title)" -ForegroundColor Cyan
        }
        if (Get-WURebootStatus -Silent) {
            $RebootRequired = $true
            Write-Warn "Reboot required after Windows Updates."
        }
    }
}

if ($WindowsUpdateOnly) { exit 0 }

# winget
Write-Section "winget"
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Info "Upgrading all winget packages..."
    winget upgrade --all --include-unknown --silent --accept-source-agreements --accept-package-agreements
} else {
    Write-Warn "winget not found — skipping."
}

# Chocolatey
Write-Section "Chocolatey"
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Info "Upgrading all Chocolatey packages..."
    choco upgrade all -y
} else {
    Write-Host "  Chocolatey not installed — skipping." -ForegroundColor DarkGray
}

# Scoop
Write-Section "Scoop"
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Info "Updating Scoop and all buckets..."
    scoop update
    scoop update *
    scoop cleanup *
} else {
    Write-Host "  Scoop not installed — skipping." -ForegroundColor DarkGray
}

# npm global packages
Write-Section "npm (global)"
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Info "Updating npm global packages..."
    npm update -g 2>&1 | Where-Object { $_ -match 'updated|added' }
} else {
    Write-Host "  npm not found — skipping." -ForegroundColor DarkGray
}

Write-Host ""
Write-Info "Update complete."
if ($RebootRequired) {
    if ($Reboot) {
        Write-Info "Rebooting in 10 seconds..."
        Start-Sleep 10
        Restart-Computer -Force
    } else {
        Write-Warn "Reboot required. Run with -Reboot to reboot automatically."
    }
}
