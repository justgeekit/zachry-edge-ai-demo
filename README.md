# Zachry R&D — Edge AI Demo (Jetson AGX Orin)

**Women in Construction Week / Career Exploration Program**

A fully offline, GPU-accelerated AI assistant and computer vision demo running
on NVIDIA Jetson AGX Orin edge hardware. No cloud connection required.

---

## Overview

This repository packages the full configuration, scripts, and documentation for
a tabletop edge AI demo featuring:

- **GLM-4.7-Flash** — a 16B MoE large language model running entirely on-device
  via [Ollama](https://ollama.com), answering student questions about construction
  careers, technology, and the industry
- **Open WebUI** — a polished chat interface accessible from any browser on the
  local network
- **Real-time object detection** — via NVIDIA's `detectnet` and a live RTSP
  camera stream from a Seeed Studio reCamera

The demo is designed for a tabletop event: power on the Jetson, run one script,
and everything is ready.

---

## Hardware

| Component | Details |
|---|---|
| **Edge AI Computer** | NVIDIA Jetson AGX Orin (ZCRD-NV-ORIN-AGX-0964) |
| **SoC** | Orin Ampere GPU, 12-core Arm Cortex-A78AE CPU |
| **Memory** | 61.3 GiB unified (GPU + CPU shared) |
| **Storage** | 3.7 TB NVMe SSD (Samsung, /data) |
| **OS** | JetPack 5.1.2 / L4T r35.4.1 / Ubuntu 20.04 / CUDA 11.4 |
| **Camera** | Seeed Studio reCamera 2002w 64GB |
| **Camera SoC** | RISC-V SG2002, OV5647 sensor, 5MP, WiFi/BT |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Jetson AGX Orin                         │
│                                                             │
│  ┌──────────────────┐      ┌──────────────────────────────┐ │
│  │  ollama-gpu      │      │  open-webui                  │ │
│  │  (Docker)        │◄─────│  (Docker)                    │ │
│  │  port 11434      │      │  port 3000                   │ │
│  │  GLM-4.7-Flash   │      │  Browser UI                  │ │
│  │  48/48 GPU layers│      │  http://localhost:3000        │ │
│  └──────────────────┘      └──────────────────────────────┘ │
│           ▲                                                  │
│           │ ollama-net (bridge)                              │
│                                                             │
│  ┌──────────────────┐                                       │
│  │  detectnet       │◄── RTSP stream (reCamera)             │
│  │  (Docker, CV)    │    rtsp://192.168.42.1:554/live        │
│  └──────────────────┘                                       │
└─────────────────────────────────────────────────────────────┘
          ▲                            ▲
    USB-C tether                  HDMI display
    reCamera 2002w              (or browser on LAN)
```

---

## Prerequisites (one-time)

- JetPack 5.1.2 / L4T r35.4.1 installed on the Jetson
- Docker CE 28+ with NVIDIA Container Toolkit
- NVMe drive mounted at `/data`
- `jtop` installed: `sudo pip3 install jetson-stats`
- `lazydocker` installed: see [lazydocker releases](https://github.com/jesseduffield/lazydocker/releases)
- Ollama v0.17.2 release archives (see Step 3 below)

---

## One-Time Setup

### 1. Clone this repository

```bash
git clone https://github.com/toddsutton/zachry-edge-ai-demo.git /data/repos/zachry-edge-ai-demo
cd /data/repos/zachry-edge-ai-demo
```

### 2. Configure Docker daemon

```bash
sudo cp docker/daemon.json /etc/docker/daemon.json
sudo systemctl restart docker
```

This sets Docker's data root to `/data/docker` and makes `nvidia` the default runtime.

### 3. Build the Ollama Docker image

Download two archives from the [Ollama v0.17.2 release page](https://github.com/ollama/ollama/releases/tag/v0.17.2):

| File on GitHub | Rename to |
|---|---|
| `ollama-linux-arm64.tar.zst` | `ollama-arm64.tar.zst` |
| `ollama-linux-arm64-jetpack5.tar.zst` | `ollama-jetpack5.tar.zst` |

Place both files in `docker/`, then build:

```bash
cd docker/
docker build -t ollama-jp5:v0.17.2 .
```

> **Note:** The `*.tar.zst` files are excluded from git (see `.gitignore`) because
> they are ~1.5 GB combined. Always download them fresh from the GitHub release.

### 4. Create model and log directories

```bash
mkdir -p /data/ollama-docker/models /data/ollama-docker/logs
mkdir -p /data/open-webui
```

### 5. Pull the GLM-4.7-Flash model

```bash
# Start a temporary Ollama container to pull the model
sudo systemctl start ollama-docker
curl http://127.0.0.1:11434/api/pull -d '{"name":"glm-4.7-flash"}'
```

### 6. Install the systemd service

```bash
sudo cp systemd/ollama-docker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ollama-docker
```

### 7. Set up the Docker network

```bash
docker network create ollama-net
```

### 8. Set the system prompt in Open WebUI

After the first start (see Daily Use below), go to:

**Open WebUI → Admin Panel → Models → glm-4.7-flash → System Prompt**

Copy and paste the prompt from [`docs/system-prompt.md`](docs/system-prompt.md).

---

## Daily Use — Starting the Demo

```bash
cd /data/repos/zachry-edge-ai-demo
./scripts/demo-start.sh
```

The script will:
1. Start the `ollama-docker` systemd service
2. Wait for Ollama to become ready
3. Ensure the `ollama-net` Docker network is configured
4. Start `open-webui` (or confirm it's already running)
5. Wait for Open WebUI to become healthy
6. Print a status table with all service URLs
7. Offer a menu to launch `lazydocker` and/or `jtop`

To stop everything cleanly:

```bash
./scripts/demo-stop.sh
```

---

## Computer Vision Demo (reCamera)

### Connect the camera

1. Plug the reCamera into the Jetson via USB-C
2. Confirm connectivity: `ping 192.168.42.1`
3. The RTSP stream is available at: `rtsp://admin:admin@192.168.42.1:554/live`

> **IP conflict warning:** The Verizon MiFi5510L USB tether also uses the
> `192.168.42.x` subnet. Do **not** use both USB devices simultaneously.
> Use the MiFi via WiFi for internet access when the reCamera is USB-tethered.

### Run object detection

```bash
sudo docker run --runtime nvidia -it --rm \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  dustynv/jetson-inference:r35.4.1 \
  detectnet rtsp://admin:admin@192.168.42.1:554/live
```

This runs NVIDIA's DetectNet on the live camera feed, drawing bounding boxes
around detected objects in real time using the Jetson GPU.

---

## Demo Tutorial — Event Day Script

### Talking points for students

**Opening hook:**
> "This little computer — about the size of a paperback book — is running a
> 16-billion-parameter AI model entirely on its own chip. No internet. No cloud.
> Just this device. That same technology is starting to show up on job sites."

**Career conversation:**
Start with the AI chat. Good opening prompts:
- *"What kinds of jobs exist in construction besides physical labor?"*
- *"How is AI being used on construction job sites today?"*
- *"What does a project engineer actually do?"*

See [`docs/system-prompt.md`](docs/system-prompt.md) for the full list of
suggested prompts.

**Computer vision transition:**
> "Now let's show you what the camera sees. This is real-time object detection —
> the AI is identifying everything in the frame, 15 frames per second, on-device."

Run the `detectnet` command above. Point the reCamera at people, tools, or
equipment in the room.

**Closing:**
> "Construction is one of the last industries to fully embrace AI and robotics —
> which means the people who get in now will shape what it looks like. That could
> be you."

### Memory budget (all services simultaneously)

| Service | GPU memory |
|---|---|
| GLM-4.7-Flash model weights | ~17.5 GiB |
| KV cache (inference) | ~19.3 GiB |
| DetectNet (CV) | ~0.5 GiB |
| **Total** | **~37 GiB / 61 GiB available** |

All three services can run simultaneously with headroom to spare.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Open WebUI shows no models | Re-run `demo-start.sh` — network connect may be needed |
| Ollama not responding | `sudo systemctl status ollama-docker` → `sudo journalctl -u ollama-docker -n 50` |
| Open WebUI hangs on startup | Check it was started with `RAG_EMBEDDING_ENGINE=ollama` env var (see start script) |
| reCamera not reachable | Check `ip addr show usb1` — confirm `192.168.42.x` is up; check for MiFi USB conflict |
| `docker: Error response... nvidia runtime` | `sudo systemctl restart docker` then retry |
| jtop not found | `sudo pip3 install jetson-stats` |

---

## Repository Structure

```
zachry-edge-ai-demo/
├── README.md
├── .gitignore
├── systemd/
│   └── ollama-docker.service   # Systemd service for GPU Ollama container
├── docker/
│   ├── daemon.json             # Docker daemon config (data-root, nvidia runtime)
│   └── Dockerfile              # Build Ollama v0.17.2 for JetPack 5
├── scripts/
│   ├── demo-start.sh           # One-command demo startup + TUI menu
│   └── demo-stop.sh            # Graceful shutdown
└── docs/
    └── system-prompt.md        # Construction AI system prompt for Open WebUI
```

---

## Upgrading Ollama

Check for new JetPack 5 releases at:
```
https://github.com/ollama/ollama/releases/latest
```

Download both `arm64` and `arm64-jetpack5` archives, place them in `docker/`,
update the version tag in the `docker build` command and in
`systemd/ollama-docker.service`, rebuild, and reload the service.

---

*Built by Zachry R&D — running at the edge.*
