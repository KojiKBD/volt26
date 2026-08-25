param(
    [string]$OutputDirectory = ""
)

$ErrorActionPreference = "Stop"
$repository = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repository "dist"
}

$themeInfo = Get-Content -Raw (Join-Path $repository "ThemeInfo.ini")
$versionMatch = [regex]::Match($themeInfo, '(?m)^Version=(?<version>[^\r\n]+)$')
if (-not $versionMatch.Success) { throw "ThemeInfo.ini does not define Version." }
$version = $versionMatch.Groups["version"].Value.Trim()
if ($version -match 'dev') { throw "Development versions cannot be packaged as releases." }

$status = git -C $repository status --porcelain
if ($LASTEXITCODE -ne 0) { throw "Unable to inspect repository status." }
if ($status) { throw "The working tree must be clean before packaging." }

$tracked = @(git -C $repository ls-files)
$blocked = @($tracked | Where-Object {
    $_ -match '(^|/)(Save|Logs|Cache)/' -or
    $_ -match '(^|/)(GrooveStats|Preferences)\.ini$' -or
    $_ -match '(^|/)\.git/'
})
if ($blocked.Count -gt 0) {
    throw "Blocked private/runtime files are tracked: $($blocked -join ', ')"
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$archive = Join-Path $OutputDirectory "VOLT26-$version.zip"
$checksum = "$archive.sha256"
Remove-Item -LiteralPath $archive, $checksum -Force -ErrorAction SilentlyContinue

git -C $repository archive --format=zip --prefix="VOLT26/" --output=$archive HEAD
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $archive)) {
    throw "Failed to create release archive."
}

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ("VOLT26-release-" + [guid]::NewGuid())
try {
    Expand-Archive -LiteralPath $archive -DestinationPath $temporary
    foreach ($required in @("ThemeInfo.ini", "metrics.ini", "LICENSE", "Scripts", "BGAnimations", "Graphics")) {
        if (-not (Test-Path -LiteralPath (Join-Path $temporary "VOLT26/$required"))) {
            throw "Release archive is missing VOLT26/$required."
        }
    }
} finally {
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Recurse -Force
    }
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksum -Value "$hash  $(Split-Path -Leaf $archive)" -Encoding ascii

Get-Item -LiteralPath $archive, $checksum
