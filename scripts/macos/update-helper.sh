#!/bin/bash
# Lets Claude's auto-update finish while several accounts are open.
#
# Claude installs updates by quitting, letting its installer (ShipIt) swap in
# the new app, then relaunching. ShipIt waits until every copy of Claude.app
# has quit, so an open second account blocks it forever and the account that
# quit for the update never comes back.
#
# launchd runs this whenever ShipIt's state file changes. If Claude has asked
# to be relaunched after installing (it quit for the update) and other accounts
# are still open, this quits them normally, waits for the install, then reopens
# them. It exits straight away in every other case.
DIR="$(cd "$(dirname "$0")" && pwd)"
STATE="$HOME/Library/Caches/com.anthropic.claudefordesktop.ShipIt/ShipItState.plist"
BIN="/Applications/Claude.app/Contents/MacOS/Claude"
LOG="$DIR/update-helper.log"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
main_procs() { ps -axww -o pid=,command= | grep -F "$BIN" | grep -v -e "--type=" -e "grep"; }
installer_waiting() { pgrep -f "Squirrel.framework/Resources/ShipIt" >/dev/null; }
relaunch_requested() { [ "$(plutil -extract launchAfterInstallation raw "$STATE" 2>/dev/null)" = true ]; }
profile_of() { # "<command line>" -> profile number
  local data="--user-data-dir=$HOME/Library/Application Support/Claude-"
  case "$1" in
    *"$data"*) local rest="${1#*"$data"}"; echo "${rest%% *}" ;;
    *) echo 1 ;;
  esac
}

relaunch_requested && installer_waiting || exit 0

# Give the account that is updating time to finish quitting.
sleep 15
installer_waiting || exit 0          # nothing was in the way
procs="$(main_procs)"
[ -n "$procs" ] || exit 0

pids=() profiles=()
while read -r pid cmd; do
  pids+=("$pid")
  profiles+=("$(profile_of "$cmd")")
done <<< "$procs"

log "update waiting on open account(s) ${profiles[*]}; closing them"
osascript -e 'display notification "Closing your other Claude accounts so the update can install. They will reopen in a moment." with title "Claude update"' 2>/dev/null
for pid in "${pids[@]}"; do "$DIR/activate" --quit "$pid"; done

for _ in $(seq 1 300); do installer_waiting || break; sleep 2; done
if installer_waiting; then log "installer still waiting after 10 minutes; giving up"; exit 1; fi
log "update installed; reopening account(s) ${profiles[*]}"

sleep 3
for n in "${profiles[@]}"; do
  [ -d "/Applications/Claude $n.app" ] && open "/Applications/Claude $n.app"
  sleep 2
done
