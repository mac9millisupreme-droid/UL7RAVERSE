import hashlib
import json
import subprocess
import sys
import time
import urllib.request


def test_server():
    p = subprocess.Popen(
        [sys.executable, "products/ul7ra-verify/app/server.py"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        deadline = time.time() + 10
        last_error = None

        while time.time() < deadline:
            if p.poll() is not None:
                stdout, stderr = p.communicate()
                raise RuntimeError(
                    "server exited during startup: "
                    f"exit={p.returncode} stderr={stderr!r}"
                )

            try:
                health = urllib.request.urlopen(
                    "http://127.0.0.1:8787/health",
                    timeout=1,
                ).read()
                break
            except Exception as exc:
                last_error = exc
                time.sleep(0.1)
        else:
            stdout, stderr = p.communicate()
            raise RuntimeError(
                "server did not become ready within 10 seconds: "
                f"last_error={last_error!r} stderr={stderr!r}"
            )

        assert json.loads(health)["status"] == "healthy"

        payload = b"UL7RA_VERIFY_TEST_ARTIFACT"

        req = urllib.request.Request(
            "http://127.0.0.1:8787/verify",
            data=payload,
            method="POST",
        )

        result = json.loads(
            urllib.request.urlopen(req, timeout=5).read()
        )

        assert result["sha256"] == hashlib.sha256(payload).hexdigest()
        assert result["bytes"] == len(payload)

    finally:
        if p.poll() is None:
            p.terminate()

        try:
            p.wait(timeout=5)
        except subprocess.TimeoutExpired:
            p.kill()
            p.wait()
