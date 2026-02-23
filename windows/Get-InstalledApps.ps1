#Requires -Version 5.1
<#
.SYNOPSIS
    List all installed applications from multiple sources.
.DESCRIPTION
    Aggregates apps from winget, registry (Programs & Features),
    Windows Store, and Scoop/Chocolatey if installed.
.PARAMETER Filter
    Filter by name (wildcard supported).
.PARAMETER Source
    Limit to a specific source: registry, winget, store, scoop, choco
.EXAMPLE
    .\Get-InstalledApps.ps1
.EXAMPLE
    .\Get-InstalledApps.ps1 -Filter "*python*"
.EXAMPLE
    .\Get-InstalledApps.ps1 -Source winget
#>

[CmdletBinding()]
param(
    [string]$Filter = '*',
    [ValidateSet('all', 'registry', 'winget', 'store', 'scoop', 'choco')]
    [string]$Source = 'all'
)

$apps = [System.Collections.Generic.List[PSCustomObject]]::new()

# Registry (Programs & Features)
if ($Source -in 'all', 'registry') {
    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($path in $regPaths) {
        Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and ($_.DisplayName -like $Filter) } |
            ForEach-Object {
                $apps.Add([PSCustomObject]@{
                    Name    = $_.DisplayName
                    Version = $_.DisplayVersion
                    Source  = 'Registry'
                    Publisher = $_.Publisher
                })
            }
    }
}

# winget
if ($Source -in 'all', 'winget') {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget list --disable-interactivity 2>/dev/null |
            Select-Object -Skip 3 |
            Where-Object { $_ -match '\S' -and $_ -notmatch '^-' } |
            ForEach-Object {
                $cols = $_ -split '\s{2,}'
                if ($cols.Count -ge 2 -and $cols[0] -like $Filter) {
                    $apps.Add([PSCustomObject]@{
                        Name    = $cols[0]
                        Version = if ($cols.Count -ge 3) { $cols[2] } else { $cols[1] }
                        Source  = 'winget'
                        Publisher = ''
                    })
                }
            }
    }
}

# Scoop
if ($Source -in 'all', 'scoop') {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop list 2>/dev/null |
            Select-Object -Skip 2 |
            Where-Object { $_ -match '\S' } |
            ForEach-Object {
                $cols = $_ -split '\s+'
                if ($cols[0] -like $Filter) {
                    $apps.Add([PSCustomObject]@{
                        Name    = $cols[0]
                        Version = $cols[1]
                        Source  = 'Scoop'
                        Publisher = ''
                    })
                }
            }
    }
}

# Chocolatey
if ($Source -in 'all', 'choco') {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        (choco list 2>/dev/null) |
            Select-Object -Skip 1 |
            Where-Object { $_ -match '^\S' -and $_ -notmatch 'packages installed' } |
            ForEach-Object {
                $cols = $_ -split '\s+'
                if ($cols[0] -like $Filter) {
                    $apps.Add([PSCustomObject]@{
                        Name    = $cols[0]
                        Version = $cols[1]
                        Source  = 'Chocolatey'
                        Publisher = ''
                    })
                }
            }
    }
}

# Deduplicate and display
$unique = $apps | Sort-Object Name -Unique
Write-Host "`nInstalled Applications ($($unique.Count) found, filter='$Filter'):`n" -ForegroundColor Cyan
$unique | Format-Table -Property Name, Version, Source, Publisher -AutoSize
