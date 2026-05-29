param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$VisibleWorker
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
[Console]::InputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom
$GitNetworkArgs = @('-c', 'http.sslBackend=schannel', '-c', 'http.version=HTTP/1.1')

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

    Write-Log 'changes detected; syncing in background'

    git @GitNetworkArgs -C $repoRootFull add -A
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    git @GitNetworkArgs -C $repoRootFull commit -m "chore: auto-sync math notes $timestamp"
    git @GitNetworkArgs -C $repoRootFull pull --rebase origin main
    git @GitNetworkArgs -C $repoRootFull push origin main
    $commit = git -C $repoRootFull rev-parse --short HEAD

    Write-Log ("sync completed: {0}" -f $commit)
} catch {
    Write-Log ("sync failed: {0}" -f $_.Exception.Message)
    throw
}
