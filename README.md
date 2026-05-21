# Latensee

A minimal macOS overlay that monitors network latency in real time by pinging Cloudflare.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)

## Build & Run

```bash
swiftc main.swift -o latensee
./latensee
```

## Overview

- Pings `https://cp.cloudflare.com/generate_204` every 2 seconds
- Displays a live latency graph (fixed 2000ms Y-axis, Grafana-style scrolling)
- Transparent always-on-top overlay with hover-to-interact
- Yellow dots indicate timeout (>2s)
- Menu bar control (◉) for opacity, color, and visibility

See [USAGE.md](USAGE.md) for detailed usage and configuration.
