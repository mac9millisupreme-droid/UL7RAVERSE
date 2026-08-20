import hashlib
import json
import subprocess
import sys
import time
import urllib.request

p = subprocess.Popen(
    [sys.executable, "app/server.py"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE
)

try:
    time.sleep(1)

    health = urllib.request.urlopen(
        "http://127.0.0.1:8787/health"
    ).read()

    assert json.loads(health)["status"] == "healthy"

    payload = b"UL7RA_VERIFY_TEST_ARTIFACT"

    req = urllib.request.Request(
        "http://127.0.0.1:8787/verify",
        data=payload,
        method="POST"
    )

    result = json.loads(
        urllib.request.urlopen(req).read()
    )

    assert result["sha256"] == hashlib.sha256(payload).hexdigest()
    assert result["bytes"] == len(payload)

    print("TESTS=PASS")

finally:
    p.terminate()
    p.wait()
