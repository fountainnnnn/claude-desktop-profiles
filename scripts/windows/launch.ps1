# Opens one Claude Desktop profile. The "Claude N" shortcuts run this hidden.
#   Profile 1 = Claude's normal data folder (whatever you were already using).
#   Profile N = %APPDATA%\Claude-N, so it signs in to its own account.
# If that profile is already open, Claude's own single-instance lock (one per
# data folder) brings its window forward instead of starting a duplicate.
param([Parameter(Mandatory = $true)][ValidateRange(1, 9)][int]$Number)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$override = $null
$config = Join-Path $PSScriptRoot 'config.json'
if (Test-Path $config) { $override = (Get-Content $config -Raw | ConvertFrom-Json).ClaudeExe }

$claude = Find-Claude -Override $override
if (-not $claude) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Claude Desktop wasn't found. Install it from claude.ai/download, then try again.",
        'Claude profiles', 'OK', 'Error') | Out-Null
    exit 1
}

if ($Number -eq 1) {
    if ($claude.AppId) { Start-Process explorer.exe -ArgumentList "shell:AppsFolder\$($claude.AppId)" }
    else { Start-Process -FilePath $claude.Exe }
    exit 0
}

$data = Get-ProfileDataDir $Number
$code = Get-ProfileCodeDir $Number
New-Item -ItemType Directory -Force -Path $data, $code | Out-Null
$env:CLAUDE_CONFIG_DIR = $code   # inherited by Claude, so its Code tab uses ~/.claude-N
Start-Process -FilePath $claude.Exe -ArgumentList "--user-data-dir=`"$data`""
