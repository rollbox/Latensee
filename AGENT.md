# Usage

## Interaction

- The overlay starts at the right edge of the screen (upper quarter area)
- Clicks pass through the overlay to the window beneath
- Hover over the overlay for 5 seconds to show window controls (drag/close) and IP history
- Move the mouse away or switch focus — window reverts to click-through overlay after 1 second

## Graph Indicators

- **Blue line** — normal latency (lower is better)
- **Yellow dots** — timeout points (request took >2s)
- **current/max** — current and maximum latency in the data window
- **"TIMEOUT"** — current or max ping timed out

## IP/Location Tracking

- Fetches IP and geo location from Cloudflare every 10 seconds
- Displays current location with country flag emoji (or a globe emoji `🌐` for generic/unknown codes) in the history panel
- When IP or location changes:
  - Current trace text flashes white briefly
  - History panel appears below the overlay showing last 20 changes with time-ago labels
  - History panel auto-hides after 10 seconds
- Hover to show the title bar also reveals the history panel (stays until hover ends)

## Technical Details

- Pings `https://cp.cloudflare.com/generate_204` every 2 seconds
- Fetches `https://cloudflare.com/cdn-cgi/trace` every 10 seconds for IP/location
- Each ping creates a fresh ephemeral URLSession (no connection reuse) to measure full DNS + TCP + TLS latency
- Request timeout is 2 seconds; overlapping requests are skipped
- Y-axis fixed at 2000ms for stable visual reference
- Up to 30 data points displayed, latest always at the right edge
- Transparent overlay stays on top of all windows and across all Spaces; mouse clicks pass through unless interactive mode is active
- Uses standard system fonts and lets macOS handle emoji font cascading dynamically, preventing CoreText crashes related to explicit "Apple Color Emoji" font instantiation
- Renders the flag emoji and text block in separate drawing calls as plain, unstyled attributed strings, preventing CoreText crashes during attribute/font cascade merging
- Maps non-country location codes (e.g. "XX", "AP", "EU", "T1") to a standard globe emoji "🌐" to avoid rendering invalid regional indicator sequences that can crash the system CoreText layout engine
