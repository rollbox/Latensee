# TransparentOverlay

A minimal macOS overlay app that continuously pings Cloudflare and displays network latency as a real-time graph.

## Features

- Pings `https://cp.cloudflare.com/generate_204` every 2 seconds
- Displays latency as a live line chart (up to 60 data points)
- Fixed Y-axis at 2000ms for stable visual reference
- Timeout handling: skips overlapping requests, 2s timeout, golden yellow fill for timeout regions
- Shows current latency value and max latency in the graph
- Transparent overlay that stays on top of all windows
- Passes through all mouse/keyboard input in normal mode
- Hover for 1 second to enter interactive mode (drag, close)
- Interactive window auto-hides 1 second after mouse leaves or focus is lost
- Menu bar icon (◉) for quick control
- Adjustable opacity (10%–50%)
- Multiple color presets (Light Blue, Silver, Lavender, Rose, White)

## Build & Run

```bash
swiftc main.swift -o overlay
./overlay
```

## Usage

- The overlay starts at the right edge of the screen (upper quarter area)
- Hover over the overlay for 1 second to show window controls (drag/close)
- Move the mouse away or switch focus — window reverts to transparent overlay after 1 second
- Click the **◉** icon in the menu bar to access controls:
  - **Toggle Overlay** — show/hide the overlay
  - **Opacity** — choose transparency level
  - **Color** — choose overlay tint
  - **Quit** (⌘Q) — exit the app

## Graph Indicators

- **Blue line/fill** — normal latency (lower is better)
- **Golden yellow fill** — timeout regions (request took >2s)
- **"TIMEOUT" label** — current ping timed out
- **max: Xms** — highest latency in the current window

## Use Cases

- Monitor network connectivity and latency in real time
- Quick visual indicator for network issues or timeouts
- Lightweight always-on-top network health widget
