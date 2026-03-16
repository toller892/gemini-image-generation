---
name: gemini-image-generation
description: Use when user asks to generate images using Gemini's image generation feature (nano banana model). Provides live browser visualization via noVNC + Cloudflare Tunnel. User logs in manually once (persisted), then agent automates generation. Designed for cloud OpenClaw instances.
---

# Gemini Image Generation (with Live Visualization)

## Overview

Automate Gemini's web-based image generation (nano banana model) with **real-time browser visualization**. A headless Chromium runs on a virtual display (Xvfb), accessible via noVNC through a temporary Cloudflare Tunnel public URL.

- **First time:** User logs in to Gemini manually via noVNC link (login persisted via Chromium profile)
- **After login:** Agent automates the full workflow (open → prompt → style → generate → download)
- **Auto-shutdown:** 10 minutes of no noVNC connections → stack auto-terminates
- **Cloud-native:** Designed for headless cloud servers (Zeabur, VPS, etc.)

## Architecture

```
User's Browser ──HTTPS──▶ Cloudflare Quick Tunnel (random temporary URL)
                              │
                    websockify + noVNC (:6080)
                              │
                    x11vnc → Xvfb (:99) virtual display
                              ▲
                    Chromium (persistent profile at ~/.agent-browser/profiles/gemini)
                              ▲
                    agent-browser CLI (automates Gemini workflow)
```

## Installation

```bash
# Install dependencies (run as root or with sudo)
bash <skill_dir>/scripts/install-deps.sh

# Install Chromium for agent-browser
agent-browser install
```

## Workflow

### First-Time Setup (User Login)

Only needed once. Login is persisted in Chromium profile at `~/.agent-browser/profiles/gemini`.

```bash
bash <skill_dir>/scripts/start-viz.sh --login
```

Send the output URL to the user:
```
🔐 Please login to Gemini:
https://xxxxx.trycloudflare.com/vnc.html?autoconnect=true&resize=scale

Your login will be saved — you won't need to do this again.
```

After user confirms login is done:
```bash
bash <skill_dir>/scripts/stop-viz.sh
```

### Image Generation (Automated)

#### Step 1: Start viz stack
```bash
bash <skill_dir>/scripts/start-viz.sh
```
Send the noVNC URL to the user so they can watch live.

#### Step 2: Automate with agent-browser

Set environment:
```bash
export DISPLAY=:99
unset WAYLAND_DISPLAY HTTP_PROXY HTTPS_PROXY ALL_PROXY 2>/dev/null
AB="agent-browser --profile ~/.agent-browser/profiles/gemini --headed"
```

**Open Gemini (already logged in):**
```bash
$AB open "https://gemini.google.com"
```

**Click "Create image":**
```bash
$AB snapshot -i
$AB click @eN  # Create image button
$AB wait 2000
```

**Enter prompt:**
```bash
$AB snapshot -i
$AB fill @eN "image description"
```

**Select style (CRITICAL: must click UI element, NOT in prompt text):**
```bash
$AB snapshot -i -C
# Present styles to user if not specified, then click
$AB click @eN  # chosen style
$AB wait 2000
```

Common styles: Cinematic, Monochrome, Oil painting, Sketch, Technicolor, Color block

**Send and wait:**
```bash
$AB snapshot -i
$AB click @eN  # Send button
$AB wait 30000
$AB snapshot -i  # Check if still generating
```

**Download:**
```bash
$AB snapshot -i
$AB download @eN ./output.png
```

#### Step 3: Cleanup
```bash
bash <skill_dir>/scripts/stop-viz.sh
```
Or let idle watchdog auto-shutdown after 10 minutes.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/install-deps.sh` | Install all dependencies (apt + npm + cloudflared) |
| `scripts/start-viz.sh` | Start full stack (Xvfb + VNC + noVNC + Chromium + tunnel) |
| `scripts/start-viz.sh --login` | Login mode — user logs in via noVNC |
| `scripts/stop-viz.sh` | Stop all processes gracefully |
| `scripts/idle-watchdog.py` | Auto-shutdown after N seconds of no connections |

## Environment Variables

| Var | Default | Description |
|---|---|---|
| `DISPLAY_NUM` | 99 | Virtual display number |
| `VNC_PORT` | 5900 | x11vnc port |
| `NOVNC_PORT` | 6080 | noVNC/websockify port |
| `RESOLUTION` | 1280x720x24 | Virtual display resolution |
| `IDLE_TIMEOUT` | 600 | Auto-shutdown timeout (seconds) |
| `BROWSER_PROFILE` | `~/.agent-browser/profiles/gemini` | Chromium profile path |

## Login Persistence

Login state is stored in a full Chromium profile at `~/.agent-browser/profiles/gemini`:
- Cookies (Google login session)
- localStorage / sessionStorage
- Browser cache

As long as this directory is intact, subsequent launches skip login.

To force re-login: `rm -rf ~/.agent-browser/profiles/gemini`

## Troubleshooting

**Browser not visible on noVNC:** Ensure `DISPLAY=:99` and `unset WAYLAND_DISPLAY`.

**Login expired:** Run `start-viz.sh --login` again.

**Tunnel failed:** Check `/tmp/gemini-viz-tunnel.log`. May be temporary Cloudflare outage. Retry.

**Style not clicking:** Use `snapshot -i -C`. Styles only appear after clicking "Create image". Always `wait 2000` after clicking a style.

**Dependencies missing:** Run `scripts/install-deps.sh` (may need root/sudo).

## Security

- Tunnel URL is random and temporary (Cloudflare Quick Tunnel)
- 10-minute idle auto-shutdown limits exposure
- No persistent public endpoint
- Browser profile stored locally — login never leaves the server
