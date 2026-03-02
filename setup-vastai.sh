#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# setup-vastai.sh — Quick setup for Vast.ai Linux Desktop instances
###############################################################################

echo "=== Installing dependencies ==="
apt-get update
apt-get install -y ffmpeg pulseaudio x11vnc novnc websockify git

if ! command -v google-chrome &>/dev/null; then
    echo "=== Installing Google Chrome ==="
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list
    apt-get update
    apt-get install -y google-chrome-stable
fi

chmod +x /root/Stream-Online/stream-gpu.sh

echo ""
echo "=== Setup complete ==="
echo "Run the stream with:"
echo "  export STREAM_KEY=XR2eKjicQoL8"
echo "  export STREAM_URL=https://hodlwarz.com"
echo "  export RTMP_SERVER=rtmps://pump-prod-tg2x8veh.rtmp.livekit.cloud/x"
echo "  /root/Stream-Online/stream-gpu.sh"
