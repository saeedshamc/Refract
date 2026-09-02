# Package Prism Echo for Windows (standalone .exe)
# Requires: LÖVE installed at "C:\Program Files\LOVE\love.exe"
# Output:  dist\PrismEcho.exe

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Dist = Join-Path $Root "dist"
$LoveExe = "C:\Program Files\LOVE\love.exe"

if (-not (Test-Path $LoveExe)) {
    $LoveExe = "C:\Program Files (x86)\LOVE\love.exe"
}
if (-not (Test-Path $LoveExe)) {
    Write-Error "love.exe not found. Install LÖVE from https://love2d.org/"
}

New-Item -ItemType Directory -Force -Path $Dist | Out-Null
$LoveFile = Join-Path $Dist "PrismEcho.love"
$OutExe   = Join-Path $Dist "PrismEcho.exe"
$ZipTemp  = Join-Path $Dist "_pack.zip"

$Include = @(
    "main.lua", "grid.lua", "entities.lua", "raytracer.lua",
    "level.lua", "ui.lua", "lever.lua", "levelgen.lua", "storage.lua",
    "levels", "assets"
)

$Temp = Join-Path $Dist "_staging"
if (Test-Path $Temp) { Remove-Item $Temp -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Temp | Out-Null

foreach ($item in $Include) {
    $src = Join-Path $Root $item
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $Temp $item) -Recurse -Force
    }
}

if (Test-Path $ZipTemp) { Remove-Item $ZipTemp -Force }
if (Test-Path $LoveFile) { Remove-Item $LoveFile -Force }
Compress-Archive -Path "$Temp\*" -DestinationPath $ZipTemp -Force
Move-Item $ZipTemp $LoveFile -Force
Remove-Item $Temp -Recurse -Force

if (Test-Path $OutExe) { Remove-Item $OutExe -Force }
cmd /c copy /b `"$LoveExe`"+`"$LoveFile`" `"$OutExe`"

Write-Host ""
Write-Host "Done! Standalone Windows build:"
Write-Host "  $OutExe"
Write-Host ""
Write-Host "Distribute PrismEcho.exe — players do not need LÖVE installed."
