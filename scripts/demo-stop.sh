#!/usr/bin/env bash
# =============================================================================
# demo-stop.sh — Gracefully stop the Zachry R&D Edge AI Demo stack
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

info() { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()   { echo -e "${GREEN}[ OK ]${RESET}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║        Zachry R&D — Edge AI Demo — Stopping...          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Stop and remove open-webui
if sudo docker ps --format '{{.Names}}' | grep -qw "open-webui"; then
  info "Stopping open-webui container..."
  sudo docker stop open-webui && sudo docker rm open-webui
  ok "open-webui stopped and removed"
else
  warn "open-webui container not running — skipping"
fi

# Stop ollama-docker systemd service
info "Stopping ollama-docker service..."
sudo systemctl stop ollama-docker
ok "ollama-docker service stopped"

echo
ok "All demo services stopped."
