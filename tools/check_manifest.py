#!/usr/bin/env python3
"""Validate assets/manifest.json. Stdlib only.

Exit 0 when clean, 1 with a numbered error list otherwise.
Run from repo root: python3 tools/check_manifest.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "assets", "manifest.json")

TYPES = {"prop", "texture", "audio", "model", "scene-dressing", "ui", "vfx"}
STATUSES = {"needed", "placeholder", "in_progress", "integrated", "done"}
REQUIRED = ["id", "type", "status", "source", "license", "file", "target", "notes"]


def main() -> int:
    try:
        data = json.load(open(MANIFEST, encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"manifest unreadable: {e}")
        return 1

    errors = []
    seen = set()
    for i, a in enumerate(data.get("assets", [])):
        tag = a.get("id", f"#{i}")
        missing = [k for k in REQUIRED if k not in a]
        if missing:
            errors.append(f"{tag}: missing fields {missing}")
            continue
        if a["id"] in seen:
            errors.append(f"{tag}: duplicate id")
        seen.add(a["id"])
        if a["type"] not in TYPES:
            errors.append(f"{tag}: bad type {a['type']!r} (one of {sorted(TYPES)})")
        if a["status"] not in STATUSES:
            errors.append(f"{tag}: bad status {a['status']!r} (one of {sorted(STATUSES)})")
        if a["status"] in {"integrated", "done"} and not a["file"]:
            errors.append(f"{tag}: status {a['status']} but file is null")
        if a["file"]:
            path = a["file"] if os.path.isabs(a["file"]) else os.path.join(ROOT, "assets", a["file"])
            if not os.path.exists(path):
                errors.append(f"{tag}: file assets/{a['file']} does not exist")
        if a["source"] not in {None, "greybox", "procedural"} and not a["license"]:
            errors.append(f"{tag}: third-party/generated source needs a license field")

    if errors:
        print(f"manifest: {len(errors)} problem(s)")
        for n, e in enumerate(errors, 1):
            print(f"  {n}. {e}")
        return 1
    print(f"manifest OK: {len(seen)} assets")
    return 0


if __name__ == "__main__":
    sys.exit(main())
