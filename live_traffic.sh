#!/bin/bash

SSH_USER="systeam"

echo "=============================================="
echo " CLOUDWAYS DYNAMIC LIVE TRAFFIC STREAMER"
echo "=============================================="
echo

# Redirect read input to /dev/tty so 'curl | bash' waits for keyboard input
printf "Enter Target Server IP: "
read -r TARGET_IP < /dev/tty
TARGET_IP=$(echo "$TARGET_IP" | tr -d '[:space:]')

if [ -z "$TARGET_IP" ]; then
    echo
    echo "[ERROR] Target Server IP is required."
    exit 1
fi

printf "Save output to a text file on Proxy Server? [y/N]: "
read -r SAVE_LOG < /dev/tty
SAVE_LOG=$(echo "$SAVE_LOG" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

LOG_OUTPUT_FILE=""
if [[ "$SAVE_LOG" == "y" || "$SAVE_LOG" == "yes" ]]; then
    printf "Enter proxy log filename (default: live_stream.log): "
    read -r LOG_OUTPUT_FILE < /dev/tty
    LOG_OUTPUT_FILE=$(echo "$LOG_OUTPUT_FILE" | tr -d '[:space:]')
    [ -z "$LOG_OUTPUT_FILE" ] && LOG_OUTPUT_FILE="live_stream.log"
    echo "Live stream will also be saved to: /home/sca/${LOG_OUTPUT_FILE}"
fi

echo
echo "Connecting to $TARGET_IP..."
sleep 1

# Clear Proxy Terminal Screen ONCE at launch
clear
