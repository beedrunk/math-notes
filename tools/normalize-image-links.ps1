param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$OwnerRepo = 'beedrunk/math-notes',
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'

function ConvertTo-RawUrl {
    param([string]$RelativePath)

    $segments = ($RelativePath -replace '\\', '/') -split '/'
    $encoded = $segments | ForEach-Object { [System.Uri]::EscapeDataString($_) }
    return "https://raw.githubusercontent.com/$OwnerRepo/$Branch/$($encoded -join '/')"
}

function Test-IsInsidePath {
    param(
        [string]$BasePath,
        [string]$ChildPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'
    $child = [System.IO.Path]::GetFullPath($ChildPath)
    return $child.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-UniquePath {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $Path
    }

    $dir = Split-Path -Parent $Path
    $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $ext = [System.IO.Path]::GetExtension($Path)
    $i = 2
    do {
        $candidate = Join-Path $dir ("{0}-{1}{2}" -f $name, $i, $ext)
        $i++
    } while (Test-Path -LiteralPath $candidate)

    return $candidate
}

$repoRootFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
$assetsRoot = Join-Path $repoRootFull 'assets'
$imageExts = @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg')

Get-ChildItem -LiteralPath $repoRootFull -Recurse -File -Filter '*.md' |
    Where-Object { $_.FullName -notmatch '\\\.git\\' } |
    ForEach-Object {
        $mdFile = $_
        $content = Get-Content -LiteralPath $mdFile.FullName -Raw

        $updated = [regex]::Replace(
            $content,
            '!\[(?<alt>[^\]]*)\]\((?<url>[^)]+)\)',
            {
                param($match)

                $alt = $match.Groups['alt'].Value
                $url = $match.Groups['url'].Value.Trim()

                if ($url -match '^(https?:|data:|mailto:|#)') {
                    return $match.Value
                }

                $cleanUrl = $url.Trim('"').Trim("'")
                $withoutAnchor = ($cleanUrl -split '#', 2)[0]
                $withoutQuery = ($withoutAnchor -split '\?', 2)[0]
                $decoded = [System.Uri]::UnescapeDataString($withoutQuery)
                $ext = [System.IO.Path]::GetExtension($decoded).ToLowerInvariant()

                if ($imageExts -notcontains $ext) {
                    return $match.Value
                }

                if ([System.IO.Path]::IsPathRooted($decoded)) {
                    $imagePath = [System.IO.Path]::GetFullPath($decoded)
                } else {
                    $imagePath = [System.IO.Path]::GetFullPath((Join-Path $mdFile.DirectoryName $decoded))
                }

                if (-not (Test-Path -LiteralPath $imagePath)) {
                    return $match.Value
                }

                if (-not (Test-IsInsidePath -BasePath $repoRootFull -ChildPath $imagePath)) {
                    return $match.Value
                }

                $finalPath = $imagePath
                if (-not (Test-IsInsidePath -BasePath $assetsRoot -ChildPath $imagePath)) {
                    $mdRelativeDir = [System.IO.Path]::GetRelativePath($repoRootFull, $mdFile.DirectoryName)
                    $subject = ($mdRelativeDir -replace '\\', '/') -split '/' | Select-Object -First 1
                    if ([string]::IsNullOrWhiteSpace($subject) -or $subject -eq '.') {
                        $subject = 'misc'
                    }

                    $docName = [System.IO.Path]::GetFileNameWithoutExtension($mdFile.Name)
                    $destDir = Join-Path $assetsRoot (Join-Path $subject $docName)
                    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
                    $destPath = Get-UniquePath (Join-Path $destDir ([System.IO.Path]::GetFileName($imagePath)))
                    Move-Item -LiteralPath $imagePath -Destination $destPath
                    $finalPath = $destPath
                }

                $relative = [System.IO.Path]::GetRelativePath($repoRootFull, $finalPath)
                return "![${alt}]($(ConvertTo-RawUrl -RelativePath $relative))"
            }
        )

        if ($updated -ne $content) {
            Set-Content -LiteralPath $mdFile.FullName -Value $updated -Encoding UTF8
        }
    }

