#Requires -Version 5.1
<#
.SYNOPSIS
    Show disk usage breakdown sorted by size.
.DESCRIPTION
    Lists directories under a path sorted by size, highlights large items,
    and shows the top largest files.
.PARAMETER Path
    Root path to analyze. Defaults to current directory.
.PARAMETER Depth
    How many levels deep to scan. Default: 1.
.PARAMETER TopFiles
    Number of largest individual files to show. Default: 10.
.EXAMPLE
    .\Get-DiskUsage.ps1
.EXAMPLE
    .\Get-DiskUsage.ps1 -Path C:\Users\User -Depth 2
#>

[CmdletBinding()]
param(
    [string]$Path = (Get-Location).Path,
    [int]$Depth   = 1,
    [int]$TopFiles = 10
)

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { "{0:N1} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { "{0:N1} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { "{0:N1} KB" -f ($Bytes / 1KB) }
    else { "$Bytes B" }
}

if (-not (Test-Path $Path)) {
    Write-Error "Path not found: $Path"
    exit 1
}

Write-Host "`nDisk Usage: $Path (depth=$Depth)" -ForegroundColor Cyan

# Drive stats
$drive = Split-Path -Qualifier $Path
$disk  = Get-PSDrive -Name $drive.TrimEnd(':') -ErrorAction SilentlyContinue
if ($disk) {
    $total = $disk.Used + $disk.Free
    $pct   = [math]::Round($disk.Used / $total * 100, 1)
    Write-Host ("Drive {0}  Used: {1}  Free: {2}  Total: {3}  ({4}%)" -f `
        $drive, (Format-Size $disk.Used), (Format-Size $disk.Free), (Format-Size $total), $pct)
}

Write-Host "`nTop directories:" -ForegroundColor White

# Get size per directory at specified depth
$items = Get-ChildItem -Path $Path -Depth ($Depth - 1) -Directory -ErrorAction SilentlyContinue

$results = $items | ForEach-Object {
    $dir = $_
    $size = (Get-ChildItem -Path $dir.FullName -Recurse -File -ErrorAction SilentlyContinue |
             Measure-Object -Property Length -Sum).Sum
    [PSCustomObject]@{ Name = $dir.FullName; Size = $size ?? 0 }
} | Sort-Object Size -Descending

foreach ($item in $results | Select-Object -First 30) {
    $sizeStr = Format-Size $item.Size
    $sizeGB  = $item.Size / 1GB
    $color   = if ($sizeGB -ge 10) { 'Red' } elseif ($sizeGB -ge 1) { 'Yellow' } else { 'Green' }
    Write-Host ("  {0,-10} {1}" -f $sizeStr, $item.Name) -ForegroundColor $color
}

Write-Host "`nTop $TopFiles largest files:" -ForegroundColor White
Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First $TopFiles |
    ForEach-Object {
        Write-Host ("  {0,-10} {1}" -f (Format-Size $_.Length), $_.FullName)
    }

Write-Host ""
