# Builds dist\DustyThready-<version>.zip, ready to upload to CurseForge / Wago / GitHub.
# The zip contains a single "DustyThready" folder, which is what players drop into Interface\AddOns.
# Usage (from the repository root):  powershell -ExecutionPolicy Bypass -File tools\package.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'DustyThready'
$toc = Get-Content (Join-Path $addon 'DustyThready.toc')
$version = ($toc | Where-Object { $_ -match '^## Version:\s*(.+)$' } | ForEach-Object { $Matches[1].Trim() }) | Select-Object -First 1
if (-not $version) { throw 'No "## Version:" line in DustyThready.toc' }

$dist = Join-Path $root 'dist'
$stage = Join-Path $dist 'stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $stage 'DustyThready') | Out-Null

# Copy the addon, leaving out development-only files.
Copy-Item (Join-Path $addon '*') (Join-Path $stage 'DustyThready') -Recurse
Remove-Item (Join-Path $stage 'DustyThready\Media\icon-source.jpg') -ErrorAction SilentlyContinue

$zip = Join-Path $dist "DustyThready-$version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage 'DustyThready') -DestinationPath $zip
Remove-Item $stage -Recurse -Force
Write-Host "Built $zip"
