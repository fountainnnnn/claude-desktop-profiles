#!/bin/bash
# Creates "Claude 1.app" ... "Claude N.app" launchers so several Claude Desktop
# accounts can run side by side on one Mac. Unofficial; see README.md.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install.sh [COUNT] [--no-dock] [--copy-code-settings]

  COUNT                 how many profiles to set up (default 2, max 9)
  --no-dock             don't add the launchers to the Dock
  --copy-code-settings  copy ~/.claude/CLAUDE.md and ~/.claude/skills into each
                        new profile's Claude Code folder (~/.claude-N), so the
                        Code tab there starts with your instructions and skills

Running it again is safe: it rebuilds the launchers and keeps every login.
EOF
}

COUNT=2 DOCK=1 COPY_CODE=0
for arg in "$@"; do
  case "$arg" in
    --no-dock) DOCK=0 ;;
    --copy-code-settings) COPY_CODE=1 ;;
    -h|--help) usage; exit 0 ;;
    [1-9]) COUNT="$arg" ;;
    *) usage >&2; exit 2 ;;
  esac
done
[ "$COUNT" -ge 2 ] || { echo "COUNT must be at least 2." >&2; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_APP="/Applications/Claude.app"
COLORS=(202024 2563EB 16A34A 9333EA DB2777 0891B2 CA8A04 DC2626 475569)

[ "$(uname)" = Darwin ] || { echo "This only works on macOS." >&2; exit 1; }
[ -d "$CLAUDE_APP" ] || { echo "Claude Desktop isn't in /Applications. Install it from claude.ai/download first." >&2; exit 1; }
command -v swiftc >/dev/null || { echo "Needs Apple's command line tools. Run: xcode-select --install" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Compiling helpers..."
swiftc -O "$HERE/activate.swift" -o "$WORK/activate"
swiftc -O "$HERE/make-icon.swift" -o "$WORK/make-icon"

for n in $(seq 1 "$COUNT"); do
  APP="/Applications/Claude $n.app"
  ID="local.claude$n.launcher"
  if [ -e "$APP" ] && [ "$(defaults read "$APP/Contents/Info.plist" CFBundleIdentifier 2>/dev/null)" != "$ID" ]; then
    echo "Skipping $APP: it exists and wasn't made by this tool." >&2
    continue
  fi

  # Icon: the installed Claude icon plus a numbered badge.
  ICONSET="$WORK/claude$n.iconset"
  mkdir -p "$ICONSET"
  "$WORK/make-icon" "$WORK/claude$n.png" "$n" "${COLORS[$((n - 1))]}"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$WORK/claude$n.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$WORK/claude$n.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done

  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/icon.icns"
  cp "$WORK/activate" "$APP/Contents/MacOS/activate"
  sed "s/__PROFILE__/$n/" "$HERE/launch.sh" > "$APP/Contents/MacOS/launch"
  chmod +x "$APP/Contents/MacOS/launch" "$APP/Contents/MacOS/activate"
  cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Claude $n</string>
  <key>CFBundleDisplayName</key><string>Claude $n</string>
  <key>CFBundleIdentifier</key><string>$ID</string>
  <key>CFBundleExecutable</key><string>launch</string>
  <key>CFBundleIconFile</key><string>icon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Claude $n reopens its Claude window when you click it in the Dock.</string>
</dict></plist>
EOF
  codesign --force --deep -s - "$APP" 2>/dev/null
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
  echo "Built $APP"

  if [ "$n" -gt 1 ] && [ "$COPY_CODE" = 1 ]; then
    CODE="$HOME/.claude-$n"
    mkdir -p "$CODE"
    if [ -f "$HOME/.claude/CLAUDE.md" ] && [ ! -e "$CODE/CLAUDE.md" ]; then
      cp "$HOME/.claude/CLAUDE.md" "$CODE/CLAUDE.md" && echo "  copied CLAUDE.md to $CODE"
    fi
    if [ -d "$HOME/.claude/skills" ] && [ ! -e "$CODE/skills" ]; then
      cp -R "$HOME/.claude/skills" "$CODE/skills" && echo "  copied skills to $CODE"
    fi
  fi
done

if [ "$DOCK" = 1 ]; then
  python3 "$HERE/dock.py" add $(seq 1 "$COUNT")
fi

cat <<EOF

Done. Claude 1 is your existing Claude. Claude 2 and up each sign in separately.
First time you open Claude 2+: quit Claude 1 (Cmd+Q) before signing in, so the
sign-in link doesn't land in the wrong window. Allow "control Claude" when asked;
that lets a Dock click bring back a window you closed.
EOF
