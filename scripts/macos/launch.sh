#!/bin/bash
# Launcher for one Claude Desktop profile. install.sh copies this into each
# "Claude N.app" and replaces __PROFILE__ with N.
#   Profile 1 = Claude's normal data folder (whatever you were already using).
#   Profile N = its own data folder, so it signs in to its own account.
PROFILE=__PROFILE__
CLAUDE_APP="/Applications/Claude.app"
BIN="$CLAUDE_APP/Contents/MacOS/Claude"
HERE="$(dirname "$0")"

# This user's main Claude processes, matched on the program itself (helpers run
# from Frameworks/ and carry --type=).
main_procs() {
  ps -x -U "$(id -u)" -ww -o pid=,command= | awk -v bin="$BIN" '{
    cmd = $0; sub(/^ *[0-9]+ /, "", cmd)
    if ((cmd == bin || index(cmd, bin " ") == 1) && cmd !~ / --type=/) print
  }'
}

if [ "$PROFILE" = 1 ]; then
  PID=$(main_procs | grep -v -e "--user-data-dir" | awk '{print $1}' | head -1)
  [ -n "$PID" ] && exec "$HERE/activate" "$PID"
  exec open -n "$CLAUDE_APP"
fi

DATA="$HOME/Library/Application Support/Claude-$PROFILE"
CODE="$HOME/.claude-$PROFILE"
mkdir -p "$DATA" "$CODE"

# Exact match on the flag, so profile 2 never matches profile 20.
PID=$(main_procs | awk -v flag="--user-data-dir=$DATA" '{
  i = index($0, flag); if (!i) next
  after = substr($0, i + length(flag), 1)
  if (after == "" || after == " ") { print $1; exit }
}')
[ -n "$PID" ] && exec "$HERE/activate" "$PID"
exec open -n "$CLAUDE_APP" --env "CLAUDE_CONFIG_DIR=$CODE" --args --user-data-dir="$DATA"
