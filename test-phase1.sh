#!/bin/bash

set -e

source ./config.env

DOMAIN="app.$PROJECT_DOMAIN"

echo ""
echo "=========================================="
echo " PHASE 1 NETWORK TEST"
echo "=========================================="

echo ""
echo "1. Testing DNS..."
echo "------------------------------------------"

dig +short "$DOMAIN"

DNS_RESULT=$(dig +short "$DOMAIN")

if [ "$DNS_RESULT" = "$MAC2_IP" ]; then
    echo "✓ DNS PASS"
else
    echo "✗ DNS FAIL"
    echo "Expected: $MAC2_IP"
    echo "Got: $DNS_RESULT"
fi


echo ""
echo "2. Testing Backend A..."
echo "------------------------------------------"

curl -s \
    "http://$MAC3_IP:$BACKEND_A_PORT/api/status"

echo ""


echo ""
echo "3. Testing Backend B..."
echo "------------------------------------------"

curl -s \
    "http://$MAC4_IP:$BACKEND_B_PORT/api/status"

echo ""


echo ""
echo "4. Testing HTTPS..."
echo "------------------------------------------"

curl -I \
    "https://$DOMAIN/api/status"

echo ""


echo ""
echo "5. Testing load balancing..."
echo "------------------------------------------"

for i in {1..10}
do

    echo -n "Request $i: "

    curl -s \
        -D - \
        -o /dev/null \
        "https://$DOMAIN/api/status" |
        grep -i "^X-Backend:" |
        tr -d '\r'

done


echo ""
echo "6. Testing caching headers..."
echo "------------------------------------------"

curl -I \
    "https://$DOMAIN/api/status" |
    grep -Ei "cache-control|etag"


echo ""
echo "=========================================="
echo " TEST COMPLETE"
echo "=========================================="