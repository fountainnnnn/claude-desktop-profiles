<#
.SYNOPSIS
    Removes the "Claude N" shortcuts made by install.ps1. Logins and chats are
    kept; the script prints where they live.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\windows\uninstall.ps1        # all
    powershell -ExecutionPolicy Bypass -File scripts\windows\uninstall.ps1 -Number 3
#>
param([ValidateRange(1, 9)][int[]]$Number)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$targets = @(Get-OurShortcuts | Where-Object { -not $Number -or $Number -contains $_.Number })
if ($targets.Count -eq 0) { Write-Host 'No launchers found.'; exit 0 }

foreach ($t in $targets) { Remove-Item $t.Path -Force; Write-Host "Removed $($t.Path)" }
$removed = $targets.Number | Sort-Object -Unique
foreach ($n in $removed) { Remove-Item (Join-Path $script:InstallDir "claude$n.ico") -ErrorAction SilentlyContinue }

# Last launcher gone: remove the helper scripts too.
if (@(Get-OurShortcuts).Count -eq 0) {
    Remove-Item $script:InstallDir -Recurse -Force -ErrorAction SilentlyContinue
}

foreach ($n in $removed) {
    if ($n -eq 1) { continue }
    foreach ($dir in (Get-ProfileDataDir $n), (Get-ProfileCodeDir $n)) {
        if (Test-Path $dir) { Write-Host "Kept profile $n data: $dir (delete it yourself to sign out for good)" }
    }
}
