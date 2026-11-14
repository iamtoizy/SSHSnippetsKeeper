# Generates Assets\ExeData\autocomplete.json
# "bash" section is reused verbatim from the existing autocomplete.json
# (or migrated from the legacy bash.autocomplete.json on first run).
# "bat" and "powershell" sections are collected from the local system:
#   - flat command lists: cmd /c help + CMD internals, Get-Command cmdlets
#   - command trees: subcommands of locally installed external tools parsed
#     from "--help" output, plus PowerShell-native chains
#     (Import-Module -> installed modules, Set-ExecutionPolicy -> policies)
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$assets  = Join-Path $RepoRoot 'Assets\ExeData'
$oldPath = Join-Path $assets 'bash.autocomplete.json'
$newPath = Join-Path $assets 'autocomplete.json'

function Escape-JsonString([string]$Value) {
    return $Value.Replace('\', '\\').Replace('"', '\"')
}

# --- 1. bash section: reuse from current file or wrap the legacy one ---
$bashLines = $null
if (Test-Path -LiteralPath $newPath) {
    $curLines = Get-Content -LiteralPath $newPath
    $start = -1
    for ($i = 0; $i -lt $curLines.Count; $i++) {
        if ($curLines[$i] -match '^  "bash": \{$') { $start = $i; break }
    }
    if ($start -lt 0) { throw 'bash section not found in existing autocomplete.json' }
    $end = -1
    for ($i = $start + 1; $i -lt $curLines.Count; $i++) {
        if ($curLines[$i] -match '^  \},$') { $end = $i; break }
    }
    if ($end -lt 0) { throw 'bash section end not found in existing autocomplete.json' }
    $bashLines = $curLines[$start..$end]
}
elseif (Test-Path -LiteralPath $oldPath) {
    $oldLines = Get-Content -LiteralPath $oldPath
    if ($oldLines[0].Trim() -ne '{' -or $oldLines[$oldLines.Count - 1].Trim() -ne '}') {
        throw 'Unexpected bash.autocomplete.json format: expected a JSON object'
    }
    $bashLines = @('  "bash": {')
    for ($i = 1; $i -lt $oldLines.Count - 1; $i++) {
        $bashLines += '  ' + $oldLines[$i]
    }
    $bashLines += '  },'
}
else {
    throw "No bash source: neither $newPath nor $oldPath exists"
}

# --- 2. bat/powershell flat command lists ---
$batCmds = @()
foreach ($line in (cmd /c help 2>$null)) {
    if ($line -match '^([A-Za-z][A-Za-z0-9_\.\-]*)\s{2,}') {
        $batCmds += $Matches[1].ToUpperInvariant()
    }
}
$batInternals = @(
    'BREAK','CALL','CD','CHDIR','CLS','COLOR','CTTY','DATE','ECHO','ENDLOCAL',
    'ERASE','EXIT','FOR','FTYPE','GOTO','IF','KEYS','LH','LOADHIGH','MD','MKDIR',
    'MKLINK','MOVE','PAUSE','PATH','PROMPT','RD','REM','REN','RENAME','RMDIR',
    'SET','SETLOCAL','SHIFT','START','SUBST','TIME','TITLE','TYPE','VER','VERIFY','VOL'
)
$batCmds = @($batCmds + $batInternals | Sort-Object -Unique)

$psCmds = @(Get-Command -CommandType Cmdlet -ErrorAction SilentlyContinue |
    ForEach-Object { $_.Name } | Sort-Object -Unique)

# --- 3. command trees for locally installed external tools ---
# Subcommand line pattern: two or more leading spaces, a word, then two
# or more spaces before the description ("  install     Installs a package")
$probeTools = @(
    'git','npm','pnpm','yarn','docker','podman','kubectl','helm','terraform',
    'gh','winget','choco','scoop','pip','conda','cargo','dotnet'
)

function Build-ToolTree([string]$Tool) {
    $out = & $Tool --help 2>$null
    if (-not $out -or @($out).Count -lt 3) { $out = & $Tool -h 2>$null }

    $subs = @()
    foreach ($line in @($out)) {
        if ($line -match '^\s{2,}([a-z][\w\-\.:]*)\s{2,}') {
            $subs += $Matches[1]
        }
    }
    $subs = @($subs | Sort-Object -Unique | Select-Object -First 60)
    if ($subs.Count -eq 0) { return $null }

    $t = Escape-JsonString $Tool
    $children = @()
    foreach ($s in $subs) {
        $se = Escape-JsonString $s
        $children += '"' + $se + '":{"insert":"' + $t + ' ' + $se + ' "}'
    }
    return '"' + $t + '":{"insert":"' + $t + ' ","children":{' + ($children -join ',') + '}}'
}

$batTreeParts = @()
$psTreeParts = @()
foreach ($tool in $probeTools) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
        $treePart = Build-ToolTree $tool
        if ($treePart) {
            $batTreeParts += $treePart
            $psTreeParts += $treePart
        }
    }
}

