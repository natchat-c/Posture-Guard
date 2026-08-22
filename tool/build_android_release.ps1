[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SymbolDirectory,

    [switch]$BuildUniversalApk
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$symbolPath = if ([IO.Path]::IsPathRooted($SymbolDirectory)) {
    [IO.Path]::GetFullPath($SymbolDirectory)
} else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $SymbolDirectory))
}
$transientBuildRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build'))

if ($symbolPath.Equals(
        $transientBuildRoot,
        [StringComparison]::OrdinalIgnoreCase
    ) -or $symbolPath.StartsWith(
        $transientBuildRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )) {
    throw 'SymbolDirectory must be outside build/ so flutter clean cannot delete release symbols.'
}

New-Item -ItemType Directory -Force -Path $symbolPath | Out-Null
Push-Location $projectRoot
try {
    & flutter build appbundle --release "--split-debug-info=$symbolPath"
    if ($LASTEXITCODE -ne 0) {
        throw "AAB build failed with exit code $LASTEXITCODE."
    }

    if ($BuildUniversalApk) {
        & flutter build apk --release "--split-debug-info=$symbolPath"
        if ($LASTEXITCODE -ne 0) {
            throw "APK build failed with exit code $LASTEXITCODE."
        }
    }
} finally {
    Pop-Location
}

$symbols = @(Get-ChildItem -LiteralPath $symbolPath -Recurse -File)
if ($symbols.Count -eq 0) {
    throw "Release completed but no symbol files were found in $symbolPath."
}

Write-Host "Release symbols retained in $symbolPath"
$symbols | Select-Object FullName, Length
