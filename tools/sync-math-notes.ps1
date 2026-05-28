param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

$repoRootFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
$logDir = Join-Path $repoRootFull '.sync'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path $logDir 'auto-push.log'

function Write-Log {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}

try {
    Write-Log 'sync started'

    & (Join-Path $PSScriptRoot 'normalize-image-links.ps1') -RepoRoot $repoRootFull

    $status = git -C $repoRootFull status --porcelain
    if ([string]::IsNullOrWhiteSpace(($status -join "`n"))) {
        Write-Log 'no changes'
        exit 0
    }

    git -C $repoRootFull add -A
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    git -C $repoRootFull commit -m "chore: auto-sync math notes $timestamp"
    git -C $repoRootFull pull --rebase origin main
    git -C $repoRootFull push origin main

    Write-Log 'sync completed'
} catch {
    Write-Log ("sync failed: {0}" -f $_.Exception.Message)
    throw
}

