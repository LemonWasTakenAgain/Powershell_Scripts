#Requires -Version 5.1
<#
.SYNOPSIS
    Pull all git repositories found under a root directory.
.PARAMETER RootPath
    Directory to search for git repos. Default: current directory.
.PARAMETER Depth
    How many levels deep to scan. Default: 3.
.EXAMPLE
    .\Invoke-PullAll.ps1
.EXAMPLE
    .\Invoke-PullAll.ps1 -RootPath C:\Projects -Depth 4
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Get-Location).Path,
    [int]$Depth = 3
)

$updated  = 0; $clean = 0; $skipped = 0; $failed = 0

Write-Host "`nScanning for git repos under: $RootPath`n" -ForegroundColor Cyan

$gitDirs = Get-ChildItem -Path $RootPath -Recurse -Depth $Depth -Directory -Filter '.git' -Force -ErrorAction SilentlyContinue

foreach ($gitDir in $gitDirs) {
    $repo   = $gitDir.Parent.FullName
    $name   = $repo.Replace($RootPath, '').TrimStart('\', '/')

    Push-Location $repo
    try {
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if (-not $branch -or $branch -eq 'HEAD') {
            Write-Host ("  {0,-5} {1}" -f "SKIP", $name) -ForegroundColor Yellow
            $skipped++; continue
        }

        # Check for uncommitted changes
        $dirty = git status --porcelain 2>$null
        if ($dirty) {
            Write-Host ("  {0,-5} {1} ($branch) — dirty, skipping" -f "DIRTY", $name) -ForegroundColor Yellow
            $skipped++; continue
        }

        # Check if remote origin exists
        $remote = git remote get-url origin 2>$null
        if (-not $remote) {
            Write-Host ("  {0,-5} {1} — no remote" -f "SKIP", $name) -ForegroundColor DarkGray
            $skipped++; continue
        }

        $output = git pull --ff-only 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host ("  {0,-5} {1} ($branch)" -f "FAIL", $name) -ForegroundColor Red
            $failed++
        } elseif ($output -match 'Already up to date') {
            Write-Host ("  {0,-5} {1} ($branch)" -f "OK", $name) -ForegroundColor Green
            $clean++
        } else {
            Write-Host ("  {0,-5} {1} ($branch)" -f "PULL", $name) -ForegroundColor Cyan
            $updated++
        }
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Done.  " -NoNewline
Write-Host "$updated updated  " -ForegroundColor Cyan -NoNewline
Write-Host "$clean up-to-date  " -ForegroundColor Green -NoNewline
Write-Host "$skipped skipped  " -ForegroundColor Yellow -NoNewline
Write-Host "$failed failed" -ForegroundColor Red
