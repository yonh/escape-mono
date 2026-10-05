#!/usr/bin/env python3
"""Sync registered assets into the Godot project.

Copies files for assets whose manifest status is integrated/done from
assets/<file> to game/assets/<type>/<basename>. Idempotent; prints what it did.

Run from repo root: python3 tools/sync_assets.py
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets", "manifest.json")
GAME_ASSETS = os.path.join(ROOT, "game", "assets")

SYNC_STATUSES = {"integrated", "done"}


def main() -> int:
    data = json.load(open(MANIFEST, encoding="utf-8"))
    synced, skipped = [], []
    for a in data.get("assets", []):
        if a["status"] not in SYNC_STATUSES or not a["file"]:
            skipped.append(a["id"])
            continue
        src = os.path.join(ROOT, "assets", a["file"])
        if not os.path.exists(src):
            print(f"ERROR: {a['id']}: assets/{a['file']} missing", file=sys.stderr)
            return 1
        dst_dir = os.path.join(GAME_ASSETS, a["type"])
        os.makedirs(dst_dir, exist_ok=True)
        dst = os.path.join(dst_dir, os.path.basename(a["file"]))
        if os.path.exists(dst) and os.path.getmtime(src) <= os.path.getmtime(dst):
            skipped.append(a["id"])
            continue
        shutil.copy2(src, dst)
        synced.append(f"{a['id']} -> game/assets/{a['type']}/{os.path.basename(dst)}")

    for s in synced:
        print(f"synced {s}")
    print(f"{len(synced)} synced, {len(skipped)} already current/not ready")
    return 0


if __name__ == "__main__":
    sys.exit(main())
