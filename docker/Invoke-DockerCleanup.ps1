#Requires -Version 5.1
<#
.SYNOPSIS
    Remove unused Docker containers, images, volumes, and networks.
.PARAMETER All
    Also remove images not referenced by any container (not just dangling).
.PARAMETER DryRun
    Show what would be removed without removing anything.
.EXAMPLE
    .\Invoke-DockerCleanup.ps1
.EXAMPLE
    .\Invoke-DockerCleanup.ps1 -All -DryRun
#>

[CmdletBinding()]
param(
    [switch]$All,
    [switch]$DryRun
)

function Write-Info { Write-Host "[INFO]  $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN]  $args" -ForegroundColor Yellow }
function Write-Section { Write-Host "`n--- $args ---" -ForegroundColor White }

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "docker not found in PATH."
    exit 1
}

function Invoke-DockerCommand {
    param([string[]]$Args, [string]$Description)
    if ($DryRun) {
        Write-Warn "Would run: docker $($Args -join ' ')"
    } else {
        Write-Info $Description
        & docker @Args
    }
}

Write-Section "Stopped Containers"
$stopped = docker ps -aq --filter status=exited --filter status=created 2>$null
if ($stopped) {
    $stopped | ForEach-Object {
        $name = docker inspect --format '{{.Name}}' $_ 2>$null
        Invoke-DockerCommand @('rm', $_) "Removing container: $name"
    }
} else {
    Write-Info "No stopped containers."
}

Write-Section "Dangling Images"
$dangling = docker images -q --filter dangling=true 2>$null
if ($dangling) {
    Invoke-DockerCommand @('rmi') + $dangling "Removing dangling images"
} else {
    Write-Info "No dangling images."
}

if ($All) {
    Write-Section "Unused Images (--All)"
    Invoke-DockerCommand @('image', 'prune', '-a', '-f') "Removing all unused images"
}

Write-Section "Unused Volumes"
$volumes = docker volume ls -q --filter dangling=true 2>$null
if ($volumes) {
    $volumes | ForEach-Object {
        Invoke-DockerCommand @('volume', 'rm', $_) "Removing volume: $_"
    }
} else {
    Write-Info "No unused volumes."
}

Write-Section "Unused Networks"
docker network ls --format '{{.ID}} {{.Name}}' 2>$null |
    Where-Object { $_ -notmatch 'bridge|host|none' } |
    ForEach-Object {
        $id, $name = $_ -split '\s+'
        $count = (docker network inspect $id --format '{{len .Containers}}' 2>$null)
        if ($count -eq '0') {
            Invoke-DockerCommand @('network', 'rm', $id) "Removing network: $name"
        }
    }

Write-Section "Build Cache"
Invoke-DockerCommand @('builder', 'prune', '-f') "Pruning build cache"

Write-Host ""
if (-not $DryRun) {
    Write-Info "Docker cleanup complete."
    docker system df
}
