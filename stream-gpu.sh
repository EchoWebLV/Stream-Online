#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# stream-gpu.sh — GPU-accelerated website streaming to pump.fun
#
# For Vast.ai Linux Desktop instances (or any machine with NVIDIA GPU).
# Uses Chrome with GPU rendering + FFmpeg NVENC hardware encoding.
###############################################################################

STREAM_URL="${STREAM_URL:?Set STREAM_URL to the website you want to stream}"
STREAM_KEY="${STREAM_KEY:?Set STREAM_KEY to your pump.fun stream key}"

RTMP_SERVER="${RTMP_SERVER:-rtmps://pump-prod-tg2x8veh.rtmp.livekit.cloud/x}"
RESOLUTION="${RESOLUTION:-1920x1080}"
WIDTH="${RESOLUTION%x*}"
HEIGHT="${RESOLUTION#*x}"
FPS="${FPS:-30}"
BITRATE="${BITRATE:-3000k}"
AUDIO_BITRATE="${AUDIO_BITRATE:-128k}"
DISPLAY_NUM="${DISPLAY_NUM:-0}"

cleanup() {
    echo "[stream] Shutting down..."
    kill "$CHROME_PID" 2>/dev/null || true
    kill "$PULSE_PID" 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

if [[ "$DISPLAY_NUM" == "0" ]] && ! xdpyinfo -display ":0" &>/dev/null; then
    echo "[stream] No existing display found, starting Xvfb"
    Xvfb ":99" -screen 0 "${RESOLUTION}x24" -ac +extension GLX +render -noreset &
    DISPLAY_NUM=99
    sleep 2
fi

export DISPLAY=":${DISPLAY_NUM}"
echo "[stream] Using display :${DISPLAY_NUM}"

echo "[stream] GPU info:"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null || echo "  (nvidia-smi not found, will try NVENC anyway)"

echo "[stream] Setting up PulseAudio"
pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
PULSE_PID=$(pgrep -f "pulseaudio" | head -1) || true
pactl load-module module-null-sink sink_name=virtual_speaker sink_properties=device.description=VirtualSpeaker 2>/dev/null || true
pactl set-default-sink virtual_speaker 2>/dev/null || true

echo "[stream] Launching Chrome (GPU-accelerated) → ${STREAM_URL}"
google-chrome \
    --no-sandbox \
    --enable-gpu-rasterization \
    --enable-zero-copy \
    --enable-features=VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization \
    --ignore-gpu-blocklist \
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
    --user-data-dir=/tmp/chrome-stream \
    "${STREAM_URL}" &
CHROME_PID=$!
sleep 5

RTMP_DEST="${RTMP_SERVER}/${STREAM_KEY}"

HAS_NVENC=false
if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q h264_nvenc; then
    HAS_NVENC=true
    echo "[stream] NVENC hardware encoder detected"
fi

echo "[stream] Starting FFmpeg → ${RTMP_DEST}"
if $HAS_NVENC; then
    ffmpeg \
        -nostdin \
        -f x11grab \
            -video_size "${RESOLUTION}" \
            -framerate "${FPS}" \
            -draw_mouse 0 \
            -i ":${DISPLAY_NUM}" \
        -f pulse \
            -i virtual_speaker.monitor \
        -c:v h264_nvenc \
            -preset p4 \
            -tune ll \
            -rc cbr \
            -b:v "${BITRATE}" \
            -maxrate "${BITRATE}" \
            -bufsize "$(echo "${BITRATE}" | sed 's/k//')k" \
            -pix_fmt yuv420p \
            -g "$((FPS * 2))" \
        -c:a aac \
            -b:a "${AUDIO_BITRATE}" \
            -ar 44100 \
        -f flv \
        -tls_verify 0 \
        "${RTMP_DEST}"
else
    echo "[stream] WARNING: NVENC not available, falling back to CPU encoding"
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
            -preset veryfast \
            -tune zerolatency \
            -maxrate "${BITRATE}" \
            -bufsize "$(echo "${BITRATE}" | sed 's/k//')k" \
            -pix_fmt yuv420p \
            -g "$((FPS * 2))" \
        -c:a aac \
            -b:a "${AUDIO_BITRATE}" \
            -ar 44100 \
        -f flv \
        -tls_verify 0 \
        "${RTMP_DEST}"
fi
