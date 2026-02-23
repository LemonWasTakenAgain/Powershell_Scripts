#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Bootstrap a Windows development environment.
.DESCRIPTION
    Installs winget packages, configures Git, sets developer-friendly
    settings, and optionally installs WSL2.
.PARAMETER Minimal
    Install only essential tools (Git, VS Code, Windows Terminal, PowerShell 7).
.PARAMETER InstallWSL
    Install WSL2 with Ubuntu.
.EXAMPLE
    .\Set-DevEnvironment.ps1
.EXAMPLE
    .\Set-DevEnvironment.ps1 -Minimal -InstallWSL
#>

[CmdletBinding()]
param(
    [switch]$Minimal,
    [switch]$InstallWSL
)

function Write-Info    { Write-Host "[INFO]  $args" -ForegroundColor Green }
function Write-Section { Write-Host "`n--- $args ---" -ForegroundColor Cyan }
function Install-App {
    param([string]$Id, [string]$Name)
    Write-Host "  Installing $Name..." -NoNewline
    $result = winget install --id $Id --silent --accept-source-agreements --accept-package-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
        Write-Host " done" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
    }
}

# Essential tools
$essentialApps = @(
    @{ Id = 'Git.Git';                   Name = 'Git' },
    @{ Id = 'Microsoft.VisualStudioCode';Name = 'VS Code' },
    @{ Id = 'Microsoft.WindowsTerminal'; Name = 'Windows Terminal' },
    @{ Id = 'Microsoft.PowerShell';      Name = 'PowerShell 7' }
)

$devApps = @(
    @{ Id = 'Python.Python.3.13';        Name = 'Python 3.13' },
    @{ Id = 'OpenJS.NodeJS.LTS';         Name = 'Node.js LTS' },
    @{ Id = 'Docker.DockerDesktop';      Name = 'Docker Desktop' },
    @{ Id = 'Hashicorp.Terraform';       Name = 'Terraform' },
    @{ Id = 'Kubernetes.kubectl';        Name = 'kubectl' },
    @{ Id = 'Helm.Helm';                 Name = 'Helm' },
    @{ Id = 'JetBrains.Toolbox';         Name = 'JetBrains Toolbox' },
    @{ Id = 'GitHub.cli';                Name = 'GitHub CLI' },
    @{ Id = 'sharkdp.bat';               Name = 'bat (cat replacement)' },
    @{ Id = 'BurntSushi.ripgrep.MSVC';   Name = 'ripgrep' },
    @{ Id = 'junegunn.fzf';              Name = 'fzf' },
    @{ Id = 'Neovim.Neovim';             Name = 'Neovim' }
)

Write-Section "Installing Essential Tools"
foreach ($app in $essentialApps) { Install-App -Id $app.Id -Name $app.Name }

if (-not $Minimal) {
    Write-Section "Installing Development Tools"
    foreach ($app in $devApps) { Install-App -Id $app.Id -Name $app.Name }
}

Write-Section "Windows Developer Settings"
# Enable long paths
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1
Write-Info "Long file paths enabled"

# Show file extensions in Explorer
$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $explorerKey -Name 'HideFileExt' -Value 0
Set-ItemProperty $explorerKey -Name 'Hidden' -Value 1
Set-ItemProperty $explorerKey -Name 'ShowSuperHidden' -Value 1
Write-Info "Explorer: show extensions, hidden files, system files"

# Disable UAC prompt for admins (useful for automation)
# Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin' -Value 0
# Write-Info "UAC silent for admins (commented out — uncomment to enable)"

# Enable Developer Mode
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -Value 1 -ErrorAction SilentlyContinue
Write-Info "Developer mode enabled"

Write-Section "Git Global Configuration"
if (Get-Command git -ErrorAction SilentlyContinue) {
    git config --global core.autocrlf input
    git config --global core.longpaths true
    git config --global pull.rebase false
    git config --global init.defaultBranch main
    git config --global rerere.enabled true
    Write-Info "Git: autocrlf=input, longpaths=true, default branch=main"
} else {
    Write-Host "  Git not found in PATH yet — restart terminal after install" -ForegroundColor Yellow
}

if ($InstallWSL) {
    Write-Section "WSL2 + Ubuntu"
    Write-Info "Installing WSL2..."
    wsl --install -d Ubuntu 2>&1
    Write-Info "WSL2 installation initiated. Reboot may be required."
}

Write-Host ""
Write-Info "Dev environment setup complete. Restart your terminal to apply PATH changes."
