# Computer Networks Course Project: Private Network Service Platform

This repository contains the configuration and scripts for our team's Private Network Service Platform project (Phase 1). The goal of this project is to build a complete local service reachable through a private domain name, demonstrating the full protocol flow from DNS resolution to TCP connection, and HTTP request handling.

## 🏗️ Architecture & Topology

The project is deployed entirely locally across 4 macOS laptops connected to the same private network (LAN/Wi-Fi). The roles are distributed as follows:

- **Mac 1 - Private DNS Server:** Runs a local `dnsmasq` instance that resolves our private project domain (`app.team1.test` and `api.team1.test`) to the edge proxy.
- **Mac 2 - Edge / Load Balancer:** Acts as the single entry point. It receives requests for the domain and load-balances them across the two backend servers.
- **Mac 3 - Backend Server A:** Runs a Python REST API backend on port 3001.
- **Mac 4 - Backend Server B:** Runs a Python REST API backend on port 3002.

## 🛠️ Features Implemented

- **Private LAN Setup**: Configuration of a private local network for seamless machine-to-machine communication.
- **Custom DNS Resolution**: A lightweight `dnsmasq` server configured on Mac 1 to handle DNS queries for the `.test` private domain namespace.
- **Custom Reverse Proxy & Load Balancer**: A Python-based proxy server (`edge_server.py`) running on Mac 2 that distributes incoming traffic in a round-robin fashion to Mac 3 and Mac 4.
- **RESTful Backend Services**: Two simple Python HTTP servers (`backend.py`) that respond with JSON data, including backend identifiers (`X-Backend` header).
- **HTTP Caching**: Implementation of `Cache-Control` (`max-age=60`) and `ETag` headers to support conditional requests (`304 Not Modified`) in the backend services.

## 📁 Repository Structure

- `setup.sh`: The core deployment script. It detects the machine's role and installs/configures the necessary services (DNS, Edge Proxy, or Backend).
- `config.env`: Environment variables file containing the IP configurations and ports for the 4 Macs.
- `backend.py`: The Python source code for the HTTP/REST backend services.
- `test-phase1.sh`: An automated test script to verify DNS resolution, backend availability, load balancing, and HTTP caching headers.

## 🚀 How to Run

1. Connect all 4 Macs to the same private Wi-Fi/LAN.
2. Update the `config.env` file with the correct IPs of each machine.
3. On each Mac, run the setup script with its corresponding role:
   ```bash
   ./setup.sh mac1  # On Mac 1 (DNS)
   ./setup.sh mac2  # On Mac 2 (Edge/Proxy)
   ./setup.sh mac3  # On Mac 3 (Backend A)
   ./setup.sh mac4  # On Mac 4 (Backend B)
   ```
4. Once all services are running, you can run the test script from any client machine connected to the DNS server:
   ```bash
   ./test-phase1.sh
   ```
