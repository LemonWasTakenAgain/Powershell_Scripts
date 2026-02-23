#Requires -Version 5.1
<#
.SYNOPSIS
    Check SSL/TLS certificate expiry for one or more domains.
.PARAMETER Domains
    Array of domains (optionally with :port) to check.
.PARAMETER WarnDays
    Warn if expiring within this many days. Default: 30.
.PARAMETER CritDays
    Critical if expiring within this many days. Default: 7.
.EXAMPLE
    .\Test-SslExpiry.ps1 -Domains google.com,github.com
.EXAMPLE
    .\Test-SslExpiry.ps1 -Domains myapp.internal:8443
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Domains,
    [int]$WarnDays = 30,
    [int]$CritDays = 7
)

function Get-CertExpiry {
    param([string]$Hostname, [int]$Port = 443)
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient($Hostname, $Port)
        $callback  = { $true }
        $ssl       = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, $callback)
        $ssl.AuthenticateAsClient($Hostname)
        $cert      = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($ssl.RemoteCertificate)
        $ssl.Close(); $tcpClient.Close()
        return $cert
    } catch {
        return $null
    }
}

Write-Host "`nSSL Certificate Expiry Check  (warn=${WarnDays}d, crit=${CritDays}d)`n" -ForegroundColor Cyan
Write-Host ("{0,-12} {1,-35} {2,-8} {3}" -f "Status", "Host:Port", "Days", "Expires")
Write-Host ("-" * 80)

foreach ($domain in $Domains) {
    $parts    = $domain.Split(':')
    $hostname = $parts[0]
    $port     = if ($parts.Count -gt 1) { [int]$parts[1] } else { 443 }

    $cert = Get-CertExpiry -Hostname $hostname -Port $port

    if (-not $cert) {
        Write-Host ("{0,-12} {1,-35} {2}" -f "FAILED", "${hostname}:${port}", "Could not retrieve certificate") -ForegroundColor Red
        continue
    }

    $expiry    = $cert.NotAfter
    $daysLeft  = ([int]($expiry - (Get-Date)).TotalDays)
    $issuer    = ($cert.Issuer -split ',')[0] -replace 'CN=', ''

    $status = switch ($true) {
        ($daysLeft -le 0)        { 'EXPIRED'; break }
        ($daysLeft -le $CritDays) { 'CRITICAL'; break }
        ($daysLeft -le $WarnDays) { 'EXPIRING'; break }
        default                  { 'OK' }
    }

    $color = switch ($status) {
        'OK'       { 'Green' }
        'EXPIRING' { 'Yellow' }
        default    { 'Red' }
    }

    Write-Host ("{0,-12} {1,-35} {2,5}d   {3}   [{4}]" -f $status, "${hostname}:${port}", $daysLeft, $expiry.ToString('yyyy-MM-dd'), $issuer) -ForegroundColor $color
}

Write-Host ""
