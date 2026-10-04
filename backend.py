#!/usr/bin/env python3

from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import hashlib
import os

BACKEND_NAME = os.environ.get("BACKEND_NAME", "UNKNOWN")
PORT = int(os.environ.get("BACKEND_PORT", "3001"))


class Handler(BaseHTTPRequestHandler):

    def send_json(self, data, status=200, cache=True):

        body = json.dumps(data, indent=2).encode("utf-8")

        etag = '"' + hashlib.md5(body).hexdigest() + '"'

        self.send_response(status)

        self.send_header(
            "Content-Type",
            "application/json"
        )

        self.send_header(
            "Content-Length",
            str(len(body))
        )

        self.send_header(
            "X-Backend",
            BACKEND_NAME
        )

        if cache:
            self.send_header(
                "Cache-Control",
                "max-age=60"
            )

            self.send_header(
                "ETag",
                etag
            )

        # Support conditional requests
        if self.headers.get("If-None-Match") == etag:
            self.send_response_only(304)
            self.send_header("ETag", etag)
            self.end_headers()
            return

        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):

        if self.path == "/":

            self.send_json({
                "service": "Computer Networks Phase 1",
                "backend": BACKEND_NAME,
                "status": "ok"
            })

        elif self.path == "/api/status":

            self.send_json({
                "backend": BACKEND_NAME,
                "status": "ok"
            })

        else:

            self.send_json({
                "error": "Not Found",
                "path": self.path
            }, 404, cache=False)

    def log_message(self, format, *args):
        print(
            "[%s] %s"
            % (BACKEND_NAME, format % args)
        )


server = HTTPServer(
    ("0.0.0.0", PORT),
    Handler
)

print("=" * 50)
print(f"Backend {BACKEND_NAME}")
print(f"Listening on 0.0.0.0:{PORT}")
print("=" * 50)

server.serve_forever()