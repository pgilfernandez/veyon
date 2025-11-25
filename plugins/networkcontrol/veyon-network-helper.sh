#!/bin/bash
# Veyon Network Control Helper
# This script runs with elevated privileges to control network routes
# WITHOUT requiring a password prompt

set -e

GATEWAY_FILE="/tmp/veyon-network-control-gateway"
ACTIVE_FILE="/tmp/veyon-network-control-active"

disable_internet() {
    echo "Disabling internet access..."

    # Get current default gateway
    ROUTE_OUTPUT=$(/sbin/route -n get default 2>/dev/null || echo "")

    if [ -z "$ROUTE_OUTPUT" ]; then
        echo "ERROR: No default route found"
        exit 1
    fi

    # Parse gateway and interface
    GATEWAY=$(echo "$ROUTE_OUTPUT" | grep "gateway:" | awk '{print $2}')
    INTERFACE=$(echo "$ROUTE_OUTPUT" | grep "interface:" | awk '{print $2}')

    if [ -z "$GATEWAY" ]; then
        echo "ERROR: Could not detect gateway"
        exit 1
    fi

    echo "Detected gateway: $GATEWAY on interface: $INTERFACE"

    # Save gateway information
    echo "$GATEWAY" > "$GATEWAY_FILE"
    echo "$INTERFACE" >> "$GATEWAY_FILE"
    chmod 644 "$GATEWAY_FILE"

    # Delete default route
    /sbin/route -n delete default

    if [ $? -eq 0 ]; then
        echo "route" > "$ACTIVE_FILE"
        chmod 644 "$ACTIVE_FILE"
        echo "SUCCESS: Internet disabled"
        exit 0
    else
        echo "ERROR: Failed to delete route"
        exit 1
    fi
}

enable_internet() {
    echo "Enabling internet access..."

    # Check if there's an active block
    if [ ! -f "$ACTIVE_FILE" ]; then
        echo "INFO: No active network control found"
        exit 0
    fi

    # Read saved gateway info
    if [ ! -f "$GATEWAY_FILE" ]; then
        echo "ERROR: Gateway file not found"
        exit 1
    fi

    GATEWAY=$(head -1 "$GATEWAY_FILE" | tr -d '\n\r')
    INTERFACE=$(tail -1 "$GATEWAY_FILE" | tr -d '\n\r')

    if [ -z "$GATEWAY" ]; then
        echo "ERROR: Gateway information is empty"
        exit 1
    fi

    echo "Restoring gateway: $GATEWAY"

    # Restore default route
    /sbin/route -n add default "$GATEWAY"

    if [ $? -eq 0 ]; then
        rm -f "$ACTIVE_FILE" "$GATEWAY_FILE"
        echo "SUCCESS: Internet enabled"
        exit 0
    else
        echo "ERROR: Failed to restore route"
        exit 1
    fi
}

# Main
case "$1" in
    disable)
        disable_internet
        ;;
    enable)
        enable_internet
        ;;
    *)
        echo "Usage: $0 {disable|enable}"
        exit 1
        ;;
esac
