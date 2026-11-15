<#
.SYNOPSIS
  Builds a Project Inventory release (D-135). Dry run by default.

.DESCRIPTION
  1. Checks: git working tree clean, on branch main, unit tests green (D-136).
  2. Checks that the version matches in RSK.Core.VERSION (Bootstrap.lua), 42/mod.info (modversion)
     and CHANGELOG.md ("## [X.Y.Z]" heading), and that it is not a -dev version.
  3. Builds build/Workshop/ProjectInventory/Contents/mods/ProjectInventory/ with 42/ and common/,
     without the in-game tests and widget gallery (RSK/Tests, D-41), plus LICENSE.
  4. Zips the mod folder to build/ProjectInventory-vX.Y.Z.zip.
  5. With -Publish only: creates the annotated tag vX.Y.Z and pushes it.

.EXAMPLE
  powershell -File tools/release.ps1 -Version 0.2.0            # dry run: checks + build
  powershell -File tools/release.ps1 -Version 0.2.0 -Publish   # also tags and pushes
  powershell -File tools/release.ps1 -Version 0.2.0 -SkipGit   # build only, ignore git state
#>
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [switch]$Publish,
    [switch]$SkipGit
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$git = 'C:\Program Files\Git\cmd\git.exe'
if (-not (Test-Path $git)) { $git = 'git' }
$tag = "v$Version"
$errors = @()

function Step($msg) { Write-Host "== $msg" -ForegroundColor Cyan }

# ---------------------------------------------------------------- 1. git and tests
if (-not $SkipGit) {
    Step 'Git state'
    $branch = (& $git rev-parse --abbrev-ref HEAD).Trim()
    if ($branch -ne 'main') { $errors += "not on main (on '$branch')" }
    $dirty = & $git status --porcelain
    if ($dirty) { $errors += 'working tree not clean: commit or stash first' }
    if (& $git tag --list $tag) { $errors += "tag $tag already exists" }
}

Step 'Unit tests'
$out = & python tests/run_unit.py 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -or $out -match 'FAIL ') { $errors += 'unit tests failing (python tests/run_unit.py)' }
else { Write-Host ("   " + ([regex]::Matches($out, 'PASS ')).Count + ' passed') }

# ---------------------------------------------------------------- 2. versions
Step "Version $Version"
$boot = Get-Content '42/media/lua/client/RSK/Core/Bootstrap.lua' -Raw
if ($boot -notmatch 'K\.VERSION\s*=\s*"([^"]+)"') { $errors += 'K.VERSION not found in Bootstrap.lua' }
elseif ($Matches[1] -ne $Version) { $errors += "Bootstrap.lua K.VERSION is '$($Matches[1])'" }
$info = Get-Content '42/mod.info' -Raw
if ($info -notmatch '(?m)^modversion=(.+?)\s*$') { $errors += 'modversion missing in 42/mod.info' }
elseif ($Matches[1] -ne $Version) { $errors += "42/mod.info modversion is '$($Matches[1])'" }
$log = Get-Content 'CHANGELOG.md' -Raw
if ($log -notmatch ('(?m)^## \[' + [regex]::Escape($Version) + '\]')) { $errors += "CHANGELOG.md has no '## [$Version]' section" }
if ($log -match '(?m)^## \[[^\]]*-dev\]') { $errors += 'CHANGELOG.md still has a -dev section' }
if ($info -notmatch '(?m)^poster=') { Write-Host '   warning: no poster= in mod.info (needed for the Workshop)' -ForegroundColor Yellow }

if ($errors.Count) {
    $errors | ForEach-Object { Write-Host "   ERROR: $_" -ForegroundColor Red }
    if (-not $SkipGit -or $Publish) { exit 1 }
    Write-Host '   continuing because of -SkipGit (build only)' -ForegroundColor Yellow
}

# ---------------------------------------------------------------- 3. build
Step 'Build'
$build = Join-Path $root 'build'
$modDir = Join-Path $build 'Workshop/ProjectInventory/Contents/mods/ProjectInventory'
if (Test-Path $build) { Remove-Item $build -Recurse -Force }
New-Item -ItemType Directory -Force $modDir | Out-Null
robocopy 42 (Join-Path $modDir '42') /MIR /XD (Join-Path $root '42/media/lua/client/RSK/Tests') /NJH /NJS /NFL /NDL | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy 42 failed ($LASTEXITCODE)" }
robocopy common (Join-Path $modDir 'common') /MIR /NJH /NJS /NFL /NDL | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy common failed ($LASTEXITCODE)" }
Copy-Item LICENSE $modDir
$left = Get-ChildItem $modDir -Recurse -File | Where-Object { $_.FullName -match '\\RSK\\Tests\\' }
if ($left) { throw 'test files left in the build' }
$n = (Get-ChildItem $modDir -Recurse -File).Count
Write-Host "   $n files in $modDir"

# ---------------------------------------------------------------- 4. zip
$zip = Join-Path $build "ProjectInventory-$tag.zip"
Compress-Archive -Path $modDir -DestinationPath $zip -Force
Write-Host "   $zip"

# ---------------------------------------------------------------- 5. tag
if ($Publish) {
    Step "Tag $tag"
    & $git tag -a $tag -m "Project Inventory $Version"
    & $git push origin $tag
    Write-Host "   pushed $tag"
} else {
    Write-Host "Dry run: no tag created. Re-run with -Publish to tag and push $tag." -ForegroundColor Yellow
}
