import hashlib
from pathlib import Path

def sha256_file(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def require_hash(path, expected):
    actual = sha256_file(path)
    if actual != expected:
        raise RuntimeError("HASH_MISMATCH")
    return actual
