#Requires -Version 5.1
<#
.SYNOPSIS
    List all local administrator accounts and group memberships.
.DESCRIPTION
    Audits local Administrator accounts, the Administrators group,
    and flags suspicious or unexpected members.
.EXAMPLE
    .\Get-LocalAdmins.ps1
#>

[CmdletBinding()]
param()

Write-Host "`n=== Local Administrator Audit: $env:COMPUTERNAME ===" -ForegroundColor Cyan

Write-Host "`nAdministrators Group Members:" -ForegroundColor White
try {
    $admins = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop
    foreach ($m in $admins) {
        $type  = $m.PrincipalSource
        $color = switch ($m.ObjectClass) {
            'User'  { 'Yellow' }
            'Group' { 'Cyan' }
            default { 'Gray' }
        }
        Write-Host ("  [{0,-6}] {1,-40} ({2})" -f $m.ObjectClass, $m.Name, $type) -ForegroundColor $color
    }
} catch {
    Write-Host "  Unable to enumerate local group: $_" -ForegroundColor Red
}

Write-Host "`nLocal User Accounts:" -ForegroundColor White
Get-LocalUser | ForEach-Object {
    $enabled  = if ($_.Enabled) { 'Enabled ' } else { 'Disabled' }
    $lastLogin = if ($_.LastLogon) { $_.LastLogon.ToString('yyyy-MM-dd') } else { 'Never' }
    $color    = if ($_.Enabled) { 'White' } else { 'DarkGray' }
    Write-Host ("  {0,-8} {1,-25} Last login: {2}" -f $enabled, $_.Name, $lastLogin) -ForegroundColor $color
}

Write-Host "`nPassword Policy:" -ForegroundColor White
try {
    $policy = net accounts 2>$null
    $policy | Where-Object { $_ -match 'password|lockout|history' } | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Unable to retrieve password policy." -ForegroundColor Yellow
}

Write-Host "`nRecent Logon Events (Security Log, last 20):" -ForegroundColor White
try {
    Get-WinEvent -FilterHashtable @{ LogName='Security'; Id=4624; StartTime=(Get-Date).AddDays(-7) } `
        -MaxEvents 20 -ErrorAction Stop |
        ForEach-Object {
            $xml  = [xml]$_.ToXml()
            $user = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'TargetUserName' }).'#text'
            $type = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'LogonType' }).'#text'
            $ip   = ($xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' }).'#text'
            Write-Host ("  {0}  User={1,-20} Type={2,-3} IP={3}" -f $_.TimeCreated.ToString('yyyy-MM-dd HH:mm'), $user, $type, $ip)
        }
} catch {
    Write-Host "  Unable to read Security event log (run as Administrator)." -ForegroundColor Yellow
}

Write-Host ""
