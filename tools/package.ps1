# Builds dist\DustyThready-<version>.zip locally, the same way the packagers do (see .pkgmeta):
# one "DustyThready" folder, without docs/tools/README/CLAUDE.md/icon-source.jpg,
# and with @project-version@ in the toc replaced by the latest git tag.
# Usage (from the repository root):  powershell -ExecutionPolicy Bypass -File tools\package.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$git = 'C:\Program Files\Git\cmd\git.exe'
if (-not (Test-Path $git)) { $git = 'git' }

$version = (& $git -C $root describe --tags --always 2>$null)
if (-not $version) { $version = 'dev' }
$version = $version.Trim()

$ignore = @('.git', '.github', 'docs', 'tools', 'dist', 'README.md', 'CLAUDE.md', '.pkgmeta', '.gitignore', '.gitattributes')
$dist = Join-Path $root 'dist'
$stage = Join-Path $dist 'stage'
$out = Join-Path $stage 'DustyThready'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null

Get-ChildItem $root -Force | Where-Object { $ignore -notcontains $_.Name } | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $out $_.Name) -Recurse
}
Remove-Item (Join-Path $out 'Media\icon-source.jpg') -ErrorAction SilentlyContinue

$toc = Join-Path $out 'DustyThready.toc'
$enc = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText($toc, [IO.File]::ReadAllText($toc, $enc).Replace('@project-version@', $version), $enc)

$zip = Join-Path $dist "DustyThready-$version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $out -DestinationPath $zip
Remove-Item $stage -Recurse -Force
Write-Host "Built $zip"