# --- 4. PowerShell-native chains ---
function Build-SimpleTree([string]$Name, [string[]]$Subs) {
    if (-not $Subs -or $Subs.Count -eq 0) { return $null }
    $n = Escape-JsonString $Name
    $children = @()
    foreach ($s in $Subs) {
        $se = Escape-JsonString $s
        $children += '"' + $se + '":{"insert":"' + $n + ' ' + $se + ' "}'
    }
    return '"' + $n + '":{"insert":"' + $n + ' ","children":{' + ($children -join ',') + '}}'
}

# Import-Module -> installed module names
$moduleNames = @(Get-Module -ListAvailable -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Name -Unique | Sort-Object -Unique)
$importTree = Build-SimpleTree 'Import-Module' $moduleNames
if ($importTree) { $psTreeParts += $importTree }

# Set-ExecutionPolicy -> execution policy values
$policyTree = Build-SimpleTree 'Set-ExecutionPolicy' @(
    'AllSigned','Bypass','Default','RemoteSigned','Restricted','Undefined','Unrestricted')
if ($policyTree) { $psTreeParts += $policyTree }

# --- 5. assemble the file ---
if ($batCmds.Count -lt 50) { throw "Too few CMD commands: $($batCmds.Count)" }
if ($psCmds.Count -lt 200) { throw "Too few PowerShell cmdlets: $($psCmds.Count)" }

function Format-CommandArray {
    param([string[]]$Names)
    $quoted = $Names | ForEach-Object { '"' + (Escape-JsonString $_) + '"' }
    return '[' + ($quoted -join ',') + ']'
}

$batText  = Format-CommandArray $batCmds
$psText   = Format-CommandArray $psCmds
$bashText = $bashLines -join "`n"
$batTree  = ($batTreeParts -join ',')
$psTree   = ($psTreeParts -join ',')

if ($batTree) {
    $batSection = '  "bat": { "completion": { "commands": ' + $batText +
        ', "tree": {' + $batTree + '} } },'
}
else {
    $batSection = '  "bat": { "completion": { "commands": ' + $batText + ' } },'
}
if ($psTree) {
    $psSection = '  "powershell": { "completion": { "commands": ' + $psText +
        ', "tree": {' + $psTree + '} } }'
}
else {
    $psSection = '  "powershell": { "completion": { "commands": ' + $psText + ' } }'
}

$json =
    "{`n" +
    "  `"version`": 2,`n" +
    $bashText + "`n" +
    $batSection + "`n" +
    $psSection + "`n" +
    '}'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($newPath, $json, $utf8NoBom)

# Sanity check: the file must parse as JSON
$parsed = Get-Content -LiteralPath $newPath -Raw | ConvertFrom-Json
$batKeys  = @($parsed.bat.completion.tree.PSObject.Properties.Name)
$psKeys   = @($parsed.powershell.completion.tree.PSObject.Properties.Name)
$bashKeys = @($parsed.bash.completion.tree.PSObject.Properties.Name)

Write-Output "OK: $newPath"
Write-Output ("bat commands: {0}, tree roots: {1}" -f $batCmds.Count, $batKeys.Count)
Write-Output ("powershell cmdlets: {0}, tree roots: {1}" -f $psCmds.Count, $psKeys.Count)
Write-Output ("bash tree roots (preserved): {0}" -f $bashKeys.Count)
Write-Output ("bat tree: {0}" -f (($batKeys | Sort-Object) -join ', '))
Write-Output ("powershell tree: {0}" -f (($psKeys | Sort-Object) -join ', '))
