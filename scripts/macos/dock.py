#!/usr/bin/env python3
"""Edits the Dock's app list for the Claude profile launchers.

  dock.py add N [N ...]     put Claude N launchers where Claude.app sat
                            (Claude.app's own tile is replaced, since
                            Claude 1 now opens it)
  dock.py remove N [N ...]  take those launchers out; if none are left,
                            put Claude.app back in their place

Backs up the Dock settings first and restarts the Dock afterwards.
"""
import os, plistlib, re, subprocess, sys, tempfile, time

CLAUDE_URL = "file:///Applications/Claude.app/"
LAUNCHER = re.compile(r"^file:///Applications/Claude%20(\d+)\.app/$")
BACKUP_DIR = os.path.expanduser("~/Library/Application Support/claude-desktop-profiles")


def url(tile):
    return tile.get("tile-data", {}).get("file-data", {}).get("_CFURLString", "")


def tile(app_path, label):
    return {"tile-type": "file-tile", "tile-data": {
        "file-label": label,
        "file-data": {"_CFURLString": "file://" + app_path.replace(" ", "%20") + "/",
                      "_CFURLStringType": 15}}}


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("add", "remove"):
        sys.exit(__doc__)
    action, numbers = sys.argv[1], [int(n) for n in sys.argv[2:]]

    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "dock.plist")
        subprocess.run(["defaults", "export", "com.apple.dock", path], check=True)
        with open(path, "rb") as f:
            dock = plistlib.load(f)

        os.makedirs(BACKUP_DIR, exist_ok=True)
        backup = os.path.join(BACKUP_DIR, time.strftime("dock-backup-%Y%m%d-%H%M%S.plist"))
        with open(backup, "wb") as f:
            plistlib.dump(dock, f)

        apps = dock.setdefault("persistent-apps", [])
        launchers = lambda: [t for t in apps if LAUNCHER.match(url(t))]

        if action == "add":
            ours = {int(LAUNCHER.match(url(t)).group(1)) for t in launchers()} | set(numbers)
            spots = [i for i, t in enumerate(apps) if url(t) == CLAUDE_URL or LAUNCHER.match(url(t))]
            at = spots[0] if spots else len(apps)
            apps[:] = [t for t in apps if url(t) != CLAUDE_URL and not LAUNCHER.match(url(t))]
            apps[at:at] = [tile(f"/Applications/Claude {n}.app", f"Claude {n}") for n in sorted(ours)]
        else:
            spots = [i for i, t in enumerate(apps)
                     if LAUNCHER.match(url(t)) and int(LAUNCHER.match(url(t)).group(1)) in numbers]
            apps[:] = [t for i, t in enumerate(apps) if i not in spots]
            if spots and not launchers() and not any(url(t) == CLAUDE_URL for t in apps):
                apps.insert(spots[0], tile("/Applications/Claude.app", "Claude"))

        with open(path, "wb") as f:
            plistlib.dump(dock, f)
        wanted = [url(t) for t in apps]
        # The Dock can save its own copy of the list while we write ours (it
        # does when apps open or quit), so check the result and retry.
        for attempt in range(5):
            subprocess.run(["defaults", "import", "com.apple.dock", path], check=True)
            # A normal quit lets the Dock save its old list over ours; on retries,
            # stop it without saving (macOS restarts it straight away).
            subprocess.run(["killall"] + (["-KILL"] if attempt else []) + ["Dock"], check=False)
            time.sleep(2)
            subprocess.run(["defaults", "export", "com.apple.dock", check_path := path + ".now"], check=True)
            with open(check_path, "rb") as f:
                now = [url(t) for t in plistlib.load(f).get("persistent-apps", [])]
            if now == wanted:
                break
        else:
            sys.exit(f"The Dock kept its old layout; please try again.\n  wanted: {wanted}\n  got:    {now}")

    print(f"Dock updated (previous layout saved to {backup})")


if __name__ == "__main__":
    main()
