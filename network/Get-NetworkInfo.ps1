#Requires -Version 5.1
<#
.SYNOPSIS
    Display detailed network interface and connectivity information.
.EXAMPLE
    .\Get-NetworkInfo.ps1
#>

[CmdletBinding()]
param()

function Write-Section { Write-Host "`n=== $args ===" -ForegroundColor Cyan }

Write-Section "Network Adapters"
Get-NetAdapter | Where-Object { $_.Status -ne 'Not Present' } | ForEach-Object {
    $color = if ($_.Status -eq 'Up') { 'Green' } else { 'DarkGray' }
    Write-Host ("  {0,-28} {1,-8} {2}" -f $_.Name, $_.Status, $_.MacAddress) -ForegroundColor $color
}

Write-Section "IPv4 Addresses"
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' } | ForEach-Object {
    $adapter = (Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue).Name
    Write-Host ("  {0,-28} {1}/{2}" -f $adapter, $_.IPAddress, $_.PrefixLength)
}

Write-Section "Default Gateway & Routes"
Get-NetRoute -DestinationPrefix '0.0.0.0/0' | ForEach-Object {
    $adapter = (Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue).Name
    Write-Host ("  Gateway: {0,-18} via {1}" -f $_.NextHop, $adapter)
}

Write-Section "DNS Servers"
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses } | ForEach-Object {
    $adapter = (Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue).Name
    Write-Host ("  {0,-28} {1}" -f $adapter, ($_.ServerAddresses -join ', '))
}

Write-Section "External IP"
try {
    $extIp = (Invoke-RestMethod -Uri 'https://ifconfig.me' -TimeoutSec 5 -ErrorAction Stop)
    Write-Host "  $extIp"
} catch {
    Write-Host "  Unable to reach external IP service" -ForegroundColor Yellow
}

Write-Section "Connectivity Check"
foreach ($host in @('1.1.1.1', '8.8.8.8', 'google.com', 'github.com')) {
    $result = Test-Connection -ComputerName $host -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($result) {
        $ping = (Test-Connection -ComputerName $host -Count 1 -ErrorAction SilentlyContinue).Latency
        Write-Host ("  {0,-18} {1,6}ms" -f $host, $ping) -ForegroundColor Green
    } else {
        Write-Host ("  {0,-18} FAILED" -f $host) -ForegroundColor Red
    }
}

Write-Section "Listening Ports"
Get-NetTCPConnection -State Listen |
    Sort-Object LocalPort |
    Select-Object -First 20 |
    ForEach-Object {
        $proc = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).Name
        Write-Host ("  {0,-22} {1}" -f "0.0.0.0:$($_.LocalPort)", $proc)
    }

Write-Host ""
