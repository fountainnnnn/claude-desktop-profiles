<#
.SYNOPSIS
    Creates "Claude 1" ... "Claude N" shortcuts so several Claude Desktop
    accounts can run side by side on one Windows PC. Unofficial; see README.md.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\windows\install.ps1 -Count 2 -CopyCodeSettings
#>
param(
    # How many profiles to set up in total.
    [ValidateRange(2, 9)][int]$Count = 2,
    # Don't put shortcuts on the Desktop (they always go in the Start menu).
    [switch]$NoDesktop,
    # Copy ~\.claude\CLAUDE.md and ~\.claude\skills into each new profile's
    # Claude Code folder (~\.claude-N).
    [switch]$CopyCodeSettings,
    # Path to Claude.exe, for unusual installs (normally found automatically).
    [string]$ClaudeExe
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
Add-Type -AssemblyName System.Drawing

$claude = Find-Claude -Override $ClaudeExe
if (-not $claude) {
    throw "Claude Desktop wasn't found. Install it from claude.ai/download first (or pass -ClaudeExe)."
}
Write-Host "Found Claude at $($claude.Exe)"

# --- Icons --------------------------------------------------------------------

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

// Reads a file's full-size (256px) shell icon with its transparency intact.
public static class ShellIcon {
    [ComImport, Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellItemImageFactory { [PreserveSig] int GetImage(SIZE size, int flags, out IntPtr bitmap); }
    [StructLayout(LayoutKind.Sequential)] struct SIZE { public int cx, cy; }
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
    static extern void SHCreateItemFromParsingName(string path, IntPtr ctx, [MarshalAs(UnmanagedType.LPStruct)] Guid riid,
        [MarshalAs(UnmanagedType.Interface)] out IShellItemImageFactory item);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr handle);

    public static Bitmap Get(string path, int size) {
        IShellItemImageFactory factory;
        SHCreateItemFromParsingName(path, IntPtr.Zero, typeof(IShellItemImageFactory).GUID, out factory);
        IntPtr hbitmap;
        int hr = factory.GetImage(new SIZE { cx = size, cy = size }, 0x4 /* icon only */, out hbitmap);
        if (hr != 0) Marshal.ThrowExceptionForHR(hr);
        try {
            // FromHbitmap drops alpha; re-read the same pixels as ARGB.
            using (Bitmap rgb = Image.FromHbitmap(hbitmap)) {
                Rectangle all = new Rectangle(0, 0, rgb.Width, rgb.Height);
                BitmapData bits = rgb.LockBits(all, ImageLockMode.ReadOnly, rgb.PixelFormat);
                try {
                    using (Bitmap argb = new Bitmap(bits.Width, bits.Height, bits.Stride, PixelFormat.Format32bppArgb, bits.Scan0))
                        return new Bitmap(argb);
                } finally { rgb.UnlockBits(bits); }
            }
        } finally { DeleteObject(hbitmap); }
    }
}
'@

function Get-ClaudeIcon {
    try { return [ShellIcon]::Get($claude.Exe, 256) }
    catch { return ([System.Drawing.Icon]::ExtractAssociatedIcon($claude.Exe)).ToBitmap() }
}

function New-BadgeIcon([int]$Number, [string]$Hex, [string]$OutFile) {
    $size = 256
    $canvas = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.SmoothingMode = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'
    $base = Get-ClaudeIcon
    $g.DrawImage($base, 0, 0, $size, $size)
    $base.Dispose()

    # Badge in the bottom-right corner.
    $cx = 190; $cy = 190; $r = 54; $ring = 4
    $g.FillEllipse([System.Drawing.Brushes]::White, $cx - $r - $ring, $cy - $r - $ring, 2 * ($r + $ring), 2 * ($r + $ring))
    $color = [System.Drawing.ColorTranslator]::FromHtml("#$Hex")
    $fill = New-Object System.Drawing.SolidBrush $color
    $g.FillEllipse($fill, $cx - $r, $cy - $r, 2 * $r, 2 * $r)

    # Centre the digit on its actual outline, not the font's line box.
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $family = New-Object System.Drawing.FontFamily 'Segoe UI'
    $path.AddString("$Number", $family, [int][System.Drawing.FontStyle]::Bold, 78, (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
    $bounds = $path.GetBounds()
    $shift = New-Object System.Drawing.Drawing2D.Matrix
    $shift.Translate($cx - $bounds.X - $bounds.Width / 2, $cy - $bounds.Y - $bounds.Height / 2)
    $path.Transform($shift)
    $g.FillPath([System.Drawing.Brushes]::White, $path)
    $g.Dispose()

    # Write a multi-size .ico (PNG-compressed entries, supported since Vista).
    $sizes = 256, 64, 48, 32, 16
    $images = foreach ($s in $sizes) {
        $scaled = New-Object System.Drawing.Bitmap $s, $s, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $sg = [System.Drawing.Graphics]::FromImage($scaled)
        $sg.InterpolationMode = 'HighQualityBicubic'
        $sg.DrawImage($canvas, 0, 0, $s, $s)
        $sg.Dispose()
        $ms = New-Object System.IO.MemoryStream
        $scaled.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $scaled.Dispose()
        , $ms.ToArray()
    }
    $canvas.Dispose()

    $out = New-Object System.IO.BinaryWriter ([System.IO.File]::Create($OutFile))
    try {
        $out.Write([uint16]0); $out.Write([uint16]1); $out.Write([uint16]$sizes.Count)
        $offset = 6 + 16 * $sizes.Count
        for ($i = 0; $i -lt $sizes.Count; $i++) {
            $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
            $out.Write([byte]$dim); $out.Write([byte]$dim); $out.Write([byte]0); $out.Write([byte]0)
            $out.Write([uint16]1); $out.Write([uint16]32)
            $out.Write([uint32]$images[$i].Length); $out.Write([uint32]$offset)
            $offset += $images[$i].Length
        }
        foreach ($img in $images) { $out.Write($img) }
    } finally { $out.Close() }
}

# --- Install ------------------------------------------------------------------

New-Item -ItemType Directory -Force -Path $script:InstallDir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'common.ps1'), (Join-Path $PSScriptRoot 'launch.ps1') $script:InstallDir -Force
@{ ClaudeExe = $(if ($ClaudeExe) { $claude.Exe } else { $null }) } | ConvertTo-Json |
    Set-Content (Join-Path $script:InstallDir 'config.json') -Encoding UTF8

$colors = '202024', '2563EB', '16A34A', '9333EA', 'DB2777', '0891B2', 'CA8A04', 'DC2626', '475569'
$shell = New-Object -ComObject WScript.Shell
$powershell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$folders = @($startMenu)
if (-not $NoDesktop) { $folders += [Environment]::GetFolderPath('Desktop') }

for ($n = 1; $n -le $Count; $n++) {
    $icon = Join-Path $script:InstallDir "claude$n.ico"
    New-BadgeIcon -Number $n -Hex $colors[$n - 1] -OutFile $icon

    foreach ($folder in $folders) {
        $lnk = Join-Path $folder "Claude $n.lnk"
        if ((Test-Path $lnk) -and $shell.CreateShortcut($lnk).Description -ne $script:ShortcutTag) {
            Write-Warning "Skipping $lnk`: it exists and wasn't made by this tool."
            continue
        }
        $sc = $shell.CreateShortcut($lnk)
        $sc.TargetPath = $powershell
        $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $script:InstallDir 'launch.ps1')`" -Number $n"
        $sc.IconLocation = "$icon,0"
        $sc.WindowStyle = 7   # start minimised, so the helper never flashes a window
        $sc.Description = $script:ShortcutTag
        $sc.Save()
    }
    Write-Host "Built Claude $n"

    if ($n -gt 1 -and $CopyCodeSettings) {
        $code = Get-ProfileCodeDir $n
        New-Item -ItemType Directory -Force -Path $code | Out-Null
        $src = Join-Path $env:USERPROFILE '.claude'
        if ((Test-Path "$src\CLAUDE.md") -and -not (Test-Path "$code\CLAUDE.md")) {
            Copy-Item "$src\CLAUDE.md" $code; Write-Host "  copied CLAUDE.md to $code"
        }
        if ((Test-Path "$src\skills") -and -not (Test-Path "$code\skills")) {
            Copy-Item "$src\skills" $code -Recurse; Write-Host "  copied skills to $code"
        }
    }
}

Write-Host @"

Done. Open "Claude 1" (your existing Claude) or "Claude 2" from the Start menu
or Desktop. To pin one, right-click it in the Start menu > More > Pin to taskbar
(pin the launcher, not the running Claude window; Windows doesn't let scripts pin).
First time you open Claude 2+: quit Claude 1 first (tray icon > Quit), so the
sign-in link doesn't land in the wrong window.
"@
