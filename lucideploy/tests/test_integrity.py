from pathlib import Path
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lucideploy.core.integrity import sha256_file, require_hash

def test_hash_roundtrip():
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "x"
        p.write_text("UL7RA-LUCIDEPLOY")
        h = sha256_file(p)
        assert require_hash(p, h) == h

def test_hash_mismatch():
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "x"
        p.write_text("original")
        try:
            require_hash(p, "deadbeef")
            assert False
        except RuntimeError as e:
            assert str(e) == "HASH_MISMATCH"
