param(
    [string]$RepoPath = "C:\src\app",
    [string]$ReleaseType = "minor"
)
Push-Location $RepoPath
try {
    git fetch --tags 2>$null
    $LastTag = git describe --tags --abbrev=0 2>$null
    if (-not $LastTag) { $LastTag = "0.0.0" }
    $Parts = $LastTag.Split(".")
    $Major = [int]$Parts[0]
    $Minor = [int]$Parts[1]
    $Patch = [int]$Parts[2]
    switch ($ReleaseType) {
        "major" { $Major++; $Minor = 0; $Patch = 0 }
        "minor" { $Minor++; $Patch = 0 }
        "patch" { $Patch++ }
        default { throw "unknown release type: $ReleaseType" }
    }
    $NewVersion = "$Major.$Minor.$Patch"
    Write-Output "release: $LastTag -> $NewVersion"
    $Changes = git log "$LastTag..HEAD" --oneline
    $ChangeCount = ($Changes | Measure-Object).Count
    Write-Output "commits since last tag: $ChangeCount"
    if ($ChangeCount -eq 0) {
        Write-Warning "nothing to release"
        exit 1
    }
    $Changes | Out-File "CHANGELOG.md" -Encoding utf8
    git add CHANGELOG.md
    git commit -m "release $NewVersion" 2>$null
    git tag -a "v$NewVersion" -m "release $NewVersion"
    git push origin "v$NewVersion"
    Write-Output "tag v$NewVersion pushed"
    $Branch = git rev-parse --abbrev-ref HEAD
    Write-Output "branch: $Branch"
} finally {
    Pop-Location
}
