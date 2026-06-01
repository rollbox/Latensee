# Latensee

[![CI](https://github.com/rollbox/Latensee/actions/workflows/ci.yml/badge.svg)](https://github.com/rollbox/Latensee/actions/workflows/ci.yml)

A minimal macOS overlay that monitors network latency in real time by pinging Cloudflare.

## Build & Run

```bash
./build.sh
open Latensee.app
```

## Overview

- Pings `https://cp.cloudflare.com/generate_204` every 2 seconds
- Fetches IP and location from `https://cloudflare.com/cdn-cgi/trace` every 10 seconds
- Displays a live latency graph (fixed 2000ms Y-axis, Grafana-style scrolling)
- Shows current/max latency, IP address and geo location with flag emoji
- Tracks last 20 IP/location changes with timestamps
- Transparent always-on-top overlay with click pass-through; hover 5s to interact
- Yellow dots indicate timeout (>2s)

See [AGENT.md](AGENT.md) for detailed usage and configuration.
