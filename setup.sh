#!/bin/bash

set -e

ROLE="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/config.env"

echo ""
echo "=========================================="
echo " COMPUTER NETWORKS - PHASE 1"
echo " ROLE: $ROLE"
echo "=========================================="
echo ""

if [ -z "$ROLE" ]; then
    echo "Usage:"
    echo "  ./setup.sh mac1"
    echo "  ./setup.sh mac2"
    echo "  ./setup.sh mac3"
    echo "  ./setup.sh mac4"
    exit 1
fi

echo "Domain : $PROJECT_DOMAIN"
echo "Mac 1  : $MAC1_IP"
echo "Mac 2  : $MAC2_IP"
echo "Mac 3  : $MAC3_IP"
echo "Mac 4  : $MAC4_IP"
echo ""

# ------------------------------------------
# Detect Wi-Fi interface
# ------------------------------------------

INTERFACE=$(
    networksetup -listallhardwareports |
    awk '/Wi-Fi/{getline; print $2}'
)

if [ -z "$INTERFACE" ]; then
    echo "Could not detect Wi-Fi interface."
    exit 1
fi

LOCAL_IP=$(ipconfig getifaddr "$INTERFACE" 2>/dev/null || true)

echo "Interface : $INTERFACE"
echo "Local IP  : $LOCAL_IP"
echo ""


# ==========================================
# MAC 1
# DNS SERVER
# ==========================================

setup_mac1() {

    echo "=========================================="
    echo " MAC 1 - DNS SERVER"
    echo "=========================================="

    mkdir -p "$HOME/cn-phase1/dns"

    cat > "$HOME/cn-phase1/dns/dns_server.py" <<PYTHON
#!/usr/bin/env python3

import socket

DOMAIN = "$PROJECT_DOMAIN"
MAC2_IP = "$MAC2_IP"
PORT = $DNS_PORT

# Minimal DNS server for the project.
# Handles A-record queries for:
# app.DOMAIN
# api.DOMAIN

def encode_name(name):
    result = b""

    for part in name.split("."):
        result += bytes([len(part)])
        result += part.encode()

    result += b"\\x00"

    return result


def parse_query(data):

    transaction_id = data[:2]

    qname = []
    index = 12

    while data[index] != 0:

        length = data[index]
        index += 1

        qname.append(
            data[index:index+length].decode()
        )

        index += length

    name = ".".join(qname)

    return transaction_id, name


def build_response(data):

    transaction_id, name = parse_query(data)

    # DNS header
    header = (
        transaction_id +
        b"\\x81\\x80" +
        b"\\x00\\x01" +
        b"\\x00\\x01" +
        b"\\x00\\x00" +
        b"\\x00\\x00"
    )

    question = data[12:]

    ip = MAC2_IP.split(".")

    answer = (
        b"\\xc0\\x0c" +
        b"\\x00\\x01" +
        b"\\x00\\x01" +
        b"\\x00\\x00\\x00\\x3c" +
        b"\\x00\\x04" +
        bytes(map(int, ip))
    )

    print(f"DNS query: {name} -> {MAC2_IP}")

    return header + question + answer


sock = socket.socket(
    socket.AF_INET,
    socket.SOCK_DGRAM
)

sock.bind(("0.0.0.0", PORT))

print("=" * 50)
print("Private DNS Server")
print(f"Listening on UDP {PORT}")
print(f"app.{DOMAIN} -> {MAC2_IP}")
print(f"api.{DOMAIN} -> {MAC2_IP}")
print("=" * 50)

while True:

    data, address = sock.recvfrom(512)

    try:

        response = build_response(data)

        sock.sendto(response, address)

    except Exception as e:

        print("DNS error:", e)

PYTHON

    chmod +x "$HOME/cn-phase1/dns/dns_server.py"

    echo ""
    echo "DNS server created."
    echo ""
    echo "Start it with:"
    echo ""
    echo "sudo python3 ~/cn-phase1/dns/dns_server.py"
    echo ""

}


# ==========================================
# MAC 2
# HTTPS EDGE + LOAD BALANCER
# ==========================================

setup_mac2() {

    echo "=========================================="
    echo " MAC 2 - EDGE / LOAD BALANCER"
    echo "=========================================="

    mkdir -p "$HOME/cn-phase1/edge"

    cat > "$HOME/cn-phase1/edge/edge_server.py" <<PYTHON
#!/usr/bin/env python3

import http.server
import socketserver
import urllib.request
import ssl
import itertools

BACKENDS = [
    ("$MAC3_IP", $BACKEND_A_PORT),
    ("$MAC4_IP", $BACKEND_B_PORT),
]

counter = itertools.cycle(BACKENDS)


class ProxyHandler(
    http.server.BaseHTTPRequestHandler
):

    def do_GET(self):

        backend_ip, backend_port = next(counter)

        target = (
            f"http://{backend_ip}:"
            f"{backend_port}{self.path}"
        )

        print(
            f"{self.client_address[0]} "
            f"-> {target}"
        )

        try:

            request = urllib.request.Request(
                target,
                headers={
                    "X-Forwarded-For":
                    self.client_address[0]
                }
            )

            with urllib.request.urlopen(
                request,
                timeout=5
            ) as response:

                body = response.read()

                self.send_response(
                    response.status
                )

                for key, value in response.headers.items():

                    if key.lower() not in [
                        "connection",
                        "transfer-encoding"
                    ]:

                        self.send_header(
                            key,
                            value
                        )

                self.end_headers()

                self.wfile.write(body)

        except Exception as e:

            print("Backend error:", e)

            self.send_response(502)

            self.send_header(
                "Content-Type",
                "application/json"
            )

            self.end_headers()

            self.wfile.write(
                b'{"error":"Backend unavailable"}'
            )


class ReusableTCPServer(
    socketserver.ThreadingTCPServer
):

    allow_reuse_address = True


server = ReusableTCPServer(
    ("0.0.0.0", $HTTPS_PORT),
    ProxyHandler
)

print("=" * 50)
print("Computer Networks Edge")
print(f"HTTPS/HTTP edge port: $HTTPS_PORT")
print("")
print("Backend A:")
print("$MAC3_IP:$BACKEND_A_PORT")
print("")
print("Backend B:")
print("$MAC4_IP:$BACKEND_B_PORT")
print("=" * 50)

server.serve_forever()

PYTHON

    chmod +x "$HOME/cn-phase1/edge/edge_server.py"

    echo ""
    echo "Edge server created."

    echo ""
    echo "Start with:"
    echo ""
    echo "python3 ~/cn-phase1/edge/edge_server.py"
    echo ""

}


