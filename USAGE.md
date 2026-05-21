# Usage

## Interaction

- The overlay starts at the right edge of the screen (upper quarter area)
- Hover over the overlay for 1 second to show window controls (drag/close)
- Move the mouse away or switch focus — window reverts to transparent overlay after 1 second
- Click the **◉** icon in the menu bar to access controls:
  - **Toggle Overlay** — show/hide the overlay
  - **Opacity** — choose transparency level (10%–50%)
  - **Color** — choose overlay tint (Light Blue, Silver, Lavender, Rose, White)
  - **Quit** (⌘Q) — exit the app

## Graph Indicators

- **Blue line** — normal latency (lower is better)
- **Yellow dots** — timeout points (request took >2s)
- **"TIMEOUT" label** — current ping timed out
- **max: Xms** — highest latency in the current data window

## Technical Details

- Pings `https://cp.cloudflare.com/generate_204` every 2 seconds
- Each ping creates a fresh ephemeral URLSession (no connection reuse) to measure full DNS + TCP + TLS latency
- Request timeout is 2 seconds; overlapping requests are skipped
- Y-axis fixed at 2000ms for stable visual reference
- Up to 60 data points displayed, latest always at the right edge
- Transparent overlay stays on top of all windows and across all Spaces
