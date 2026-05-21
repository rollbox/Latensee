import Cocoa

class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: OverlayWindow!
    var statusItem: NSStatusItem!
    var overlayView: OverlayView!
    var isVisible = true
    var pingTimer: Timer?
    var isPinging = false
    var hoverTimer: Timer?
    var exitTimer: Timer?
    var isInteractive = false
    var savedFrame: NSRect = .zero
    let pingURL = URL(string: "https://cp.cloudflare.com/generate_204")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main!
        let visibleFrame = screen.visibleFrame
        let width: CGFloat = 320
        let height: CGFloat = 120
        let frame = NSRect(
            x: visibleFrame.maxX - width,
            y: visibleFrame.minY + visibleFrame.height * 3 / 4 - height / 2,
            width: width,
            height: height
        )

        window = OverlayWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.hasShadow = false

        overlayView = OverlayView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        overlayView.wantsLayer = true
        overlayView.layer?.isOpaque = false
        overlayView.appDelegate = self
        window.contentView = overlayView
        window.orderFrontRegardless()
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)))

        setupMouseTracking()
        setupStatusBar()
        startPinging()
    }

    func setupMouseTracking() {
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
    }

    func onMouseEntered() {
        exitTimer?.invalidate()
        exitTimer = nil
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.enterInteractiveMode()
        }
    }

    func onMouseExited() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        if isInteractive {
            scheduleExit()
        }
    }

    func enterInteractiveMode() {
        isInteractive = true
        exitTimer?.invalidate()
        exitTimer = nil

        savedFrame = window.frame
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.black.withAlphaComponent(0.5)
        window.hasShadow = true
        overlayView.needsDisplay = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )

        startMousePolling()
    }

    var mousePollingTimer: Timer?

    func startMousePolling() {
        mousePollingTimer?.invalidate()
        mousePollingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self, self.isInteractive else { return }
            let mouseLocation = NSEvent.mouseLocation
            let windowFrame = self.window.frame
            if !windowFrame.contains(mouseLocation) {
                self.scheduleExit()
                self.mousePollingTimer?.invalidate()
                self.mousePollingTimer = nil
            }
        }
    }

    @objc func windowDidResignKey(_ notification: Notification) {
        scheduleExit()
    }

    @objc func windowDidMove(_ notification: Notification) {
        scheduleExit()
    }

    func scheduleExit() {
        exitTimer?.invalidate()
        exitTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.exitInteractiveMode()
        }
    }

    func exitInteractiveMode() {
        guard isInteractive else { return }
        isInteractive = false
        exitTimer?.invalidate()
        exitTimer = nil
        mousePollingTimer?.invalidate()
        mousePollingTimer = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: window)

        let currentFrame = window.frame
        window.styleMask = .borderless
        window.setFrame(NSRect(x: currentFrame.origin.x, y: currentFrame.origin.y, width: savedFrame.width, height: savedFrame.height), display: true)
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        overlayView.needsDisplay = true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func startPinging() {
        pingOnce()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pingOnce()
        }
    }

    func pingOnce() {
        guard !isPinging else { return }
        isPinging = true
        let start = CFAbsoluteTimeGetCurrent()
        var request = URLRequest(url: pingURL)
        request.timeoutInterval = 2.0
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)
        session.dataTask(with: request) { [weak self] _, response, error in
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isPinging = false
                if error != nil {
                    self.overlayView.addLatency(elapsed, timeout: true)
                } else {
                    self.overlayView.addLatency(elapsed, timeout: false)
                }
            }
            session.invalidateAndCancel()
        }.resume()
    }

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "◉"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Overlay", action: #selector(toggleOverlay), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())

        let opacityItem = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        let opacitySubmenu = NSMenu()
        for value in [10, 20, 30, 40, 50] {
            let item = NSMenuItem(title: "\(value)%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            item.tag = value
            if value == 20 { item.state = .on }
            opacitySubmenu.addItem(item)
        }
        opacityItem.submenu = opacitySubmenu
        menu.addItem(opacityItem)

        let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        let colorSubmenu = NSMenu()
        for (name, tag) in [("Light Blue", 0), ("Silver", 1), ("Lavender", 2), ("Rose", 3), ("White", 4)] {
            let item = NSMenuItem(title: name, action: #selector(setColor(_:)), keyEquivalent: "")
            item.tag = tag
            if tag == 0 { item.state = .on }
            colorSubmenu.addItem(item)
        }
        colorItem.submenu = colorSubmenu
        menu.addItem(colorItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc func toggleOverlay() {
        isVisible.toggle()
        if isVisible {
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
    }

    @objc func setOpacity(_ sender: NSMenuItem) {
        let opacity = CGFloat(sender.tag) / 100.0
        overlayView.overlayOpacity = opacity
        overlayView.needsDisplay = true

        if let menu = sender.menu {
            for item in menu.items { item.state = .off }
        }
        sender.state = .on
    }

    @objc func setColor(_ sender: NSMenuItem) {
        let colors: [NSColor] = [
            NSColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 1.0),
            NSColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1.0),
            NSColor(red: 0.75, green: 0.7, blue: 0.85, alpha: 1.0),
            NSColor(red: 0.85, green: 0.7, blue: 0.75, alpha: 1.0),
            NSColor.white,
        ]
        overlayView.overlayColor = colors[sender.tag]
        overlayView.needsDisplay = true

        if let menu = sender.menu {
            for item in menu.items { item.state = .off }
        }
        sender.state = .on
    }
}

class OverlayView: NSView {
    var overlayColor: NSColor = NSColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 1.0)
    var overlayOpacity: CGFloat = 0.35
    var latencyData: [(ms: Double, timeout: Bool)] = []
    let maxDataPoints = 60
    weak var appDelegate: AppDelegate?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        appDelegate?.onMouseEntered()
    }

    override func mouseExited(with event: NSEvent) {
        appDelegate?.onMouseExited()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        guard latencyData.count >= 2 else { return }

        let margin: CGFloat = 10
        let textReserve: CGFloat = 18
        let graphRect = bounds.insetBy(dx: margin, dy: margin)
        let curveMaxY = graphRect.maxY - textReserve

        NSColor.black.withAlphaComponent(0.15).setFill()
        let bgPath = NSBezierPath(roundedRect: graphRect, xRadius: 6, yRadius: 6)
        bgPath.fill()

        let maxLatency: Double = 2000
        let stepX = graphRect.width / CGFloat(maxDataPoints - 1)
        let curveHeight = curveMaxY - graphRect.minY

        let timeoutColor = NSColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1.0)

        let fillPath = NSBezierPath()
        let timeoutFillPath = NSBezierPath()
        let linePath = NSBezierPath()
        linePath.lineWidth = 1.5

        var inTimeoutRegion = false

        for (i, entry) in latencyData.enumerated() {
            let x = graphRect.minX + stepX * CGFloat(i)
            let y = graphRect.minY + curveHeight * CGFloat(min(entry.ms / maxLatency, 1.0))
            let point = NSPoint(x: x, y: min(y, curveMaxY))

            if i == 0 {
                linePath.move(to: point)
                fillPath.move(to: NSPoint(x: x, y: graphRect.minY))
                fillPath.line(to: point)
            } else {
                linePath.line(to: point)
                fillPath.line(to: point)
            }

            if entry.timeout {
                if !inTimeoutRegion {
                    timeoutFillPath.move(to: NSPoint(x: x, y: graphRect.minY))
                }
                timeoutFillPath.line(to: point)
                inTimeoutRegion = true
            } else {
                if inTimeoutRegion {
                    timeoutFillPath.line(to: point)
                    timeoutFillPath.line(to: NSPoint(x: x, y: graphRect.minY))
                    timeoutFillPath.close()
                }
                inTimeoutRegion = false
            }
        }
        if inTimeoutRegion {
            let lastX = graphRect.minX + stepX * CGFloat(latencyData.count - 1)
            timeoutFillPath.line(to: NSPoint(x: lastX, y: graphRect.minY))
            timeoutFillPath.close()
        }

        let lastX = graphRect.minX + stepX * CGFloat(latencyData.count - 1)
        fillPath.line(to: NSPoint(x: lastX, y: graphRect.minY))
        fillPath.close()
        overlayColor.withAlphaComponent(0.08).setFill()
        fillPath.fill()

        timeoutColor.withAlphaComponent(0.2).setFill()
        timeoutFillPath.fill()

        overlayColor.withAlphaComponent(overlayOpacity).setStroke()
        linePath.stroke()


        if let last = latencyData.last {
            let text: String
            let labelColor: NSColor
            if last.timeout {
                text = "TIMEOUT"
                labelColor = timeoutColor.withAlphaComponent(overlayOpacity)
            } else {
                text = String(format: "%.0f ms", last.ms)
                labelColor = overlayColor.withAlphaComponent(overlayOpacity * 0.8)
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: labelColor,
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let textSize = str.size()
            let textPoint = NSPoint(x: graphRect.maxX - textSize.width - 4, y: graphRect.maxY - textSize.height - 4)
            str.draw(at: textPoint)
        }

        let actualMax = latencyData.filter { !$0.timeout }.map { $0.ms }.max() ?? 0
        let maxText = String(format: "max: %.0f ms", actualMax)
        let maxAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: overlayColor.withAlphaComponent(overlayOpacity * 0.5),
            .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        ]
        let maxStr = NSAttributedString(string: maxText, attributes: maxAttrs)
        maxStr.draw(at: NSPoint(x: graphRect.minX + 4, y: graphRect.maxY - maxStr.size().height - 4))
    }

    func addLatency(_ ms: Double, timeout: Bool) {
        latencyData.append((ms: ms, timeout: timeout))
        if latencyData.count > maxDataPoints {
            latencyData.removeFirst()
        }
        needsDisplay = true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
