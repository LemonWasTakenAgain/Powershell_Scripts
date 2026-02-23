#Requires -Version 5.1
<#
.SYNOPSIS
    Backup a directory with timestamped snapshots and rotation.
.DESCRIPTION
    Uses robocopy to create incremental backups with timestamps.
    Keeps the last N snapshots and removes older ones automatically.
.PARAMETER Source
    Source directory to back up.
.PARAMETER Destination
    Destination parent directory where snapshots are created.
.PARAMETER Keep
    Number of snapshots to retain. Default: 7.
.PARAMETER Compress
    Compress the snapshot into a zip archive.
.EXAMPLE
    .\Backup-Directory.ps1 -Source C:\Users\User\Documents -Destination D:\Backups
.EXAMPLE
    .\Backup-Directory.ps1 -Source C:\Projects -Destination E:\Backups -Keep 14 -Compress
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Destination,
    [int]$Keep = 7,
    [switch]$Compress
)

function Write-Info { Write-Host "[INFO]  $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN]  $args" -ForegroundColor Yellow }

if (-not (Test-Path $Source)) {
    Write-Error "Source not found: $Source"
    exit 1
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null

$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$snapDir   = Join-Path $Destination $timestamp

Write-Info "Backup: $Source → $snapDir"

# robocopy: mirror mode, exclude system/temp files
$roboArgs = @(
    $Source, $snapDir,
    '/E',           # include subdirectories
    '/COPYALL',     # copy all file attributes
    '/R:2',         # retry twice on failure
    '/W:3',         # wait 3 seconds between retries
    '/XA:SH',       # exclude system and hidden files
    '/XF', '*.tmp', '*.swp', 'thumbs.db', 'desktop.ini',
    '/NP',          # no progress (cleaner output)
    '/LOG+:NUL'     # suppress output (remove for verbose)
)

$result = Start-Process robocopy -ArgumentList $roboArgs -Wait -PassThru -NoNewWindow
# robocopy exit codes 0-7 are success/informational
if ($result.ExitCode -gt 7) {
    Write-Error "robocopy failed with exit code $($result.ExitCode)"
    exit 1
}

Write-Info "Snapshot created: $snapDir"

if ($Compress) {
    $zipPath = "${snapDir}.zip"
    Write-Info "Compressing to $zipPath..."
    Compress-Archive -Path $snapDir -DestinationPath $zipPath -CompressionLevel Optimal
    Remove-Item $snapDir -Recurse -Force
    Write-Info "Compressed. Removing uncompressed snapshot."
}

# Rotation
$pattern    = if ($Compress) { '*_*-*-*_*-*-*.zip' } else { $null }
$allSnaps   = Get-ChildItem $Destination |
              Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}' } |
              Sort-Object Name

if ($allSnaps.Count -gt $Keep) {
    $toDelete = $allSnaps | Select-Object -First ($allSnaps.Count - $Keep)
    foreach ($old in $toDelete) {
        Write-Warn "Removing old snapshot: $($old.Name)"
        Remove-Item $old.FullName -Recurse -Force
    }
}

$finalSnap = if ($Compress) { "${snapDir}.zip" } else { $snapDir }
$size      = (Get-ChildItem $finalSnap -Recurse -File -ErrorAction SilentlyContinue |
              Measure-Object -Property Length -Sum).Sum
Write-Info ("Backup complete. Size: {0:N1} MB" -f ($size / 1MB))
