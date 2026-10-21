---
name: claude-desktop-profiles
description: Set up two or more Claude Desktop accounts side by side on one Mac or Windows PC (e.g. personal + work), each with a numbered launcher icon. Use when the user wants a second Claude account, a work and personal Claude at the same time, multiple Claude Desktop profiles, or asks to remove that setup.
---

# Claude Desktop profiles

Unofficial. Creates numbered launchers (**Claude 1**, **Claude 2**, ...). Each
opens the user's normal Claude Desktop with its own data folder
(`--user-data-dir`), so each signs in to its own account. Claude itself isn't
modified and keeps auto-updating. Scripts live next to this file in
`scripts/macos/` and `scripts/windows/`.

## Set up

1. **Check the system.** If anything is missing, stop and tell the user what to install.
   - macOS: `/Applications/Claude.app` exists, and `swiftc` is available
     (otherwise `xcode-select --install`).
   - Windows: Claude Desktop is installed (claude.ai/download or the Microsoft
     Store). The installer finds it.
2. **Ask** two things, unless the user already said:
   - How many accounts in total (default 2).
   - Whether the new accounts' Code tab should get a copy of their
     `~/.claude/CLAUDE.md` and `~/.claude/skills`.
3. **Run the installer.** On macOS it writes to `/Applications` and restarts the
   Dock, so it may need to run outside a sandbox.
   - macOS: `scripts/macos/install.sh 2 --copy-code-settings`
   - Windows: `powershell -ExecutionPolicy Bypass -File scripts\windows\install.ps1 -Count 2 -CopyCodeSettings`

   Re-running is safe: logins are kept, and launchers this tool didn't make are
   never overwritten.
4. **Tell the user how to finish.** These steps are theirs, not yours.
   - **Claude 1** is the Claude they already use. **Claude 2** and up open a
     fresh sign-in screen.
   - Quit Claude 1 completely before signing in to Claude 2. Otherwise the
     browser's sign-in link can land in Claude 1, because all accounts share the
     `claude://` link. Reopen Claude 1 afterwards.
   - Mac: when asked "Claude 2 wants to control Claude", Allow. That lets a
     click bring back a closed window.
   - Windows: the launchers are in the Start menu and on the Desktop. To pin
     one, right-click it in the Start menu → (More →) Pin to taskbar. Pinning
     the running Claude window would pin plain Claude instead. Scripts can't pin.
   - While running, every account shows the normal Claude icon. The account
     name at the bottom of the sidebar shows which one they're in.

## Remove

- macOS: `scripts/macos/uninstall.sh` (or `uninstall.sh 3` for one)
- Windows: `powershell -ExecutionPolicy Bypass -File scripts\windows\uninstall.ps1` (or `-Number 3`)

Account data is kept and the script prints the paths:
`~/Library/Application Support/Claude-N` or `%APPDATA%\Claude-N`, plus
`~/.claude-N`. Delete them only if the user asks.

## Troubleshooting

- **Claude 2 opens already signed in as account 1.** A Claude update has stopped
  honouring `--user-data-dir`. Nothing can be fixed on this side. Tell the user
  and suggest uninstalling until it's resolved.
- **Mac: clicking Claude 2 shows no window.** The "control Claude" prompt was
  declined. Re-enable it under System Settings → Privacy & Security →
  Automation, or quit Claude 2 with Cmd+Q and click again.
- **Mac: asked for permission again after re-installing.** Expected. macOS ties
  the permission to the launcher's signature, which changes on a rebuild.
- **Windows: "Claude Desktop wasn't found".** Re-run with
  `-ClaudeExe "C:\path\to\Claude.exe"`.
- **Windows: Cowork fails in one account.** Only one Cowork VM runs per PC. Quit
  the other account first.
