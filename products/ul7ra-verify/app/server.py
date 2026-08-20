#!/usr/bin/env python3

import hashlib
import json
import os
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

PRODUCT = "UL7RA Verify"
VERSION = "0.1.0"

class Handler(BaseHTTPRequestHandler):

    def send_json(self, status, payload):
        body = json.dumps(payload, indent=2).encode()

        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/":
            self.send_json(200, {
                "product": PRODUCT,
                "version": VERSION,
                "status": "ONLINE",
                "verification": "AVAILABLE"
            })
            return

        if self.path == "/health":
            self.send_json(200, {
                "status": "healthy",
                "timestamp": int(time.time())
            })
            return

        self.send_json(404, {"error": "not_found"})

    def do_POST(self):
        if self.path != "/verify":
            self.send_json(404, {"error": "not_found"})
            return

        length = int(self.headers.get("Content-Length", "0"))

        if length <= 0:
            self.send_json(400, {"error": "artifact_required"})
            return

        data = self.rfile.read(length)

        digest = hashlib.sha256(data).hexdigest()

        result = {
            "product": PRODUCT,
            "version": VERSION,
            "result": "VERIFIED_INPUT_RECEIVED",
            "sha256": digest,
            "bytes": len(data),
            "timestamp": int(time.time())
        }

        self.send_json(200, result)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8787"))

    server = HTTPServer(("0.0.0.0", port), Handler)

    print(f"{PRODUCT} {VERSION}")
    print(f"Listening on :{port}")

    server.serve_forever()
