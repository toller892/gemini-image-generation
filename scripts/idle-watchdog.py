#!/usr/bin/env python3
"""
Idle watchdog for noVNC visualization stack.

Monitors websockify connections. After N seconds of no active WebSocket
connections, kills the entire viz stack (Xvfb, x11vnc, websockify,
cloudflared) by reading PIDs from /tmp/gemini-viz.pids.

Usage:
    python3 idle-watchdog.py [--timeout 600] [--novnc-port 6080]
"""

import argparse
import subprocess
import signal
import sys
import time
import os


def count_websockify_connections(port: int) -> int:
    """Count active WebSocket connections to websockify."""
    try:
        result = subprocess.run(
            ["ss", "-tn", f"sport = :{port}"],
            capture_output=True, text=True, timeout=5
        )
        # Subtract 1 for the header line, and 1 for the LISTEN line
        lines = [l for l in result.stdout.strip().split("\n") if "ESTAB" in l]
        return len(lines)
    except Exception:
        return 0


def kill_stack():
    """Kill all viz processes."""
    pid_file = "/tmp/gemini-viz.pids"
    if os.path.exists(pid_file):
        with open(pid_file) as f:
            for line in f:
                pid = line.strip()
                if pid:
                    try:
                        os.kill(int(pid), signal.SIGTERM)
                        print(f"[watchdog] Killed PID {pid}")
                    except (ProcessLookupError, ValueError):
                        pass
    # Also kill by name
    for pattern in ["Xvfb :99", "x11vnc", "websockify.*6080", "cloudflared.*tunnel"]:
        subprocess.run(["pkill", "-f", pattern], capture_output=True)
    
    # Clean up
    for f in [pid_file, "/tmp/gemini-viz.token", "/tmp/gemini-viz.url",
              "/tmp/gemini-viz-tunnel.log"]:
        try:
            os.remove(f)
        except FileNotFoundError:
            pass
    
    print("[watchdog] Stack terminated.", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", type=int, default=600, help="Idle timeout seconds")
    parser.add_argument("--novnc-port", type=int, default=6080, help="noVNC port to monitor")
    args = parser.parse_args()

    print(f"[watchdog] Monitoring port {args.novnc_port}, timeout {args.timeout}s", flush=True)

    last_active = time.monotonic()

    # Handle signals gracefully
    def handle_signal(sig, frame):
        print(f"[watchdog] Received signal {sig}, exiting.", flush=True)
        sys.exit(0)
    
    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    while True:
        time.sleep(15)  # Check every 15 seconds
        
        conns = count_websockify_connections(args.novnc_port)
        if conns > 0:
            last_active = time.monotonic()
        
        idle = time.monotonic() - last_active
        if idle >= args.timeout:
            print(f"[watchdog] No connections for {int(idle)}s — shutting down stack.", flush=True)
            kill_stack()
            sys.exit(0)


if __name__ == "__main__":
    main()
