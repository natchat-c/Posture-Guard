param(
    [string]$SourceIcon = (Join-Path $PSScriptRoot '..\images\app icon\app icon.png')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$resourceRoot = Join-Path $projectRoot 'android\app\src\main\res'
$sourcePath = (Resolve-Path $SourceIcon).Path
$sourceBitmap = [System.Drawing.Bitmap]::new($sourcePath)

function New-Graphics([System.Drawing.Bitmap]$bitmap) {
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    return $graphics
}

function New-RoundedPath([int]$size) {
    $diameter = [int][Math]::Round($size * 0.5)
    $offset = $size - $diameter
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddArc(0, 0, $diameter, $diameter, 180, 90)
    $path.AddArc($offset, 0, $diameter, $diameter, 270, 90)
    $path.AddArc($offset, $offset, $diameter, $diameter, 0, 90)
    $path.AddArc(0, $offset, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Save-LegacyIcon([string]$path, [int]$size, [bool]$round) {
    $bitmap = [System.Drawing.Bitmap]::new(
        $size,
        $size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = New-Graphics $bitmap
    $clipPath = if ($round) {
        $ellipse = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $ellipse.AddEllipse(0, 0, $size, $size)
        $ellipse
    } else {
        New-RoundedPath $size
    }
    $graphics.SetClip($clipPath)
    $graphics.DrawImage($sourceBitmap, 0, 0, $size, $size)
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $clipPath.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

function Save-AdaptiveForeground([string]$path, [int]$size) {
    $bitmap = [System.Drawing.Bitmap]::new(
        $size,
        $size,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = New-Graphics $bitmap
    $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
    $attributes.SetColorKey(
        [System.Drawing.Color]::FromArgb(230, 220, 215),
        [System.Drawing.Color]::FromArgb(255, 255, 255)
    )

    # Crop only the approved icon's slime. The 64/108 width keeps all core
    # artwork inside Android's adaptive-icon safe zone under circle/squircle
    # masks; the source's branding text remains on legacy and round icons.
    $sourceRect = [System.Drawing.Rectangle]::new(270, 265, 714, 590)
    $contentWidth = [int][Math]::Round($size * (64.0 / 108.0))
    $contentHeight = [int][Math]::Round(
        $contentWidth * ($sourceRect.Height / $sourceRect.Width)
    )
    $destinationRect = [System.Drawing.Rectangle]::new(
        [int](($size - $contentWidth) / 2),
        [int](($size - $contentHeight) / 2),
        $contentWidth,
        $contentHeight
    )
    $graphics.DrawImage(
        $sourceBitmap,
        $destinationRect,
        $sourceRect.X,
        $sourceRect.Y,
        $sourceRect.Width,
        $sourceRect.Height,
        [System.Drawing.GraphicsUnit]::Pixel,
        $attributes
    )
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $attributes.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

$densities = [ordered]@{
    'mipmap-mdpi' = 1.0
    'mipmap-hdpi' = 1.5
    'mipmap-xhdpi' = 2.0
    'mipmap-xxhdpi' = 3.0
    'mipmap-xxxhdpi' = 4.0
}

foreach ($entry in $densities.GetEnumerator()) {
    $directory = Join-Path $resourceRoot $entry.Key
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    $legacySize = [int][Math]::Round(48 * $entry.Value)
    $foregroundSize = [int][Math]::Round(108 * $entry.Value)
    Save-LegacyIcon (Join-Path $directory 'ic_launcher.png') $legacySize $false
    Save-LegacyIcon (Join-Path $directory 'ic_launcher_round.png') $legacySize $true
    Save-AdaptiveForeground (
        Join-Path $directory 'ic_launcher_foreground.png'
    ) $foregroundSize
}

$sourceBitmap.Dispose()
Write-Output "Generated Android launcher resources from: $sourcePath"
