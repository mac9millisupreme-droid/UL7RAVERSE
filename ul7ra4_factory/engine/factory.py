#!/usr/bin/env python3
import json
import hashlib
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FACTORY = ROOT / "ul7ra4_factory"

def now():
    return datetime.now(timezone.utc).isoformat()

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def git(*args):
    try:
        return subprocess.check_output(
            ["git", *args],
            cwd=ROOT,
            stderr=subprocess.STDOUT,
            text=True
        ).strip()
    except Exception as e:
        return f"ERROR:{e}"

def inventory():
    result = {
        "timestamp": now(),
        "root": str(ROOT),
        "git_head": git("rev-parse", "HEAD"),
        "git_branch": git("branch", "--show-current"),
        "git_status": git("status", "--short"),
        "files": []
    }

    excluded = {".git", "__pycache__"}

    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if any(part in excluded for part in p.parts):
            continue
        try:
            result["files"].append({
                "path": str(p.relative_to(ROOT)),
                "sha256": sha256(p),
                "bytes": p.stat().st_size
            })
        except Exception:
            pass

    return result

def main():
    data = inventory()

    out = FACTORY / "manifests" / "CURRENT_BUILD_MANIFEST.json"
    out.parent.mkdir(parents=True, exist_ok=True)

    tmp = out.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True))
    os.replace(tmp, out)

    print(json.dumps({
        "factory": "UL7RA4_AUTONOMOUS_FACTORY",
        "timestamp": data["timestamp"],
        "git_head": data["git_head"],
        "file_count": len(data["files"]),
        "manifest": str(out)
    }, indent=2))

if __name__ == "__main__":
    main()
