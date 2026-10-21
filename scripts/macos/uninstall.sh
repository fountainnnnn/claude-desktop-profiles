#!/bin/bash
# Removes the "Claude N.app" launchers made by install.sh and puts Claude back
# in the Dock. Logins and chats are kept; the script prints where they live.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: uninstall.sh [N ...]

  With no numbers, removes every launcher this tool made.
  With numbers (e.g. "uninstall.sh 3"), removes only those.
Profile data is never deleted.
EOF
}

case "${1:-}" in -h|--help) usage; exit 0 ;; esac
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ $# -eq 0 ]; then
  set -- $(for app in /Applications/Claude\ [0-9]*.app; do
    [ -e "$app" ] && basename "$app" .app | sed 's/^Claude //'
  done)
fi
[ $# -gt 0 ] || { echo "No launchers found."; exit 0; }

removed=()
for n in "$@"; do
  case "$n" in [1-9]) ;; *) echo "Not a profile number: $n" >&2; exit 2 ;; esac
  APP="/Applications/Claude $n.app"
  [ -e "$APP" ] || continue
  if [ "$(defaults read "$APP/Contents/Info.plist" CFBundleIdentifier 2>/dev/null)" != "local.claude$n.launcher" ]; then
    echo "Skipping $APP: it wasn't made by this tool." >&2
    continue
  fi
  rm -rf "$APP"
  removed+=("$n")
  echo "Removed $APP"
done

[ ${#removed[@]} -gt 0 ] || exit 0
python3 "$HERE/dock.py" remove "${removed[@]}"

for n in "${removed[@]}"; do
  [ "$n" = 1 ] && continue
  for dir in "$HOME/Library/Application Support/Claude-$n" "$HOME/.claude-$n"; do
    [ -e "$dir" ] && echo "Kept profile $n data: $dir (delete it yourself to sign out for good)"
  done
done
exit 0
