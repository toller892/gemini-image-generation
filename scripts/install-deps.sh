#!/bin/bash
#
# install-deps.sh — Install all required dependencies for the viz stack.
# Supports Debian/Ubuntu (including Docker containers).
#
set -e

echo "[install] Checking and installing dependencies..."

MISSING=()

command -v Xvfb >/dev/null 2>&1 || MISSING+=("xvfb")
command -v x11vnc >/dev/null 2>&1 || MISSING+=("x11vnc")
command -v websockify >/dev/null 2>&1 || MISSING+=("websockify")
[ -f /usr/share/novnc/vnc.html ] || MISSING+=("novnc")
command -v cloudflared >/dev/null 2>&1 || MISSING+=("cloudflared")
command -v agent-browser >/dev/null 2>&1 || MISSING+=("agent-browser")

if [ ${#MISSING[@]} -eq 0 ]; then
    echo "[install] All dependencies already installed ✅"
    exit 0
fi

echo "[install] Missing: ${MISSING[*]}"

# Install apt packages
APT_PKGS=()
for dep in "${MISSING[@]}"; do
    case "$dep" in
        xvfb|x11vnc|websockify|novnc)
            APT_PKGS+=("$dep")
            ;;
    esac
done

if [ ${#APT_PKGS[@]} -gt 0 ]; then
    echo "[install] Installing apt packages: ${APT_PKGS[*]}"
    apt-get update -qq
    apt-get install -y -qq "${APT_PKGS[@]}"
fi

# Install cloudflared
if [[ " ${MISSING[*]} " == *" cloudflared "* ]]; then
    echo "[install] Installing cloudflared..."
    ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
    curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb" -o /tmp/cloudflared.deb
    dpkg -i /tmp/cloudflared.deb || apt-get install -f -y
    rm -f /tmp/cloudflared.deb
fi

# Install agent-browser
if [[ " ${MISSING[*]} " == *" agent-browser "* ]]; then
    echo "[install] Installing agent-browser..."
    npm install -g agent-browser
    agent-browser install  # Download Chromium
fi

echo "[install] Done ✅"

# Verify
echo "[install] Verification:"
for cmd in Xvfb x11vnc websockify cloudflared agent-browser; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  ✅ $cmd"
    else
        echo "  ❌ $cmd (still missing!)"
    fi
done
[ -f /usr/share/novnc/vnc.html ] && echo "  ✅ noVNC" || echo "  ❌ noVNC"
