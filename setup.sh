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
    echo " MAC 1 - PRIVATE DNS SERVER"
    echo " dnsmasq"
    echo "=========================================="

    DNS_DIR="$HOME/cn-phase1/dns"
    DNSMASQ_DIR="$HOME/cn-phase1/dnsmasq"
    DNSMASQ_INSTALL="$HOME/cn-phase1/dnsmasq-install"

    mkdir -p "$DNS_DIR"
    mkdir -p "$DNSMASQ_DIR"
    mkdir -p "$DNSMASQ_INSTALL"

    echo ""
    echo "Checking Wi-Fi interface..."
    echo "Interface : $INTERFACE"
    echo "Local IP  : $LOCAL_IP"
    echo ""

    if [ "$LOCAL_IP" != "$MAC1_IP" ]; then
        echo "ERROR: This Mac's IP does not match MAC1_IP."
        echo ""
        echo "Expected : $MAC1_IP"
        echo "Detected : $LOCAL_IP"
        echo ""
        exit 1
    fi

    echo "Mac 1 IP verified."
    echo ""

    # ------------------------------------------
    # Check for dnsmasq
    # ------------------------------------------

    if command -v dnsmasq >/dev/null 2>&1; then

        DNSMASQ_BIN="$(command -v dnsmasq)"

        echo "dnsmasq already installed:"
        echo "$DNSMASQ_BIN"

    else

        echo "dnsmasq not found."
        echo "Installing dnsmasq locally without Homebrew..."
        echo ""

        DNSMASQ_VERSION="2.93"
        DNSMASQ_TAR="dnsmasq-${DNSMASQ_VERSION}.tar.gz"
        DNSMASQ_URL="https://thekelleys.org.uk/dnsmasq/${DNSMASQ_TAR}"

        BUILD_DIR="$HOME/cn-phase1/dnsmasq-build"

        rm -rf "$BUILD_DIR"
        mkdir -p "$BUILD_DIR"

        cd "$BUILD_DIR"

        echo "Downloading dnsmasq ${DNSMASQ_VERSION}..."

        curl -L \
            "$DNSMASQ_URL" \
            -o "$DNSMASQ_TAR"

        echo "Extracting..."

        tar -xzf "$DNSMASQ_TAR"

        cd "dnsmasq-${DNSMASQ_VERSION}"

        echo "Building dnsmasq..."

        make

        echo "Installing local copy..."

        cp src/dnsmasq "$DNSMASQ_INSTALL/dnsmasq"

        chmod +x "$DNSMASQ_INSTALL/dnsmasq"

        DNSMASQ_BIN="$DNSMASQ_INSTALL/dnsmasq"

        echo ""
        echo "dnsmasq installed locally:"
        echo "$DNSMASQ_BIN"

    fi

    echo ""

    # ------------------------------------------
    # Verify dnsmasq binary
    # ------------------------------------------

    "$DNSMASQ_BIN" --version | head -n 1

    echo ""

    # ------------------------------------------
    # Check UDP 53
    # ------------------------------------------

    echo "Checking UDP port 53..."

    if sudo lsof -nP -iUDP:"$DNS_PORT" | grep -q LISTEN; then

        echo ""
        echo "ERROR: UDP port $DNS_PORT is already in use."
        echo ""
        sudo lsof -nP -iUDP:"$DNS_PORT"
        echo ""
        echo "Stop the existing DNS service before continuing."
        exit 1

    fi

    echo "UDP $DNS_PORT is available."
    echo ""

    # ------------------------------------------
    # Create dnsmasq configuration
    # ------------------------------------------

    cat > "$DNSMASQ_DIR/dnsmasq.conf" <<EOF

# ==========================================
# Computer Networks Phase 1
# Mac 1 - Private DNS
# ==========================================

# DNS port
port=$DNS_PORT

# Listen only on Mac 1
interface=$INTERFACE
listen-address=127.0.0.1
listen-address=$MAC1_IP
bind-interfaces

# Do not provide DHCP
no-dhcp-interface=$INTERFACE

# Do not forward malformed/private names
domain-needed
bogus-priv

# Our private project domain
local=/team1.test/

# Project DNS records
address=/app.team1.test/$MAC2_IP
address=/api.team1.test/$MAC2_IP

# Cache DNS answers
cache-size=150

# Log queries for demonstration/debugging
log-queries

EOF

    echo "dnsmasq configuration created:"
    echo "$DNSMASQ_DIR/dnsmasq.conf"
    echo ""

    # ------------------------------------------
    # Validate configuration
    # ------------------------------------------

    echo "Validating dnsmasq configuration..."

    "$DNSMASQ_BIN" \
        --test \
        --conf-file="$DNSMASQ_DIR/dnsmasq.conf"

    echo ""
    echo "Configuration is valid."
    echo ""

    # ------------------------------------------
    # Save binary path
    # ------------------------------------------

    cat > "$DNSMASQ_DIR/start_dns.sh" <<EOF
#!/bin/bash

DNSMASQ_BIN="$DNSMASQ_BIN"
CONFIG="$DNSMASQ_DIR/dnsmasq.conf"

echo "=========================================="
echo " Mac 1 - dnsmasq"
echo "=========================================="
echo "DNS server : $MAC1_IP"
echo "Port       : $DNS_PORT"
echo ""
echo "app.team1.test -> $MAC2_IP"
echo "api.team1.test -> $MAC2_IP"
echo ""
echo "Starting dnsmasq..."
echo ""

sudo "\$DNSMASQ_BIN" \
    --no-daemon \
    --conf-file="\$CONFIG"
EOF

    chmod +x "$DNSMASQ_DIR/start_dns.sh"

    # ------------------------------------------
    # Test commands
    # ------------------------------------------

    echo "=========================================="
    echo " MAC 1 DNS SETUP COMPLETE"
    echo "=========================================="
    echo ""

    echo "DNS server:"
    echo "  $MAC1_IP:$DNS_PORT"
    echo ""

    echo "Records:"
    echo "  app.team1.test -> $MAC2_IP"
    echo "  api.team1.test -> $MAC2_IP"
    echo ""

    echo "Start DNS with:"
    echo ""
    echo "  $DNSMASQ_DIR/start_dns.sh"
    echo ""

    echo "Then test locally:"
    echo ""
    echo "  dig @127.0.0.1 app.team1.test"
    echo ""
    echo "  dig @$MAC1_IP app.team1.test"
    echo ""

    echo "Other Macs should use:"
    echo ""
    echo "  DNS server: $MAC1_IP"
    echo ""

    echo "=========================================="
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