# ==========================================
# MAC 3
# BACKEND A
# ==========================================

setup_mac3() {

    echo "=========================================="
    echo " MAC 3 - BACKEND A"
    echo "=========================================="

    mkdir -p "$HOME/cn-phase1/backend"

    cat > "$HOME/cn-phase1/backend/backend.py" <<PYTHON
#!/usr/bin/env python3

from http.server import BaseHTTPRequestHandler
from http.server import HTTPServer
import json
import hashlib

PORT = $BACKEND_A_PORT
BACKEND = "A"


class Handler(BaseHTTPRequestHandler):

    def do_GET(self):

        if self.path == "/":

            data = {
                "backend": BACKEND,
                "status": "ok"
            }

        elif self.path == "/api/status":

            data = {
                "backend": BACKEND,
                "status": "ok"
            }

        else:

            data = {
                "error": "not found"
            }

        body = json.dumps(data).encode()

        etag = '"' + hashlib.md5(
            body
        ).hexdigest() + '"'

        if self.headers.get(
            "If-None-Match"
        ) == etag:

            self.send_response(304)

            self.send_header(
                "ETag",
                etag
            )

            self.end_headers()

            return

        self.send_response(200)

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
            BACKEND
        )

        self.send_header(
            "Cache-Control",
            "max-age=60"
        )

        self.send_header(
            "ETag",
            etag
        )

        self.end_headers()

        self.wfile.write(body)


server = HTTPServer(
    ("0.0.0.0", PORT),
    Handler
)

print(
    f"Backend {BACKEND} listening on {PORT}"
)

server.serve_forever()

PYTHON

    chmod +x "$HOME/cn-phase1/backend/backend.py"

    echo ""
    echo "Backend A ready."
    echo ""
    echo "Run:"
    echo "python3 ~/cn-phase1/backend/backend.py"
    echo ""

}


# ==========================================
# MAC 4
# BACKEND B
# ==========================================

setup_mac4() {

    echo "=========================================="
    echo " MAC 4 - BACKEND B"
    echo "=========================================="

    mkdir -p "$HOME/cn-phase1/backend"

    cat > "$HOME/cn-phase1/backend/backend.py" <<PYTHON
#!/usr/bin/env python3

from http.server import BaseHTTPRequestHandler
from http.server import HTTPServer
import json
import hashlib

PORT = $BACKEND_B_PORT
BACKEND = "B"


class Handler(BaseHTTPRequestHandler):

    def do_GET(self):

        if self.path == "/":

            data = {
                "backend": BACKEND,
                "status": "ok"
            }

        elif self.path == "/api/status":

            data = {
                "backend": BACKEND,
                "status": "ok"
            }

        else:

            data = {
                "error": "not found"
            }

        body = json.dumps(data).encode()

        etag = '"' + hashlib.md5(
            body
        ).hexdigest() + '"'

        if self.headers.get(
            "If-None-Match"
        ) == etag:

            self.send_response(304)

            self.send_header(
                "ETag",
                etag
            )

            self.end_headers()

            return

        self.send_response(200)

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
            BACKEND
        )

        self.send_header(
            "Cache-Control",
            "max-age=60"
        )

        self.send_header(
            "ETag",
            etag
        )

        self.end_headers()

        self.wfile.write(body)


server = HTTPServer(
    ("0.0.0.0", PORT),
    Handler
)

print(
    f"Backend {BACKEND} listening on {PORT}"
)

server.serve_forever()

PYTHON

    chmod +x "$HOME/cn-phase1/backend/backend.py"

    echo ""
    echo "Backend B ready."
    echo ""
    echo "Run:"
    echo "python3 ~/cn-phase1/backend/backend.py"
    echo ""

}


case "$ROLE" in

    mac1)
        setup_mac1
        ;;

    mac2)
        setup_mac2
        ;;

    mac3)
        setup_mac3
        ;;

    mac4)
        setup_mac4
        ;;

    *)
        echo "Invalid role."
        echo ""
        echo "Usage:"
        echo "./setup.sh mac1"
        echo "./setup.sh mac2"
        echo "./setup.sh mac3"
        echo "./setup.sh mac4"
        exit 1
        ;;

esac