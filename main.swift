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
    let traceURL = URL(string: "https://cloudflare.com/cdn-cgi/trace")!
    var traceTimer: Timer?
    var traceHistory: [(info: String, time: Date)] = []
    let maxTraceHistory = 20
    var historyWindow: NSWindow?
    var historyView: TraceHistoryView?
    var historyHideTimer: Timer?

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
        startTrace()
    }

    func locToFlag(_ code: String) -> String {
        guard code.count == 2 else { return "" }
        return code.uppercased().unicodeScalars.compactMap {
            Unicode.Scalar(127397 + $0.value).map(String.init)
        }.joined()
    }

    func startTrace() {
        fetchTrace()
        traceTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.fetchTrace()
        }
    }

    func fetchTrace() {
        var request = URLRequest(url: traceURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let session = URLSession(configuration: config)
        session.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, error == nil,
                  let body = String(data: data, encoding: .utf8) else { return }
            var ip = ""
            var loc = ""
            for line in body.split(separator: "\n") {
                if line.hasPrefix("ip=") {
                    ip = String(line.dropFirst(3))
                } else if line.hasPrefix("loc=") {
                    loc = String(line.dropFirst(4))
                }
            }
            let flag = self?.locToFlag(loc) ?? ""
            let info = "\(loc) | \(ip)"
            let infoWithFlag = "\(flag) \(loc) | \(ip)"
            DispatchQueue.main.async {
                guard let self = self else { return }
                let changed = !self.overlayView.traceInfo.isEmpty && self.overlayView.traceInfo != info
                self.overlayView.updateTraceInfo(info)
                if self.traceHistory.isEmpty || self.traceHistory.last?.info != infoWithFlag {
                    self.traceHistory.append((info: infoWithFlag, time: Date()))
                    if self.traceHistory.count > self.maxTraceHistory {
                        self.traceHistory.removeFirst()
                    }
                }
                if changed {
                    self.showHistory()
                }
            }
            session.invalidateAndCancel()
        }.resume()
    }

    func showHistory() {
        historyHideTimer?.invalidate()

        guard traceHistory.count > 1 else { return }

        let lineHeight: CGFloat = 16
        let padding: CGFloat = 10
        let historyHeight = CGFloat(traceHistory.count - 1) * lineHeight + padding * 2
        let mainFrame = window.frame
        let historyFrame = NSRect(
            x: mainFrame.origin.x,
            y: mainFrame.origin.y - historyHeight - 4,
            width: mainFrame.width,
            height: historyHeight
        )

        if historyWindow == nil {
            historyWindow = NSWindow(
                contentRect: historyFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            historyWindow!.isOpaque = false
            historyWindow!.backgroundColor = .clear
            historyWindow!.ignoresMouseEvents = true
            historyWindow!.level = window.level
            historyWindow!.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            historyWindow!.hasShadow = false

            historyView = TraceHistoryView(frame: NSRect(x: 0, y: 0, width: historyFrame.width, height: historyFrame.height))
            historyView!.wantsLayer = true
            historyView!.layer?.isOpaque = false
            historyWindow!.contentView = historyView
        }

        historyWindow!.setFrame(historyFrame, display: true)
        historyView!.frame = NSRect(x: 0, y: 0, width: historyFrame.width, height: historyFrame.height)
        historyView!.history = traceHistory
        historyView!.overlayColor = overlayView.overlayColor
        historyView!.overlayOpacity = overlayView.overlayOpacity
        historyView!.isInteractive = isInteractive
        historyView!.needsDisplay = true
        historyWindow!.orderFrontRegardless()

        if !isInteractive {
            historyHideTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                self?.historyWindow?.orderOut(nil)
            }
        }
    }

    func syncHistoryHighlight(_ highlighted: Bool) {
        guard let hv = historyView else { return }
        if hv.isHighlighted != highlighted {
            hv.isHighlighted = highlighted
            hv.needsDisplay = true
        }
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
        overlayView.isInteractive = true
        overlayView.needsDisplay = true

        if traceHistory.count > 1 {
            showHistory()
        }

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
        historyHideTimer?.invalidate()
        historyWindow?.orderOut(nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: window)

        let currentFrame = window.frame
        window.styleMask = .borderless
        window.setFrame(NSRect(x: currentFrame.origin.x, y: currentFrame.origin.y, width: savedFrame.width, height: savedFrame.height), display: true)
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        overlayView.isInteractive = false
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
    var traceInfo: String = ""
    var traceHighlight: CGFloat = 0
    var highlightTimer: Timer?
    var isInteractive = false
    var isHighlighted = false

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

        isHighlighted = isInteractive || (latencyData.last?.timeout ?? false) || traceHighlight > 0
        appDelegate?.syncHistoryHighlight(isHighlighted)

        let margin: CGFloat = 10
        let textReserve: CGFloat = 24
        let bottomReserve: CGFloat = 16
        let graphRect = bounds.insetBy(dx: margin, dy: margin)
        let curveMaxY = graphRect.maxY - textReserve
        let curveMinY = graphRect.minY + bottomReserve

        NSColor.black.withAlphaComponent(isInteractive ? 0.5 : 0.075).setFill()
        let bgPath = NSBezierPath(roundedRect: graphRect, xRadius: 6, yRadius: 6)
        bgPath.fill()

        let maxLatency: Double = 2000
        let stepX = graphRect.width / CGFloat(maxDataPoints - 1)
        let curveHeight = curveMaxY - curveMinY

        let timeoutColor = NSColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1.0)

        let linePath = NSBezierPath()
        linePath.lineWidth = 1.5

        var timeoutPoints: [NSPoint] = []

        for (i, entry) in latencyData.enumerated() {
            let offset = maxDataPoints - latencyData.count
            let x = graphRect.minX + stepX * CGFloat(i + offset)
            let y = curveMinY + curveHeight * CGFloat(min(entry.ms / maxLatency, 1.0))
            let point = NSPoint(x: x, y: min(y, curveMaxY))

            if i == 0 {
                linePath.move(to: point)
            } else {
                linePath.line(to: point)
            }

            if entry.timeout {
                timeoutPoints.append(NSPoint(x: point.x, y: curveMaxY))
            }
        }

        let lineColor: NSColor = isHighlighted ? NSColor.white : overlayColor.withAlphaComponent(overlayOpacity)
        lineColor.setStroke()
        linePath.stroke()

        // timeout dot markers
        timeoutColor.withAlphaComponent(0.8).setFill()
        for pt in timeoutPoints {
            let marker = NSBezierPath(ovalIn: NSRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6))
            marker.fill()
        }


        let actualMax = latencyData.map { $0.ms }.max() ?? 0
        if let last = latencyData.last {
            let text: String
            let labelColor: NSColor
            let currentText: String
            if last.timeout {
                currentText = "TIMEOUT"
                labelColor = isHighlighted ? NSColor.white : timeoutColor.withAlphaComponent(0.8)
            } else {
                currentText = String(format: "%.0f", last.ms)
                labelColor = isHighlighted ? NSColor.white : overlayColor.withAlphaComponent(overlayOpacity * 0.8)
            }
            let maxText: String
            if actualMax >= 2000 {
                maxText = "TIMEOUT"
            } else {
                maxText = String(format: "%.0f", actualMax)
            }
            text = "\(currentText)/\(maxText)"
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: labelColor,
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let textSize = str.size()
            let textPoint = NSPoint(x: graphRect.maxX - textSize.width - 4, y: graphRect.maxY - textSize.height - 4)
            str.draw(at: textPoint)
        }

        if !traceInfo.isEmpty {
            let traceColor: NSColor
            if isHighlighted {
                traceColor = NSColor.white
            } else {
                let baseAlpha = overlayOpacity * 0.5
                let highlightAlpha = baseAlpha + (1.0 - baseAlpha) * traceHighlight
                traceColor = NSColor.white.withAlphaComponent(highlightAlpha)
            }
            let traceAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: traceColor,
                .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
            ]
            let traceStr = NSAttributedString(string: traceInfo, attributes: traceAttrs)
            let traceSize = traceStr.size()
            traceStr.draw(at: NSPoint(x: graphRect.maxX - traceSize.width - 4, y: graphRect.minY + 2))
        }
    }

    func addLatency(_ ms: Double, timeout: Bool) {
        latencyData.append((ms: ms, timeout: timeout))
        if latencyData.count > maxDataPoints {
            latencyData.removeFirst()
        }
        needsDisplay = true
    }

    func updateTraceInfo(_ info: String) {
        if !traceInfo.isEmpty && traceInfo != info {
            startHighlight()
        }
        traceInfo = info
        needsDisplay = true
    }

    func startHighlight() {
        traceHighlight = 1.0
        highlightTimer?.invalidate()
        highlightTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.traceHighlight -= 1.0 / (2.0 * 30.0)
            if self.traceHighlight <= 0 {
                self.traceHighlight = 0
                timer.invalidate()
            }
            self.needsDisplay = true
        }
    }
}

