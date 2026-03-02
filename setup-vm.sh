#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vm.sh — One-command setup for a fresh Ubuntu 22.04+ VM
#
# Usage:  sudo bash setup-vm.sh
###############################################################################

if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root:  sudo bash setup-vm.sh"
    exit 1
fi

echo "=== [1/4] Installing Docker ==="
if ! command -v docker &>/dev/null; then
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    echo "Docker installed."
else
    echo "Docker already installed, skipping."
fi

echo ""
echo "=== [2/4] Setting up project directory ==="
PROJECT_DIR="/opt/stream-online"
mkdir -p "$PROJECT_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/stream.sh"          "$PROJECT_DIR/"
cp "$SCRIPT_DIR/Dockerfile"         "$PROJECT_DIR/"
cp "$SCRIPT_DIR/docker-compose.yml" "$PROJECT_DIR/"
chmod +x "$PROJECT_DIR/stream.sh"

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$PROJECT_DIR/.env"
    echo ""
    echo "!! IMPORTANT: Edit /opt/stream-online/.env and set your STREAM_KEY !!"
    echo "   nano /opt/stream-online/.env"
    echo ""
fi

echo ""
echo "=== [3/4] Installing systemd service ==="
cp "$SCRIPT_DIR/stream-online.service" /etc/systemd/system/stream-online.service
systemctl daemon-reload
systemctl enable stream-online.service
echo "Service installed and enabled on boot."

echo ""
echo "=== [4/4] Done! ==="
echo ""
echo "Next steps:"
echo "  1. Edit your stream key:   nano /opt/stream-online/.env"
echo "  2. Start the stream:       sudo systemctl start stream-online"
echo "  3. Check status:           sudo systemctl status stream-online"
echo "  4. View logs:              sudo journalctl -u stream-online -f"
echo ""
echo "The stream will auto-restart on crash and on VM reboot."
