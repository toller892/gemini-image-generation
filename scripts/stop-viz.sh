#!/bin/bash
#
# stop-viz.sh — Stop the visualization stack.
#
set +e

PID_FILE="/tmp/gemini-viz.pids"
URL_FILE="/tmp/gemini-viz.url"

# Close agent-browser gracefully first (saves profile state)
agent-browser close 2>/dev/null || true
sleep 1

if [ -f "$PID_FILE" ]; then
    while read -r pid; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            echo "[viz] Killed PID $pid"
        fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
fi

# Kill by name as fallback (careful not to kill A2A tunnels)
pkill -f "Xvfb :99" 2>/dev/null || true
pkill -f "x11vnc.*:99" 2>/dev/null || true
pkill -f "websockify.*6080" 2>/dev/null || true
pkill -f "idle-watchdog.py" 2>/dev/null || true
# Only kill cloudflared tunnels pointing to noVNC port, not A2A
for pid in $(pgrep -f "cloudflared.*tunnel.*6080" 2>/dev/null); do
    kill "$pid" 2>/dev/null || true
done

rm -f "$URL_FILE" /tmp/gemini-viz-tunnel.log /tmp/gemini-viz-watchdog.log /tmp/gemini-viz-browser.log

echo "[viz] All stopped and cleaned up."
