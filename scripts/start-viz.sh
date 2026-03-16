#!/bin/bash
#
# start-viz.sh — Start visualization stack + Chromium with persistent profile
#
#   1. Xvfb (virtual display)
#   2. x11vnc (VNC server)  
#   3. websockify + noVNC (web VNC client)
#   4. Chromium via agent-browser (persistent profile, renders on Xvfb)
#   5. Idle watchdog (auto-shutdown)
#   6. Cloudflare Quick Tunnel (public access)
#
# Usage:
#   bash start-viz.sh                    # Normal start (Gemini pre-loaded)
#   bash start-viz.sh --login            # First-time login mode (headed, wait for user)
#   bash start-viz.sh --url <url>        # Open custom URL
#
set -uo pipefail

DISPLAY_NUM=${DISPLAY_NUM:-99}
VNC_PORT=${VNC_PORT:-5900}
NOVNC_PORT=${NOVNC_PORT:-6080}
RESOLUTION=${RESOLUTION:-1280x720x24}
IDLE_TIMEOUT=${IDLE_TIMEOUT:-600}
BROWSER_PROFILE="${BROWSER_PROFILE:-$HOME/.agent-browser/profiles/gemini}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="/tmp/gemini-viz.pids"
URL_FILE="/tmp/gemini-viz.url"

TARGET_URL="https://gemini.google.com"
LOGIN_MODE=false

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --login) LOGIN_MODE=true; shift ;;
        --url) TARGET_URL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

export DISPLAY=":${DISPLAY_NUM}"
unset WAYLAND_DISPLAY 2>/dev/null || true

# Clear proxy variables — cloud servers connect directly
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy 2>/dev/null || true

# ---- Cleanup any previous run ----
if [ -f "$PID_FILE" ]; then
    bash "${SCRIPT_DIR}/stop-viz.sh" 2>/dev/null || true
fi
> "$PID_FILE"

# ---- 1. Xvfb ----
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
sleep 0.5
nohup Xvfb ":${DISPLAY_NUM}" -screen 0 "${RESOLUTION}" > /dev/null 2>&1 &
XVFB_PID=$!
disown $XVFB_PID
echo "$XVFB_PID" >> "$PID_FILE"
sleep 1
echo "[viz] Xvfb started on :${DISPLAY_NUM} (PID $XVFB_PID)"

# ---- 2. x11vnc ----
pkill -f "x11vnc.*:${DISPLAY_NUM}" 2>/dev/null || true
sleep 0.5
x11vnc -display ":${DISPLAY_NUM}" -rfbport "${VNC_PORT}" -nopw -forever -shared -bg > /dev/null 2>&1
sleep 1
X11VNC_PID=$(pgrep -f "x11vnc.*:${DISPLAY_NUM}" 2>/dev/null | head -1)
if [ -n "$X11VNC_PID" ]; then
    echo "$X11VNC_PID" >> "$PID_FILE"
    echo "[viz] x11vnc started on :${VNC_PORT} (PID $X11VNC_PID)"
else
    echo "[viz] WARNING: x11vnc may not have started"
fi

# ---- 3. websockify + noVNC ----
pkill -f "websockify.*${NOVNC_PORT}" 2>/dev/null || true
sleep 0.5
nohup websockify --web /usr/share/novnc "${NOVNC_PORT}" "localhost:${VNC_PORT}" > /dev/null 2>&1 &
WS_PID=$!
disown $WS_PID
echo "$WS_PID" >> "$PID_FILE"
sleep 1
echo "[viz] noVNC started on :${NOVNC_PORT} (PID $WS_PID)"

# ---- 4. Chromium via agent-browser (persistent profile) ----
echo "[viz] Launching Chromium with persistent profile: ${BROWSER_PROFILE}"
mkdir -p "${BROWSER_PROFILE}"

# Use --profile for persistent login, --headed so it renders on Xvfb
nohup agent-browser \
    --profile "${BROWSER_PROFILE}" \
    --headed \
    open "${TARGET_URL}" \
    > /tmp/gemini-viz-browser.log 2>&1 &
BROWSER_PID=$!
disown $BROWSER_PID
echo "$BROWSER_PID" >> "$PID_FILE"
sleep 3
echo "[viz] Chromium opened ${TARGET_URL} (PID $BROWSER_PID)"

if [ "$LOGIN_MODE" = true ]; then
    echo "[viz] 🔐 LOGIN MODE: Please login via the noVNC link below."
    echo "[viz]    After login, your session will be saved to: ${BROWSER_PROFILE}"
fi

# ---- 5. Idle watchdog ----
pkill -f "idle-watchdog.py" 2>/dev/null || true
sleep 0.5
nohup python3 "${SCRIPT_DIR}/idle-watchdog.py" \
    --timeout "${IDLE_TIMEOUT}" \
    --novnc-port "${NOVNC_PORT}" \
    > /tmp/gemini-viz-watchdog.log 2>&1 &
WD_PID=$!
disown $WD_PID
echo "$WD_PID" >> "$PID_FILE"
echo "[viz] Idle watchdog started (PID $WD_PID, timeout ${IDLE_TIMEOUT}s)"

# ---- 6. Cloudflare Tunnel ----
# Don't kill A2A tunnels — only kill tunnels pointing to noVNC port
for pid in $(pgrep -f "cloudflared.*tunnel.*${NOVNC_PORT}" 2>/dev/null); do
    kill "$pid" 2>/dev/null || true
done
sleep 0.5

TUNNEL_LOG="/tmp/gemini-viz-tunnel.log"
nohup cloudflared tunnel --url "http://localhost:${NOVNC_PORT}" \
    > "$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!
disown $TUNNEL_PID
echo "$TUNNEL_PID" >> "$PID_FILE"

# Wait for tunnel URL (up to 20s)
TUNNEL_URL=""
for i in $(seq 1 40); do
    sleep 0.5
    TUNNEL_URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | head -1)
    if [ -n "$TUNNEL_URL" ]; then
        break
    fi
done

if [ -z "$TUNNEL_URL" ]; then
    echo "[viz] WARNING: Tunnel failed. Local access only." >&2
    tail -3 "$TUNNEL_LOG" >&2
    echo "[viz] ====================================="
    echo "[viz] 🖥️  Visualization ready (LOCAL ONLY)"
    echo "[viz] Local: http://localhost:${NOVNC_PORT}/vnc.html?autoconnect=true&resize=scale"
    echo "[viz] ====================================="
    exit 0
fi

VIZ_URL="${TUNNEL_URL}/vnc.html?autoconnect=true&resize=scale"
echo "$VIZ_URL" > "$URL_FILE"

echo "[viz] ====================================="
echo "[viz] 🖥️  Visualization ready!"
echo "[viz] URL: ${VIZ_URL}"
if [ "$LOGIN_MODE" = true ]; then
    echo "[viz] 🔐 Please login to Gemini in the browser above"
    echo "[viz]    Login will be saved for future sessions"
fi
echo "[viz] Idle timeout: ${IDLE_TIMEOUT}s"
echo "[viz] ====================================="
