#!/bin/bash
#
# generate-image.sh — Full pipeline: ensure viz stack → agent-browser workflow → output
#
# Usage:
#   generate-image.sh --prompt "描述" [--style "Cinematic"] [--output ./output.png]
#
# Outputs:
#   - Image file at specified path
#   - Viz URL to stdout (for user to watch)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults
PROMPT=""
STYLE=""
OUTPUT="./generated-image.png"
SESSION_NAME="gemini"

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --prompt) PROMPT="$2"; shift 2 ;;
        --style) STYLE="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --session) SESSION_NAME="$2"; shift 2 ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$PROMPT" ]; then
    echo "Error: --prompt is required" >&2
    exit 1
fi

# ---- Ensure viz stack is running ----
URL_FILE="/tmp/gemini-viz.url"
if [ ! -f "$URL_FILE" ] || [ ! -f "/tmp/gemini-viz.pids" ]; then
    echo "[gen] Starting visualization stack..."
    bash "${SCRIPT_DIR}/start-viz.sh"
fi

VIZ_URL=$(cat "$URL_FILE" 2>/dev/null || echo "")
if [ -n "$VIZ_URL" ]; then
    echo "[gen] 🖥️ Watch live: ${VIZ_URL}"
fi

# ---- Ensure DISPLAY is set ----
export DISPLAY="${DISPLAY:-:99}"
unset WAYLAND_DISPLAY 2>/dev/null || true

# ---- agent-browser workflow ----
AB="agent-browser --session-name ${SESSION_NAME}"

echo "[gen] Opening Gemini..."
$AB open "https://gemini.google.com"
sleep 3

echo "[gen] Looking for Create image button..."
$AB snapshot -i > /tmp/gemini-snapshot.txt 2>&1
# The actual element refs will vary; the SKILL.md instructs to parse snapshot output
# This script provides the framework; the agent interprets snapshots dynamically

echo "[gen] Snapshot saved to /tmp/gemini-snapshot.txt"
echo "[gen] Prompt: ${PROMPT}"
echo "[gen] Style: ${STYLE:-'(user will choose)'}"
echo "[gen] Output: ${OUTPUT}"

# Note: The actual click/fill/download sequence requires dynamic ref parsing
# which the agent does interactively. This script sets up the environment
# and provides the entry point. The agent follows SKILL.md steps from here.
echo "[gen] Environment ready. Agent should now follow SKILL.md workflow steps."
