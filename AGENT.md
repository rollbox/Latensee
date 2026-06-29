# Latensee Agent Guide

Developer and agent instructions for building, running, and modifying Latensee.

## Project Structure & Entry Points

- **[main.swift](main.swift)**: Contains the entire application code:
  - `AppDelegate`: Orchestrates timers, window management, and network tasks.
  - `OverlayWindow` & `OverlayView`: The always-on-top, click-through latency chart window.
  - `TraceHistoryView`: The dropdown containing location and IP trace changes.
- **[build.sh](build.sh)**: Compiles the Swift code and packages it into `Latensee.app`.
- **[Info.plist](Info.plist)**: Defines the app as an accessory agent (`LSUIElement = true`) to run without a Dock icon.

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

## Interaction & Control

Since the app runs as a pure background accessory (`LSUIElement = true` and no menu bar icon):
- **Click Pass-through**: By default, clicks pass through the overlay so it doesn't obstruct normal workflow.
- **Interactive Mode**: Hover the mouse cursor over the overlay for **5 seconds**. The window will become active, showing a title bar and window frame, and turning the background semi-transparent.
- **Exit/Quit**: While in interactive mode, click the close button on the window's title bar, or press `Cmd+Q` while the window is active.

## Critical Developer Guidelines

### 1. Memory Management for Programmatic Windows
Since the windows are created programmatically without an `NSWindowController`, AppKit defaults `isReleasedWhenClosed` to `true`. This causes double-free or use-after-free `EXC_BAD_ACCESS` crashes when ARC cleans them up or when background timers attempt to access them post-closure.
- **Rule**: Always set `isReleasedWhenClosed = false` on both `OverlayWindow` and any programmatic `NSWindow` (such as `historyWindow`).

### 2. CoreText and Emoji Rendering Crash Prevention
Rendering emoji characters (such as flags or globes) under CoreText in custom view draw passes on macOS can trigger internal system-level crashes (`TAttributes::ApplyFont`) due to font cascading dictionary errors.
- **Rule**: To prevent this crash entirely, do not draw emoji characters (like flag or globe emojis) in attributed text rendered within custom draw routines (`draw(_:)`). Keep all rendering strings as plain alphanumeric text (e.g., displaying the text location code `"US"` instead of the flag emoji `"🇺🇸"`).
- **Rule**: Keep country code validation using Foundation's dynamic locale APIs (`Locale.Region.isoRegions` or `Locale.isoRegionCodes`) to dynamically ensure only valid location codes are accepted.
- **Rule**: Avoid using dynamic system fonts (such as `NSFont.monospacedSystemFont` or `NSFont.systemFont`) inside custom draw passes (`draw(_:)`). Instead, use explicit static fonts like `"Menlo"` or `"Helvetica-Bold"` to prevent CoreText attribute rendering exceptions.
- **Rule**: When drawing custom views, always convert colors to the `.deviceRGB` color space (e.g., using `.usingColorSpace(.deviceRGB)`) before drawing, especially if applying alpha or text attributes.

### 3. Networking
- Pings Cloudflare latency endpoint every 2 seconds.
- Queries Cloudflare trace endpoint every 10 seconds.
- Requests run asynchronously. Ensure URLSessions are terminated cleanly using `session.invalidateAndCancel()` inside completion handlers.
