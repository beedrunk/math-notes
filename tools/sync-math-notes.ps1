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

    if (-not $VisibleWorker) {
        Write-Log 'changes detected; launching visible sync worker'
        $scriptPath = Join-Path $PSScriptRoot 'sync-math-notes.ps1'
        $arguments = @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $scriptPath),
            '-RepoRoot', ('"{0}"' -f $repoRootFull),
            '-VisibleWorker'
        ) -join ' '
        Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -WorkingDirectory $repoRootFull
        exit 0
    }

    git @GitNetworkArgs -C $repoRootFull add -A
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    git @GitNetworkArgs -C $repoRootFull commit -m "chore: auto-sync math notes $timestamp"
    git @GitNetworkArgs -C $repoRootFull pull --rebase origin main
    git @GitNetworkArgs -C $repoRootFull push origin main
    $commit = git -C $repoRootFull rev-parse --short HEAD

    Write-Host ("Math notes synced to GitHub. Commit: {0}" -f $commit)
    Write-Log ("sync completed: {0}" -f $commit)
    Start-Sleep -Seconds 3
} catch {
    Write-Log ("sync failed: {0}" -f $_.Exception.Message)
    throw
}
