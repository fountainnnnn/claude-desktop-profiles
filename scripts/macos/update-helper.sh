#!/bin/bash
# Lets Claude's auto-update finish while several accounts are open.
#
# Claude installs updates by quitting, letting its installer (ShipIt) swap in
# the new app, then relaunching. ShipIt waits until every copy of Claude.app
# has quit, so an open second account blocks it and the account that quit for
# the update never comes back.
#
# launchd runs this whenever ShipIt's state file changes:
#  - Update downloaded: remember which accounts are open.
#  - An account quit to install it: ask the other accounts to quit, wait for
#    the install, then reopen everyone. If an account won't quit (Claude asks
#    for confirmation while a Claude Code task is running), reopen the account
#    that closed straight away and leave the update for later; it installs the
#    next time every account can close.
DIR="$(cd "$(dirname "$0")" && pwd)"
STATE="$HOME/Library/Caches/com.anthropic.claudefordesktop.ShipIt/ShipItState.plist"
BIN="/Applications/Claude.app/Contents/MacOS/Claude"
LOG="$DIR/update-helper.log"
SNAPSHOT="$DIR/open-before-update"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
# This user's main Claude processes, matched on the program itself (helpers run
# from Frameworks/ and carry --type=).
main_procs() {
  ps -x -U "$(id -u)" -ww -o pid=,command= | awk -v bin="$BIN" '{
    cmd = $0; sub(/^ *[0-9]+ /, "", cmd)
    if ((cmd == bin || index(cmd, bin " ") == 1) && cmd !~ / --type=/) print
  }'
}
installer_waiting() { pgrep -u "$(id -u)" -f "Squirrel.framework/Resources/ShipIt" >/dev/null; }
relaunch_requested() { [ "$(plutil -extract launchAfterInstallation raw "$STATE" 2>/dev/null)" = true ]; }
profile_of() { # "<command line>" -> profile number
  local data="--user-data-dir=$HOME/Library/Application Support/Claude-"
  case "$1" in
    *"$data"*) local rest="${1#*"$data"}"; echo "${rest%% *}" ;;
    *) echo 1 ;;
  esac
}
open_accounts() { # "<profile> <pid>" per open account
  main_procs | while read -r pid cmd; do
    n="$(profile_of "$cmd")"
    [[ "$n" =~ ^[1-9]$ ]] && echo "$n $pid"   # only profiles this tool can make
  done
}
reopen() { # profile numbers
  sleep 3
  for n in "$@"; do
    [ -d "/Applications/Claude $n.app" ] && open "/Applications/Claude $n.app"
    sleep 2
  done
}

if ! relaunch_requested; then
  # Update downloaded, nothing quit yet: note which accounts are open.
  open_accounts | cut -d' ' -f1 | sort -u > "$SNAPSHOT"
  exit 0
fi
installer_waiting || exit 0

# Give the account that is updating time to finish quitting.
sleep 15
installer_waiting || exit 0          # nothing was in the way
blocking="$(open_accounts)"
[ -n "$blocking" ] || exit 0

blocking_profiles=($(cut -d' ' -f1 <<< "$blocking" | sort -u))
blocking_pids=($(cut -d' ' -f2 <<< "$blocking"))
# Accounts open before the update that have since closed are the ones updating.
updating=($(comm -23 <(sort -u "$SNAPSHOT" 2>/dev/null) <(printf '%s\n' "${blocking_profiles[@]}")))
[ ${#updating[@]} -gt 0 ] || updating=(1)

log "account(s) ${updating[*]} quit to update; asking ${blocking_profiles[*]} to quit too"
for pid in "${blocking_pids[@]}"; do "$DIR/activate" --quit "$pid"; done

for _ in $(seq 1 30); do
  still=0
  for pid in "${blocking_pids[@]}"; do kill -0 "$pid" 2>/dev/null && still=1; done
  [ "$still" = 0 ] && break
  sleep 2
done
if [ "$still" = 1 ]; then
  log "account(s) ${blocking_profiles[*]} didn't quit (usually a running task); reopening ${updating[*]}, update postponed"
  reopen "${updating[@]}"
  exit 0
fi

osascript -e 'display notification "Installing the Claude update. Your accounts will reopen in a moment." with title "Claude update"' 2>/dev/null
for _ in $(seq 1 300); do installer_waiting || break; sleep 2; done
if installer_waiting; then
  log "installer still waiting after 10 minutes; reopening ${updating[*]} ${blocking_profiles[*]}"
else
  log "update installed; reopening ${updating[*]} ${blocking_profiles[*]}"
fi
reopen $(printf '%s\n' "${updating[@]}" "${blocking_profiles[@]}" | sort -u)
