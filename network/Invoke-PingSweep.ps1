#Requires -Version 5.1
<#
.SYNOPSIS
    Ping sweep a subnet to discover live hosts.
.PARAMETER Subnet
    Network prefix, e.g. '192.168.1' for a /24.
.PARAMETER Workers
    Number of parallel jobs. Default: 50.
.PARAMETER Timeout
    Ping timeout in milliseconds. Default: 500.
.EXAMPLE
    .\Invoke-PingSweep.ps1 -Subnet 192.168.1
.EXAMPLE
    .\Invoke-PingSweep.ps1 -Subnet 10.0.0 -Workers 100
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Subnet,
    [int]$Workers = 50,
    [int]$Timeout = 500
)

# Strip trailing .0 if provided
$base = $Subnet.TrimEnd('.0')

Write-Host "`nPing sweep: $base.0/24  (workers=$Workers, timeout=${Timeout}ms)`n" -ForegroundColor Cyan
Write-Host "Scanning 254 hosts..."

$results = 1..254 | ForEach-Object -Parallel {
    $ip   = "$using:base.$_"
    $ping = New-Object System.Net.NetworkInformation.Ping
    try {
        $reply = $ping.Send($ip, $using:Timeout)
        if ($reply.Status -eq 'Success') {
            $hostname = try { [System.Net.Dns]::GetHostEntry($ip).HostName } catch { '' }
            [PSCustomObject]@{ IP = $ip; Alive = $true; Hostname = $hostname; RTT = $reply.RoundtripTime }
        }
    } catch {}
} -ThrottleLimit $Workers | Where-Object { $_ } | Sort-Object { [version]$_.IP }

if ($results.Count -eq 0) {
    Write-Host "No live hosts found." -ForegroundColor Yellow
} else {
    foreach ($r in $results) {
        $hostSuffix = if ($r.Hostname) { " ($($r.Hostname))" } else { '' }
        Write-Host ("  {0,-18} {1,4}ms{2}" -f $r.IP, $r.RTT, $hostSuffix) -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Scan complete. " -NoNewline
Write-Host "$($results.Count) host(s) alive" -ForegroundColor Green -NoNewline
Write-Host " out of 254."
