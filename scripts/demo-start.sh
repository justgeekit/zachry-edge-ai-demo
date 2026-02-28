#!/usr/bin/env bash
# =============================================================================
# demo-start.sh — Zachry R&D Edge AI Demo startup script
# Jetson AGX Orin | Ollama v0.17.2 + Open WebUI
# =============================================================================
set -euo pipefail

OLLAMA_PORT=11434
WEBUI_PORT=3000
OLLAMA_CONTAINER="ollama-gpu"
WEBUI_CONTAINER="open-webui"
OLLAMA_NETWORK="ollama-net"
WEBUI_IMAGE="ghcr.io/open-webui/open-webui:main"
WEBUI_DATA="/data/open-webui"

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

banner() {
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║        Zachry R&D — Edge AI Demo — Starting up...       ║"
  echo "║           Women in Construction Week / Jetson Orin       ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
fail()    { echo -e "${RED}[FAIL]${RESET}  $*"; }

# ── 1. Banner ─────────────────────────────────────────────────────────────────
banner

# ── 2. Start ollama-docker.service ────────────────────────────────────────────
info "Starting ollama-docker systemd service..."
sudo systemctl start ollama-docker
ok "ollama-docker service started (or already running)"

# ── 3. Wait for Ollama to respond on port 11434 ───────────────────────────────
info "Waiting for Ollama to become ready (up to 15s)..."
for i in $(seq 1 15); do
  if curl -sf http://127.0.0.1:${OLLAMA_PORT}/api/tags > /dev/null 2>&1; then
    ok "Ollama is ready (${i}s)"
    break
  fi
  if [ "$i" -eq 15 ]; then
    fail "Ollama did not respond after 15s. Check: sudo journalctl -u ollama-docker -n 50"
    exit 1
  fi
  sleep 1
done

# ── 4. Ensure ollama-net Docker network exists ────────────────────────────────
if ! sudo docker network inspect "${OLLAMA_NETWORK}" > /dev/null 2>&1; then
  info "Creating Docker network '${OLLAMA_NETWORK}'..."
  sudo docker network create "${OLLAMA_NETWORK}"
  ok "Network '${OLLAMA_NETWORK}' created"
else
  ok "Docker network '${OLLAMA_NETWORK}' already exists"
fi

# ── 5. Connect ollama-gpu to ollama-net if needed ─────────────────────────────
if sudo docker network inspect "${OLLAMA_NETWORK}" --format '{{range .Containers}}{{.Name}} {{end}}' \
    | grep -qw "${OLLAMA_CONTAINER}"; then
  ok "${OLLAMA_CONTAINER} already connected to ${OLLAMA_NETWORK}"
else
  info "Connecting ${OLLAMA_CONTAINER} to ${OLLAMA_NETWORK}..."
  sudo docker network connect "${OLLAMA_NETWORK}" "${OLLAMA_CONTAINER}"
  ok "${OLLAMA_CONTAINER} connected to ${OLLAMA_NETWORK}"
fi

# ── 6. Start open-webui container if not running ──────────────────────────────
if sudo docker ps --format '{{.Names}}' | grep -qw "${WEBUI_CONTAINER}"; then
  ok "${WEBUI_CONTAINER} is already running — skipping launch"
else
  # Remove any stopped container with the same name
  sudo docker rm -f "${WEBUI_CONTAINER}" > /dev/null 2>&1 || true

  info "Starting ${WEBUI_CONTAINER}..."
  sudo docker run -d \
    --name "${WEBUI_CONTAINER}" \
    --restart always \
    --network "${OLLAMA_NETWORK}" \
    -p "${WEBUI_PORT}":8080 \
    -e OLLAMA_BASE_URL="http://${OLLAMA_CONTAINER}:${OLLAMA_PORT}" \
    -e RAG_EMBEDDING_ENGINE=ollama \
    -e RAG_EMBEDDING_MODEL=glm-4.7-flash \
    -v "${WEBUI_DATA}":/app/backend/data \
    "${WEBUI_IMAGE}"
  ok "${WEBUI_CONTAINER} container started"
fi

# ── 7. Wait for Open WebUI to become healthy ──────────────────────────────────
info "Waiting for Open WebUI to become ready (up to 30s)..."
for i in $(seq 1 30); do
  if curl -sf http://127.0.0.1:${WEBUI_PORT} > /dev/null 2>&1; then
    ok "Open WebUI is ready (${i}s)"
    break
  fi
  if [ "$i" -eq 30 ]; then
    warn "Open WebUI did not respond after 30s — it may still be initialising."
    warn "Check: sudo docker logs ${WEBUI_CONTAINER}"
  fi
  sleep 1
done

# ── 8. Status table ───────────────────────────────────────────────────────────
echo
echo -e "${BOLD}════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Service / Container        Port     URL${RESET}"
echo -e "${BOLD}────────────────────────────────────────────────────────────${RESET}"
printf "  %-28s %-8s %s\n" "ollama-docker (systemd)" "11434" "http://127.0.0.1:11434"
printf "  %-28s %-8s %s\n" "${OLLAMA_CONTAINER} (docker)" "11434" "http://127.0.0.1:11434/api/tags"
printf "  %-28s %-8s %s\n" "${WEBUI_CONTAINER} (docker)" "${WEBUI_PORT}" "http://localhost:${WEBUI_PORT}"
echo -e "${BOLD}════════════════════════════════════════════════════════════${RESET}"
echo

# ── 9. TUI menu ───────────────────────────────────────────────────────────────
echo -e "${BOLD}What would you like to open?${RESET}"
echo "  [1] lazydocker  (container manager)"
echo "  [2] jtop        (GPU / system monitor)"
echo "  [3] Both        (lazydocker foreground, jtop in new window)"
echo "  [4] Neither     — just show status and exit"
echo
read -rp "Enter choice [1-4]: " choice

case "$choice" in
  1)
    info "Launching lazydocker..."
    lazydocker
    ;;
  2)
    info "Launching jtop..."
    jtop
    ;;
  3)
    info "Launching jtop in a background window..."
    if command -v gnome-terminal > /dev/null 2>&1; then
      gnome-terminal -- bash -c "jtop; exec bash" &
    elif command -v xterm > /dev/null 2>&1; then
      xterm -e "jtop" &
    else
      warn "No graphical terminal found. Run 'jtop' in a separate terminal."
    fi
    sleep 1
    info "Launching lazydocker..."
    lazydocker
    ;;
  4|"")
    ok "All services running. Exiting."
    ;;
  *)
    warn "Unrecognised choice — exiting. Run the script again to launch tools."
    ;;
esac

echo
ok "Demo stack is up. Good luck!"
