# Stream-Online

Stream any website 24/7 to pump.fun (or any RTMP destination) from a cloud virtual machine.

This project uses **headless Chrome** to render a website, **Xvfb** for a virtual display, and **FFmpeg** to encode and push the video as a live RTMP stream. Everything runs inside **Docker** for easy deployment on any Linux VM.

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  Cloud VM (Ubuntu)                          │
│                                             │
│  Xvfb (virtual display)                    │
│    └── Chrome (renders hodlwarz.com)        │
│          └── FFmpeg (captures → RTMP)       │
│                └── pump.fun live stream     │
└─────────────────────────────────────────────┘
```

## Quick Start (5 minutes)

### 1. Get a Cloud VM

Any provider works. Recommended specs:

| Provider | Plan | Cost |
|----------|------|------|
| **Hetzner** | CPX21 (3 vCPU, 4 GB RAM) | ~€8/mo |
| **DigitalOcean** | Basic Droplet (2 vCPU, 4 GB) | ~$24/mo |
| **Vultr** | Cloud Compute (2 vCPU, 4 GB) | ~$24/mo |
| **AWS** | t3.medium (2 vCPU, 4 GB) | ~$30/mo |
| **Contabo** | VPS S (4 vCPU, 8 GB) | ~€5/mo |

> **Minimum requirements:** 2 vCPU, 4 GB RAM, Ubuntu 22.04+

### 2. Get Your pump.fun Stream Key

1. Go to [pump.fun](https://pump.fun)
2. Create or go to your token page
3. Click **"Start Stream"** or **"Go Live"**
4. Copy the **Stream Key** (it will look something like a long alphanumeric string)
5. Note the **RTMP Server URL** (usually `rtmp://stream.pump.fun/live`)

### 3. Deploy to Your VM

SSH into your VM and run:

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/Stream-Online.git
cd Stream-Online

# Run the setup (installs Docker, configures everything)
sudo bash setup-vm.sh

# Set your stream key
sudo nano /opt/stream-online/.env
# Change STREAM_KEY=your-stream-key-here to your actual key

# Start streaming!
sudo systemctl start stream-online
```

That's it. The stream will now run 24/7 and auto-restart on crash or reboot.

### 4. Manage the Stream

```bash
# Check if it's running
sudo systemctl status stream-online

# View live logs
sudo journalctl -u stream-online -f

# Stop the stream
sudo systemctl stop stream-online

# Restart the stream
sudo systemctl restart stream-online

# Disable auto-start on boot
sudo systemctl disable stream-online
```

---

## Alternative: Run with Docker Compose Directly

If you prefer not to use the systemd service:

```bash
# Copy and edit your .env
cp .env.example .env
nano .env   # set your STREAM_KEY

# Start (runs in background, auto-restarts)
docker compose up -d --build

# View logs
docker compose logs -f

# Stop
docker compose down
```

---

## Configuration

All settings are in the `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `STREAM_KEY` | *(required)* | Your pump.fun stream key |
| `STREAM_URL` | `https://hodlwarz.com` | Website to stream |
| `RTMP_SERVER` | `rtmp://stream.pump.fun/live` | RTMP ingest server |
| `RESOLUTION` | `1920x1080` | Video resolution |
| `FPS` | `30` | Frames per second |
| `BITRATE` | `3000k` | Video bitrate |

### Lower Resource Usage

If your VM has limited resources, use 720p:

```env
RESOLUTION=1280x720
FPS=24
BITRATE=2000k
```

---

## Troubleshooting

### Stream not showing on pump.fun
- Double-check your `STREAM_KEY` in `.env`
- Verify the `RTMP_SERVER` URL matches what pump.fun shows
- Check logs: `sudo journalctl -u stream-online -f`

### High CPU usage
- Lower the resolution and FPS in `.env`
- Use `RESOLUTION=1280x720` and `FPS=24`

### Chrome crashes
- Make sure your VM has at least 4 GB RAM
- The Docker container uses `shm_size: 2gb` — this is required for Chrome

### Stream keeps disconnecting
- Check your VM's network stability
- Lowering `BITRATE` can help on slower connections
- The systemd service will auto-restart within 10 seconds

---

## Files

| File | Purpose |
|------|---------|
| `stream.sh` | Main script — launches Xvfb, Chrome, and FFmpeg |
| `Dockerfile` | Builds the container with Chrome + FFmpeg |
| `docker-compose.yml` | Orchestrates the container with env vars |
| `setup-vm.sh` | One-command VM setup (Docker + systemd) |
| `stream-online.service` | systemd unit for 24/7 auto-restart |
| `.env.example` | Template for configuration |

## License

MIT
