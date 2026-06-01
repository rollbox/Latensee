# Latensee Agent Guide

Developer and agent instructions for building, running, and modifying Latensee.

## Project Structure & Entry Points

- **[main.swift](file:///Users/rollbox/Downloads/tmp/github/Latensee/main.swift)**: Contains the entire application code:
  - `AppDelegate`: Orchestrates timers, window management, and network tasks.
  - `OverlayWindow` & `OverlayView`: The always-on-top, click-through latency chart window.
  - `TraceHistoryView`: The dropdown containing location and IP trace changes.
- **[build.sh](file:///Users/rollbox/Downloads/tmp/github/Latensee/build.sh)**: Compiles the Swift code and packages it into `Latensee.app`.
- **[Info.plist](file:///Users/rollbox/Downloads/tmp/github/Latensee/Info.plist)**: Defines the app as an accessory agent (`LSUIElement = true`) to run without a Dock icon.

## Compilation and Execution

### Build
Compile the application by running:
```bash
./build.sh
```

### Run (with Logs)
To capture stdout/stderr directly (crucial for catching runtime crashes/assertions):
```bash
./Latensee.app/Contents/MacOS/Latensee
```

### Run (via Finder)
```bash
open Latensee.app
```

## Critical Developer Guidelines

### 1. Memory Management for Programmatic Windows
Since the windows are created programmatically without an `NSWindowController`, AppKit defaults `isReleasedWhenClosed` to `true`. This causes double-free or use-after-free `EXC_BAD_ACCESS` crashes when ARC cleans them up or when background timers attempt to access them post-closure.
- **Rule**: Always set `isReleasedWhenClosed = false` on both `OverlayWindow` and any programmatic `NSWindow` (such as `historyWindow`).

### 2. CoreText and Emoji Rendering Crash Prevention
Applying styling attributes (like `.font` or `.foregroundColor`) to attributed strings containing emoji characters or trying to render invalid regional indicators (e.g., from generic region codes) triggers a CoreText crash (`TAttributes::ApplyFont`) on Apple Silicon.
- **Rule**: Always validate country codes using Foundation's dynamic locale APIs (`Locale.Region.isoRegions` or `Locale.isoRegionCodes`).
- **Rule**: Map non-country codes (`XX`, `AP`, `EU`, `T1`) to a standard globe emoji (`🌐`).
- **Rule**: Draw emoji characters in a separate pass as a plain `NSAttributedString` with no styling attributes applied. Never append them directly to stylized text inside `NSMutableAttributedString`.

### 3. Networking
- Pings Cloudflare latency endpoint every 2 seconds.
- Queries Cloudflare trace endpoint every 10 seconds.
- Requests run asynchronously. Ensure URLSessions are terminated cleanly using `session.invalidateAndCancel()` inside completion handlers.
