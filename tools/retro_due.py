#!/usr/bin/env python3
"""Report whether a workflow retro is due.

Counts session logs in docs/exec-logs/ written after the newest *-retro.md.
Prints RETRO_DUE with the backlog count when >= threshold, else OK.
Run at session start: python3 tools/retro_due.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGS = os.path.join(ROOT, "docs", "exec-logs")
THRESHOLD = 5

ENTRY = re.compile(r"^\d{4}-\d{2}-\d{2}.*\.md$")


def main() -> int:
    names = sorted(f for f in os.listdir(LOGS) if ENTRY.match(f))
    retros = [f for f in names if f.endswith("-retro.md")]
    sessions = [f for f in names if not f.endswith("-retro.md")]
    last_retro = retros[-1] if retros else None
    backlog = [f for f in sessions if last_retro is None or f > last_retro]

    if len(backlog) >= THRESHOLD:
        print(f"RETRO_DUE: {len(backlog)} session log(s) since "
              f"{last_retro or 'beginning'} — invoke the workflow-retro skill.")
        for f in backlog:
            print(f"  - {f}")
    else:
        print(f"OK: {len(backlog)}/{THRESHOLD} logs since last retro "
              f"({last_retro or 'none yet'})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
