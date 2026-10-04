# Computer Networks Course Project: Private Network Service Platform

This repository contains the configuration and scripts for our team's Private Network Service Platform project. The goal of this project is to build a complete local service reachable through a private domain name with full packet evidence of the DNS → TCP → TLS → HTTP flow.

## Project Structure

- `setup.sh`: The main deployment script for setting up each Mac role.
- `config.env`: Environment variables and IP configurations for the 4 Macs.
- `backend.py`: A simple Python HTTP/REST backend service.
- `test-phase1.sh`: A script to test DNS resolution, backend availability, load balancing, and caching.

## Architecture

The project is deployed across 4 macOS laptops connected to the same local network:

- **Mac 1 (10.81.95.189)**: Private DNS Server (dnsmasq) + Test Client
- **Mac 2 (10.81.95.225)**: Edge / Reverse Proxy + Load Balancer
- **Mac 3 (10.81.95.70)**: Backend Server A (port 3001)
- **Mac 4 (10.81.95.68)**: Backend Server B (port 3002)

## Usage

1. Connect all 4 Macs to the same private Wi-Fi/LAN.
2. Update the `config.env` file with the correct IPs of each machine.
3. On each Mac, run the setup script with its corresponding role:
   - Mac 1: `./setup.sh mac1`
   - Mac 2: `./setup.sh mac2`
   - Mac 3: `./setup.sh mac3`
   - Mac 4: `./setup.sh mac4`

## Current Status

We have implemented the foundational tasks for Phase 1, including:
- Creating the project structure and deployment scripts.
- Implementing the DNS server configuration (`dnsmasq`).
- Creating the backend applications with proper HTTP headers (`Cache-Control`, `ETag`).
- Writing test scripts.

---

## Tasks Remaining

Based on the project requirements, the following tasks are still pending:

### Phase 1: Build & Observe
- [ ] **Task D & E (Nginx & TLS)**: The current `setup.sh` configures a Python proxy (`edge_server.py`) for Mac 2. The project explicitly requires using **Nginx** as the reverse proxy and load balancer. We need to replace the Python script with an Nginx configuration (`nginx.conf`) and configure it to terminate TLS.
- [ ] **Task E (TLS Certificates)**: Generate a self-signed TLS certificate (using OpenSSL or mkcert) for `app.team1.test` and install it on the Nginx edge server and trust it on client Macs.
- [ ] **Task G (Packet Capture)**: Perform the Wireshark packet captures for the final protocol flow (DNS, TCP Handshake, TLS Handshake, HTTP Headers).

### Deliverables to Create
- [ ] **Architecture Document**: Network topology diagram, IP table, request-flow diagram showing each protocol layer.
- [ ] **Configuration Bundle**: Collect `dnsmasq.conf`, `nginx.conf`, TLS notes, and backend launch instructions into one folder.
- [ ] **Evidence Folder**: Screenshots/exports of DNS resolution, curl/browser output with headers, and Wireshark captures for DNS, TCP handshake, TLS handshake, and HTTP caching demo.
- [ ] **Phase 1 Checkpoint**: Prepare for a working live system demonstration.
