#Requires -Version 5.1
<#
.SYNOPSIS
    Display a summary of system information.
.DESCRIPTION
    Shows OS, CPU, memory, disk, network, and top processes.
.EXAMPLE
    .\Get-SystemInfo.ps1
#>

[CmdletBinding()]
param()

function Write-Section {
    param([string]$Title)
    Write-Host "`n=== $Title ===" -ForegroundColor Cyan
}

Write-Section "System"
$os  = Get-CimInstance Win32_OperatingSystem
$cs  = Get-CimInstance Win32_ComputerSystem
$up  = (Get-Date) - $os.LastBootUpTime
Write-Host "Hostname  : $($env:COMPUTERNAME)"
Write-Host "OS        : $($os.Caption) ($($os.Version))"
Write-Host "Arch      : $($os.OSArchitecture)"
Write-Host "Uptime    : $($up.Days)d $($up.Hours)h $($up.Minutes)m"
Write-Host "Domain    : $($cs.Domain)"

Write-Section "CPU"
$cpu = Get-CimInstance Win32_Processor
Write-Host "Model     : $($cpu.Name.Trim())"
Write-Host "Cores     : $($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads"
$cpuLoad = (Get-CimInstance Win32_Processor).LoadPercentage
Write-Host "Load      : $cpuLoad%"

Write-Section "Memory"
$totalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
$freeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$usedGB  = [math]::Round($totalGB - $freeGB, 1)
$pct     = [math]::Round($usedGB / $totalGB * 100, 1)
$color   = if ($pct -gt 90) { 'Red' } elseif ($pct -gt 70) { 'Yellow' } else { 'Green' }
Write-Host "Total     : ${totalGB} GB"
Write-Host "Used      : ${usedGB} GB (${pct}%)" -ForegroundColor $color
Write-Host "Free      : ${freeGB} GB"

Write-Section "Disk Usage"
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
    $total = [math]::Round(($_.Used + $_.Free) / 1GB, 1)
    $used  = [math]::Round($_.Used / 1GB, 1)
    $pct   = if ($total -gt 0) { [math]::Round($used / $total * 100, 1) } else { 0 }
    $bar   = ('#' * [int]($pct / 5)) + ('-' * (20 - [int]($pct / 5)))
    $color = if ($pct -gt 90) { 'Red' } elseif ($pct -gt 75) { 'Yellow' } else { 'Green' }
    Write-Host ("  {0,-6} [{1}] {2,5}%  {3,6} GB / {4} GB" -f $_.Name, $bar, $pct, $used, $total) -ForegroundColor $color
}

Write-Section "Network"
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' } | ForEach-Object {
    $adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
    Write-Host ("  {0,-20} {1,-18} [{2}]" -f $adapter.Name, $_.IPAddress, $adapter.Status)
}

Write-Section "Top Processes (CPU)"
Get-Process | Sort-Object CPU -Descending | Select-Object -First 8 | ForEach-Object {
    $cpu  = [math]::Round($_.CPU, 1)
    $memM = [math]::Round($_.WorkingSet64 / 1MB, 1)
    Write-Host ("  {0,-30} CPU: {1,8}s  Mem: {2,8} MB" -f $_.Name, $cpu, $memM)
}

Write-Host ""
