#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# stream.sh — Capture a website with headless Chrome and stream it to pump.fun
#
# Required env vars:
#   STREAM_URL   – The website to display (e.g. https://hodlwarz.com)
#   STREAM_KEY   – Your pump.fun RTMP stream key
#
# Optional env vars:
#   RTMP_SERVER  – RTMP ingest URL (default: pump.fun's server)
#   RESOLUTION   – e.g. 1280x720  (default: 1920x1080)
#   FPS          – Frames per second (default: 30)
#   BITRATE      – Video bitrate   (default: 3000k)
#   AUDIO_BITRATE – Audio bitrate  (default: 128k)
###############################################################################

STREAM_URL="${STREAM_URL:?Set STREAM_URL to the website you want to stream}"
STREAM_KEY="${STREAM_KEY:?Set STREAM_KEY to your pump.fun stream key}"

RTMP_SERVER="${RTMP_SERVER:-rtmps://pump-prod-tg2x8veh.rtmp.livekit.cloud/x}"
RESOLUTION="${RESOLUTION:-1280x720}"
WIDTH="${RESOLUTION%x*}"
HEIGHT="${RESOLUTION#*x}"
FPS="${FPS:-30}"
BITRATE="${BITRATE:-2500k}"
AUDIO_BITRATE="${AUDIO_BITRATE:-96k}"
DISPLAY_NUM="${DISPLAY_NUM:-99}"

cleanup() {
    echo "[stream] Shutting down..."
    kill "$CHROME_PID" 2>/dev/null || true
    kill "$NOVNC_PID" 2>/dev/null || true
    kill "$PULSE_PID" 2>/dev/null || true
    kill "$XVFB_PID" 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

echo "[stream] Starting virtual display :${DISPLAY_NUM} at ${RESOLUTION}"
Xvfb ":${DISPLAY_NUM}" -screen 0 "${RESOLUTION}x24" -ac +extension GLX +render -noreset &
XVFB_PID=$!
sleep 2

export DISPLAY=":${DISPLAY_NUM}"

echo "[stream] Starting PulseAudio (virtual audio sink)"
pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
PULSE_PID=$(pgrep -f "pulseaudio" | head -1) || true

pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=VirtualSpeaker 2>/dev/null || true
pactl set-default-sink virtual_speaker 2>/dev/null || true

VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"

echo "[stream] Starting VNC server on port ${VNC_PORT}"
x11vnc -display ":${DISPLAY_NUM}" -forever -shared -nopw -rfbport "${VNC_PORT}" -bg -o /tmp/x11vnc.log 2>/dev/null

echo "[stream] Starting noVNC web client on port ${NOVNC_PORT}"
websockify --web /usr/share/novnc "${NOVNC_PORT}" localhost:"${VNC_PORT}" &
NOVNC_PID=$!
echo "[stream] Remote control available at http://<your-server-ip>:${NOVNC_PORT}/vnc.html"

echo "[stream] Launching Chrome → ${STREAM_URL}"
google-chrome \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --no-first-run \
    --no-default-browser-check \
    --autoplay-policy=no-user-gesture-required \
    --start-fullscreen \
    --window-size="${WIDTH},${HEIGHT}" \
    --kiosk \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --disable-translate \
    --disable-background-timer-throttling \
    --disable-backgrounding-occluded-windows \
    --disable-renderer-backgrounding \
    --disable-extensions \
    --disable-component-update \
    --disable-hang-monitor \
    --js-flags="--max-old-space-size=512" \
    --user-data-dir=/tmp/chrome-stream \
    "${STREAM_URL}" &
CHROME_PID=$!
sleep 5

RTMP_DEST="${RTMP_SERVER}/${STREAM_KEY}"
echo "[stream] Starting FFmpeg → ${RTMP_DEST}"
ffmpeg \
    -nostdin \
    -f x11grab \
        -video_size "${RESOLUTION}" \
        -framerate "${FPS}" \
        -draw_mouse 0 \
        -i ":${DISPLAY_NUM}" \
    -f pulse \
        -i virtual_speaker.monitor \
    -c:v libx264 \
        -preset ultrafast \
        -tune zerolatency \
        -crf 28 \
        -maxrate "${BITRATE}" \
        -bufsize "$(echo "${BITRATE}" | sed 's/k//')k" \
        -pix_fmt yuv420p \
        -g "$((FPS * 2))" \
        -threads 0 \
    -c:a aac \
        -b:a "${AUDIO_BITRATE}" \
        -ar 44100 \
    -f flv \
    -tls_verify 0 \
    "${RTMP_DEST}"
