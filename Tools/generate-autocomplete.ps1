# Generates Assets\ExeData\autocomplete.json
# "bash" section is reused from the existing autocomplete.json
# (or migrated from the legacy bash.autocomplete.json on first run).
# "bat" and "powershell" sections are collected from the local system:
#   - flat command lists: cmd /c help + CMD internals, Get-Command cmdlets
#   - command trees: subcommands of locally installed external tools parsed
#     from "--help" output, plus PowerShell-native chains
#     (Import-Module -> installed modules, Set-ExecutionPolicy -> policies)
# Frequent commands get common parameters appended to their insert text
# (-y for package managers, -e --id for winget) applied to all sections.
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

# --- 1. bash section: reuse the whole object from current file or legacy ---
$bashSectionObj = $null
if (Test-Path -LiteralPath $newPath) {
    $bashSectionObj = (Get-Content -LiteralPath $newPath -Raw | ConvertFrom-Json).bash
}
elseif (Test-Path -LiteralPath $oldPath) {
    # Legacy single-language format: completion lives at the root
    $bashSectionObj = Get-Content -LiteralPath $oldPath -Raw | ConvertFrom-Json
}
if (-not $bashSectionObj -or -not $bashSectionObj.completion) {
    throw "No bash source: no completion section in $newPath or $oldPath"
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
        # insert - только слово: SynCompletionProposal заменяет им
        # текущее частичное слово в строке
        $children += '"' + $se + '":{"insert":"' + $se + ' "}'
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
        # insert - только слово (см. комментарий в Build-ToolTree)
        $children += '"' + $se + '":{"insert":"' + $se + ' "}'
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

$batTreeObj = '{' + ($batTreeParts -join ',') + '}' | ConvertFrom-Json
$psTreeObj  = '{' + ($psTreeParts -join ',')  + '}' | ConvertFrom-Json

# --- 5. frequent-command parameters appended to insert text ---
$insertArgs = @{
    'apt install'         = '-y '; 'apt-get install'    = '-y '
    'apt remove'          = '-y '; 'apt-get remove'     = '-y '
    'apt upgrade'         = '-y '; 'apt-get upgrade'    = '-y '
    'apt autoremove'      = '-y '; 'apt-get autoremove' = '-y '
    'dnf install'         = '-y '; 'yum install'        = '-y '
    'dnf remove'          = '-y '; 'yum remove'         = '-y '
    'choco install'       = '-y '; 'choco upgrade'      = '-y '
    'choco uninstall'     = '-y '
    'winget install'      = '-e --id '; 'winget uninstall' = '-e --id '
}

# Recursively appends the mapped parameters to node insert texts
# ("install" -> "install -y " under the apt path). Skips nodes that
# already end with the parameters.
function Add-InsertArgs([object]$Tree, [string]$Prefix) {
    if (-not $Tree) { return }
    foreach ($prop in $Tree.PSObject.Properties) {
        $node = $prop.Value
        $path = if ($Prefix) { "$Prefix $($prop.Name)" } else { $prop.Name }
        $key = $path.ToLowerInvariant()
        if ($node.PSObject.Properties['insert'] -and $insertArgs.ContainsKey($key)) {
            $extra = $insertArgs[$key].Trim()
            $ins = ([string]$node.insert).Trim()
            if (-not $ins.ToLowerInvariant().EndsWith($extra.ToLowerInvariant())) {
                $node.insert = "$ins $extra "
            }
        }
        if ($node.PSObject.Properties['children']) {
            Add-InsertArgs $node.children $path
        }
    }
}

Add-InsertArgs $bashSectionObj.completion.tree ''
Add-InsertArgs $batTreeObj ''
Add-InsertArgs $psTreeObj ''

# --- 6. assemble the file ---
if ($batCmds.Count -lt 50) { throw "Too few CMD commands: $($batCmds.Count)" }
if ($psCmds.Count -lt 200) { throw "Too few PowerShell cmdlets: $($psCmds.Count)" }

$batCompletion = [ordered]@{ commands = $batCmds }
if ($batTreeObj) { $batCompletion.tree = $batTreeObj }
$psCompletion = [ordered]@{ commands = $psCmds }
if ($psTreeObj) { $psCompletion.tree = $psTreeObj }

$root = [ordered]@{
    version    = 2
    bash       = $bashSectionObj
    bat        = [ordered]@{ completion = $batCompletion }
    powershell = [ordered]@{ completion = $psCompletion }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($newPath, ($root | ConvertTo-Json -Depth 32), $utf8NoBom)

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