class TraceHistoryView: NSView {
    var history: [(info: String, time: Date)] = []
    var overlayColor: NSColor = .white
    var overlayOpacity: CGFloat = 0.35
    var isInteractive = false
    var isHighlighted = false

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        guard history.count > 1 else { return }

        let padding: CGFloat = 10
        let lineHeight: CGFloat = 16
        let contentRect = bounds.insetBy(dx: padding, dy: padding / 2)

        let bgAlpha: CGFloat = isInteractive ? 0.5 : 0.075
        NSColor.black.withAlphaComponent(bgAlpha).setFill()
        let bgPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 10, dy: 0), xRadius: 6, yRadius: 6)
        bgPath.fill()

        let now = Date()
        let pastEntries = history.dropLast().reversed()
        for (i, entry) in pastEntries.enumerated() {
            let y = contentRect.maxY - CGFloat(i + 1) * lineHeight
            guard y >= contentRect.minY else { break }

            let ago = formatAgo(now.timeIntervalSince(entry.time))
            let text = "\(ago)  \(entry.info)"
            let textColor: NSColor = isHighlighted ? NSColor.white : overlayColor.withAlphaComponent(overlayOpacity * 0.6)
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: textColor,
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let strSize = str.size()
            str.draw(at: NSPoint(x: contentRect.maxX - strSize.width, y: y))
        }
    }

    func formatAgo(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%3.0fs", seconds)
        } else if seconds < 3600 {
            return String(format: "%3.0fm", seconds / 60)
        } else {
            return String(format: "%3.0fh", seconds / 3600)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
