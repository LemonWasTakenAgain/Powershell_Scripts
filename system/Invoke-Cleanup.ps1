#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Remove temporary files, caches, and old logs to free disk space.
.PARAMETER DryRun
    Show what would be deleted without deleting anything.
.EXAMPLE
    .\Invoke-Cleanup.ps1
.EXAMPLE
    .\Invoke-Cleanup.ps1 -DryRun
#>

[CmdletBinding()]
param([switch]$DryRun)

function Write-Info    { Write-Host "[INFO]  $args" -ForegroundColor Green }
function Write-Removed { Write-Host "[DEL]   $args" -ForegroundColor Yellow }
function Write-Section { Write-Host "`n--- $args ---" -ForegroundColor White }

$TotalFreed = 0

function Remove-Items {
    param([string[]]$Paths, [string]$Label)
    foreach ($p in $Paths) {
        if (Test-Path $p) {
            $size = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum).Sum
            if ($DryRun) {
                Write-Removed "Would remove: $p ($([math]::Round($size/1MB,1)) MB)"
            } else {
                Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
                Write-Removed "Removed: $p ($([math]::Round($size/1MB,1)) MB)"
                $script:TotalFreed += $size
            }
        }
    }
}

Write-Section "Windows Temp Files"
Remove-Items @(
    $env:TEMP,
    "C:\Windows\Temp",
    "C:\Windows\Prefetch"
) -Label "Temp"

Write-Section "Windows Update Cache"
Remove-Items @("C:\Windows\SoftwareDistribution\Download") -Label "WUpdate"

Write-Section "Windows Error Reporting"
Remove-Items @(
    "$env:LOCALAPPDATA\Microsoft\Windows\WER",
    "C:\ProgramData\Microsoft\Windows\WER\ReportArchive",
    "C:\ProgramData\Microsoft\Windows\WER\ReportQueue"
) -Label "WER"

Write-Section "Browser Caches"
$BrowserCaches = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles\*\cache2",
    "$env:APPDATA\Opera Software\Opera Stable\Cache"
)
Remove-Items $BrowserCaches -Label "Browsers"

Write-Section "Recycle Bin"
if (-not $DryRun) {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Removed "Recycle Bin emptied"
} else {
    Write-Removed "Would empty: Recycle Bin"
}

Write-Section "npm / pip Caches"
Remove-Items @(
    "$env:APPDATA\npm-cache",
    "$env:LOCALAPPDATA\pip\Cache"
) -Label "Dev caches"

Write-Section "Windows Log Files (older than 30 days)"
Get-ChildItem "C:\Windows\Logs" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    ForEach-Object {
        if ($DryRun) {
            Write-Removed "Would remove log: $($_.FullName)"
        } else {
            $script:TotalFreed += $_.Length
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            Write-Removed "Removed log: $($_.FullName)"
        }
    }

Write-Host ""
if ($DryRun) {
    Write-Info "Dry run complete. No files deleted."
} else {
    Write-Info ("Cleanup complete. Approximately {0:N1} MB freed." -f ($TotalFreed / 1MB))
}
