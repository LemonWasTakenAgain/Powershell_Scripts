#Requires -Version 5.1
<#
.SYNOPSIS
    Test TCP port connectivity to a host.
.PARAMETER Host
    Target hostname or IP address.
.PARAMETER Ports
    One or more ports to test. Accepts comma-separated values or ranges.
.PARAMETER Timeout
    Connection timeout in milliseconds. Default: 2000.
.EXAMPLE
    .\Test-Ports.ps1 -Host 192.168.1.1 -Ports 80,443,22
.EXAMPLE
    .\Test-Ports.ps1 -Host myserver.local -Ports (1..1024)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TargetHost,
    [Parameter(Mandatory)][int[]]$Ports,
    [int]$Timeout = 2000
)

$openCount   = 0
$closedCount = 0

Write-Host "`nPort scan: $TargetHost  (timeout=${Timeout}ms, ports=$($Ports.Count))`n" -ForegroundColor Cyan

foreach ($port in $Ports) {
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $tcp.BeginConnect($TargetHost, $port, $null, $null)
        $wait    = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
        if ($wait -and -not $tcp.Client.Poll(0, [System.Net.Sockets.SelectMode]::SelectError)) {
            $tcp.EndConnect($connect)
            Write-Host ("  OPEN   {0}" -f $port) -ForegroundColor Green
            $openCount++
        } else {
            if ($Ports.Count -le 50) {
                Write-Host ("  CLOSED {0}" -f $port) -ForegroundColor Red
            }
            $closedCount++
        }
    } catch {
        if ($Ports.Count -le 50) {
            Write-Host ("  CLOSED {0}" -f $port) -ForegroundColor Red
        }
        $closedCount++
    } finally {
        $tcp.Close()
    }
}

Write-Host ""
Write-Host "Results: " -NoNewline
Write-Host "$openCount open" -ForegroundColor Green -NoNewline
Write-Host "  $closedCount closed" -ForegroundColor Red
