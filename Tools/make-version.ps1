# Generates Resources\SSHSnippetsKeeperVersion.rc from version.txt + git.
# Invoked as PreBuildEvent from SSHSnippetsKeeper.dproj (IDE and msbuild alike).
# Build number = total git commit count; ProductVersion also carries the short
# hash, build date and configuration, so a bug report maps to one exact commit.
param(
    [string]$ProjectDir,
    [string]$Config = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectDir)) {
    # Default: project root = parent of this script folder (Tools\)
    $ProjectDir = Split-Path -Parent $PSScriptRoot
}
$ProjectDir = [System.IO.Path]::GetFullPath($ProjectDir)

$versionFile = Join-Path $ProjectDir 'version.txt'
if (-not (Test-Path -LiteralPath $versionFile)) {
    throw "version.txt not found: $versionFile"
}

$semver = ''
foreach ($line in Get-Content -LiteralPath $versionFile) {
    $t = $line.Trim()
    if ($t -ne '' -and -not $t.StartsWith('#')) { $semver = $t; break }
}

$m = [regex]::Match($semver, '^(\d+)\.(\d+)\.(\d+)$')
if (-not $m.Success) {
    throw "version.txt must contain MAJOR.MINOR.PATCH (for example 1.4.2), got: '$semver'"
}
$maj = $m.Groups[1].Value
$min = $m.Groups[2].Value
$pat = $m.Groups[3].Value

# Build number = commit count (monotonic, deterministic, works without the IDE).
$build = 0
$hash = 'nongit'
try {
    $out = & git -C $ProjectDir rev-list --count HEAD
    if ($LASTEXITCODE -eq 0 -and $out) { $build = [int]$out }
    $out = & git -C $ProjectDir rev-parse --short HEAD
    if ($LASTEXITCODE -eq 0 -and $out) { $hash = ([string]$out).Trim() }
} catch { }

$date = Get-Date -Format 'yyyy-MM-dd'
$flags = '0x0L'
$mode = ''
if ($Config -match 'Debug') {
    $flags = '0x1L' # VS_FF_DEBUG
    $mode = ', Debug'
}

$productVersion = "$maj.$min.$pat.$build ($hash, $date$mode)"

$rc = @"
// SSHSnippetsKeeper VERSIONINFO resource.
// Generated automatically by Tools\make-version.ps1 from version.txt and git. DO NOT EDIT.
1 VERSIONINFO
FILEVERSION $maj,$min,$pat,$build
PRODUCTVERSION $maj,$min,$pat,$build
FILEOS 0x4L
FILETYPE 0x1L
FILEFLAGSMASK 0x3fL
FILEFLAGS $flags
BEGIN
  BLOCK "StringFileInfo"
  BEGIN
    BLOCK "040904B0"
    BEGIN
      VALUE "CompanyName", "iamtoizy\000"
      VALUE "FileDescription", "SSH Snippets Keeper\000"
      VALUE "FileVersion", "$maj.$min.$pat.$build\000"
      VALUE "InternalName", "SSHSnippetsKeeper\000"
      VALUE "LegalCopyright", "(c) iamtoizy\000"
      VALUE "OriginalFilename", "SSHSnippetsKeeper.exe\000"
      VALUE "ProductName", "SSH Snippets Keeper\000"
      VALUE "ProductVersion", "$productVersion\000"
    END
  END
  BLOCK "VarFileInfo"
  BEGIN
    VALUE "Translation", 0x0409, 1200
  END
END
"@

$rcFile = Join-Path $ProjectDir 'Resources\SSHSnippetsKeeperVersion.rc'
[System.IO.File]::WriteAllText($rcFile, $rc, [System.Text.Encoding]::ASCII)
Write-Host "make-version: FileVersion $maj.$min.$pat.$build, ProductVersion '$productVersion' -> $rcFile"
