# Shared helpers for the Windows launchers. Works in Windows PowerShell 5.1+.

$script:ToolName = 'claude-desktop-profiles'
$script:InstallDir = Join-Path $env:LOCALAPPDATA $script:ToolName
$script:ShortcutTag = "$script:ToolName launcher"

function Get-ProfileDataDir([int]$Number) {
    # Must stay under %APPDATA%: Claude's Cowork VM only finds its disk there.
    Join-Path $env:APPDATA "Claude-$Number"
}

function Get-ProfileCodeDir([int]$Number) {
    Join-Path $env:USERPROFILE ".claude-$Number"
}

function Find-Claude {
    <# Returns @{ Exe; AppId } for the installed Claude Desktop, or $null.
       AppId is set for the Microsoft Store / MSIX install and is used to open
       profile 1 exactly the way the Start menu does. #>
    param([string]$Override)

    if ($Override) {
        if (Test-Path $Override) { return @{ Exe = (Resolve-Path $Override).Path; AppId = $null } }
        return $null
    }

    # MSIX install (claude.ai/download and the Microsoft Store). The folder
    # name changes with every update, so this is resolved on each launch.
    $pkg = Get-AppxPackage -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '*Claude*' -and $_.Publisher -match 'Anthropic' } |
        Sort-Object Version -Descending | Select-Object -First 1
    if ($pkg) {
        $exe = Join-Path $pkg.InstallLocation 'app\Claude.exe'
        if (-not (Test-Path $exe)) {
            $exe = Get-ChildItem $pkg.InstallLocation -Recurse -Filter 'Claude.exe' -ErrorAction SilentlyContinue |
                Select-Object -First 1 -ExpandProperty FullName
        }
        if ($exe) {
            $appId = $null
            try {
                $id = (Get-AppxPackageManifest $pkg).Package.Applications.Application |
                    Select-Object -First 1 -ExpandProperty Id
                if ($id) { $appId = "$($pkg.PackageFamilyName)!$id" }
            } catch { }
            return @{ Exe = $exe; AppId = $appId }
        }
    }

    # Older installer (Squirrel) in %LOCALAPPDATA%\AnthropicClaude.
    $legacy = Join-Path $env:LOCALAPPDATA 'AnthropicClaude\claude.exe'
    if (Test-Path $legacy) { return @{ Exe = $legacy; AppId = $null } }
    return $null
}

function Get-OurShortcuts {
    # Every "Claude N.lnk" this tool made, in the Start menu and on the Desktop.
    $shell = New-Object -ComObject WScript.Shell
    $dirs = @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'),
        [Environment]::GetFolderPath('Desktop')
    )
    foreach ($dir in $dirs) {
        Get-ChildItem $dir -Filter 'Claude *.lnk' -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.BaseName -match '^Claude (\d)$' -and $shell.CreateShortcut($_.FullName).Description -eq $script:ShortcutTag) {
                [pscustomobject]@{ Number = [int]$Matches[1]; Path = $_.FullName }
            }
        }
    }
}
