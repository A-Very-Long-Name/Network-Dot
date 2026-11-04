import AppKit
import Network
import ServiceManagement
import QuartzCore

struct Target {
    let url: String
    let token: String
    var code: Int = 200
}
let defaults = [Target(url: "https://www.apple.com/library/test/success.html", token: "<TITLE>Success</TITLE>"), Target(url: "https://www.gstatic.com/generate_204", token: "", code: 204), Target(url: "https://www.cloudflare.com/cdn-cgi/trace", token: "ip=")]
final class IndicatorWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class Dot: NSView {
    private let border = CAShapeLayer()
    private let center = CAShapeLayer()
    var color = NSColor.systemGray { didSet { updateDotLayers() } }
    var rendersColor = true {
        didSet { border.isHidden = !rendersColor; center.isHidden = !rendersColor }
    }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(border)
        layer?.addSublayer(center)
        updateDotLayers()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); updateDotLayers() }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); updateDotLayers() }
    private func updateDotLayers() {
        let scale = max(window?.backingScaleFactor ?? 1, 1)
        let inner = bounds.insetBy(dx: 4, dy: 4)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        border.frame = bounds; center.frame = bounds
        border.contentsScale = scale; center.contentsScale = scale
        border.path = CGPath(ellipseIn: inner.insetBy(dx: -1 / scale, dy: -1 / scale), transform: nil)
        border.fillColor = NSColor.black.cgColor
        center.path = CGPath(ellipseIn: inner, transform: nil)
        center.fillColor = color.cgColor
        CATransaction.commit()
    }
}
final class App: NSObject, NSApplicationDelegate {
    let monitor = NWPathMonitor()
    var panels: [NSWindow] = []
    var restoreTicket = 0
    var rawOverlays: [UnsafeMutableRawPointer?] = []
    var dots: [Dot] = []
    var timer: Timer?
    var health = ConnectivityHealth()
    var nextProbe: TimeInterval = 0
    var selection = ProbeSelection()
    var round: ProbeRound?
    var fallbackWork: DispatchWorkItem?
    var launchedRequestCount = 0
    var launchCounts: [String: Int] = [:]
    var reportDuration: Double? {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--probe-report=") }),
              let seconds = Double(arg.dropFirst("--probe-report=".count)), (2...120).contains(seconds) else { return nil }
        return seconds
    }
    var language: String { UserDefaults.standard.string(forKey: "language") ?? "auto" }
    var isChinese: Bool { language == "zh" || (language == "auto" && (Locale.preferredLanguages.first ?? "en").hasPrefix("zh")) }
    func l(_ zh: String, _ en: String) -> String { isChinese ? zh : en }
    var generation = 0
    var tasks: [UUID: URLSessionDataTask] = [:]
    var details: [String: String] = [:]
    var state = ""
    var session: URLSession!
    var targets: [Target] {
        if reportDuration != nil, let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--probe-urls=") }) {
            let urls = arg.dropFirst("--probe-urls=".count).split(separator: ",").map(String.init)
            if !urls.isEmpty && urls.count <= 5 && urls.allSatisfy({ URL(string: $0)?.scheme == "https" && URL(string: $0)?.host != nil }) {
                return urls.map { url in defaults.first(where: { $0.url == url }) ?? Target(url: url, token: "") }
            }
        }
        let urls = UserDefaults.standard.stringArray(forKey: "targets") ?? []
        return urls.isEmpty ? defaults : urls.map { Target(url: $0, token: "") }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if reportDuration == nil && NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.NetworkDot").count > 1 { NSApp.terminate(nil); return }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.5
        config.timeoutIntervalForResource = 1.5
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpCookieStorage = nil
        config.urlCache = nil
        session = URLSession(configuration: config)
        NotificationCenter.default.addObserver(self, selector: #selector(screens), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        workspaceNotifications.addObserver(self, selector: #selector(restoreOverlay), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        workspaceNotifications.addObserver(self, selector: #selector(restoreOverlay), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        if reportDuration == nil { screens() }
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                self.reset()
                self.health.reset(connected: path.status == .satisfied, now: ProcessInfo.processInfo.systemUptime)
                self.tick()
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkDot.path"))
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        update()
        if let duration = reportDuration {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self else { return }
                let report: [String: Any] = ["requests": self.launchedRequestCount, "byTarget": self.launchCounts,
                    "online": self.health.state(now: ProcessInfo.processInfo.systemUptime) == .online,
                    "preferredIndex": self.selection.preferred, "duration": duration]
                if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]),
                   let text = String(data: data, encoding: .utf8) { print(text) }
                NSApp.terminate(nil)
            }
        } else if !UserDefaults.standard.bool(forKey: "welcomeShown") {
            DispatchQueue.main.async { [weak self] in self?.welcome() }
        }
    }
    func reset() {
        generation += 1
        fallbackWork?.cancel(); fallbackWork = nil
        round = nil
        selection.reset()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        health.reset(connected: health.connected, now: ProcessInfo.processInfo.systemUptime)
        nextProbe = 0
        details.removeAll()
    }
    @objc func wake() { reset(); tick(); restoreOverlay() }
    @objc func restoreOverlay() {
        guard reportDuration == nil else { return }
        restoreTicket += 1
        let ticket = restoreTicket
        for delay in [0.0, 0.1, 0.35, 0.8] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.restoreTicket == ticket else { return }
                // Raw visual surfaces remain intact across Space transitions.
                self.panels.forEach { panel in
                    panel.orderFrontRegardless()
                    panel.displayIfNeeded()
                }
            }
        }
    }
    @objc func screens() {
        let oldPanels = panels
        let oldRawOverlays = rawOverlays
        panels = []; dots = []; rawOverlays = []
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        for screen in NSScreen.screens {
            let frame = screen.frame
            let panel = IndicatorWindow(contentRect: NSRect(x: frame.maxX - 22, y: frame.minY + 8, width: 16, height: 16), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.canHide = false
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
            panel.animationBehavior = .none
            panel.level = .screenSaver
            if #available(macOS 14.0, *) {
                panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            } else {
                panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            }
            panel.ignoresMouseEvents = false; panel.hidesOnDeactivate = false
            let dot = Dot(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
            dot.menu = makeMenu()
            panel.contentView = dot; panel.orderFrontRegardless()
            let raw = NDRawOverlayCreate(frame.maxX - 22, top - (frame.minY + 24), screen.backingScaleFactor)
            rawOverlays.append(raw)
            if ProcessInfo.processInfo.environment["NETWORK_DOT_BACKEND_REPORT"] == "1" {
                print("raw-overlay screen=\(rawOverlays.count - 1) window=\(NDRawOverlayWindowID(raw))")
                fflush(stdout)
            }
            dot.rendersColor = raw == nil
            panels.append(panel); dots.append(dot)
        }
        lastPaintedColor = nil
        update()
        panels.forEach { $0.displayIfNeeded() }
        oldPanels.forEach { $0.close() }
        oldRawOverlays.forEach { if let raw = $0 { NDRawOverlayDestroy(raw) } }
    }
    var lastPaintedColor: NSColor?
    func paint(_ color: NSColor, _ label: String) {
        state = label
        guard lastPaintedColor != color else { return }
        lastPaintedColor = color
        dots.forEach { $0.color = color }
        if let rgb = color.usingColorSpace(.sRGB) {
            rawOverlays.forEach { raw in
                if let raw { NDRawOverlayDraw(raw, rgb.redComponent, rgb.greenComponent, rgb.blueComponent) }
            }
        }

    }
    func update() {
        switch health.state(now: ProcessInfo.processInfo.systemUptime) {
        case .checking: paint(.systemGray, l("正在检测", "Checking connection"))
        case .online: paint(.systemGreen, l("互联网可用", "Internet available"))
        case .offline:
            paint(.systemRed, health.connected ? l("检测目标均未通过", "No probe has passed recently") : l("网络接口未连接", "Network interface disconnected"))
        }
    }
    func tick() {
        update()
        guard health.connected, round == nil else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now >= nextProbe else { return }
        nextProbe = now + 1.0
        let list = targets
        var next = ProbeRound(count: list.count, primary: selection.primary(now: now, count: list.count))
        let initial = next.start()
        round = next
        let currentGeneration = generation
        let roundID = next.id
        let work = DispatchWorkItem { [weak self] in
            self?.startFallback(roundID: roundID, generation: currentGeneration, targets: list)
        }
        fallbackWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
        initial.forEach { launch(index: $0, target: list[$0], roundID: roundID, generation: currentGeneration, targets: list) }
    }
    func startFallback(roundID: UUID, generation: Int, targets: [Target]) {
        guard self.generation == generation, var current = round, current.id == roundID else { return }
        let indices = current.fallback()
        round = current
        indices.forEach { launch(index: $0, target: targets[$0], roundID: roundID, generation: generation, targets: targets) }
    }
    func finishRound() {
        fallbackWork?.cancel(); fallbackWork = nil
        // Invalidate the round before cancelling, so late loser callbacks cannot change state.
        round = nil
        let losers = tasks.values
        tasks.removeAll()
        losers.forEach { $0.cancel() }
    }
    func launch(index: Int, target: Target, roundID: UUID, generation: Int, targets: [Target]) {
        let id = UUID()
        launchedRequestCount += 1
        launchCounts[target.url, default: 0] += 1
        selection.launched(index: index, now: ProcessInfo.processInfo.systemUptime)
        var request = URLRequest(url: URL(string: target.url)!)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("bytes=0-4095", forHTTPHeaderField: "Range")
        request.setValue("NetworkDot/1.1.1", forHTTPHeaderField: "User-Agent")
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self, self.generation == generation, var current = self.round, current.id == roundID else { return }
                self.tasks.removeValue(forKey: id)
                let http = response as? HTTPURLResponse
                let body = String(data: data ?? Data(), encoding: .utf8) ?? ""
                let valid = error == nil && (200...299).contains(http?.statusCode ?? 0) && http?.url?.host == URL(string: target.url)?.host && (target.token.isEmpty || body.contains(target.token)) && (target.token.isEmpty && target.code == 200 || http?.statusCode == target.code)
                self.details[target.url] = valid ? self.l("通过", "Passed") : (error?.localizedDescription ?? self.l("响应未符合预期", "Unexpected response") + " / HTTP \(http?.statusCode ?? 0)")
                let outcome = current.complete(index: index, success: valid)
                self.round = current
                switch outcome {
                case .winner(let winner):
                    self.health.succeeded(now: ProcessInfo.processInfo.systemUptime)
                    self.selection.succeeded(index: winner)
                    self.finishRound()
                case .startFallback:
                    self.startFallback(roundID: roundID, generation: generation, targets: targets)
                case .allFailed:
                    self.finishRound()
                case .ignored, .waiting: break
                }
                self.update()
            }
        }
        tasks[id] = task; task.resume()
    }
    @objc func showDetails() {
        let alert = NSAlert()
        alert.messageText = state
        alert.informativeText = targets.map { "\($0.url)\n\(details[$0.url] ?? l("备用／尚未检测", "Standby / not checked yet"))" }.joined(separator: "\n\n") + l("\n\n优先检测第一个目标（默认 Apple），正常时每秒一个请求。失败或 0.6 秒未响应时启用备用；使用备用时每分钟重试首选目标。最近 2 秒任一目标通过即绿色。\n本次运行已发起请求：", "\n\nFirst target preferred (Apple by default); one request per second while healthy. Backups start on failure or after 0.6 seconds without a response. The first target is retried every minute while using a backup. Green if any target passed within 2 seconds.\nRequests started this session: ") + String(launchedRequestCount) + l("\n红色也可能表示所有目标被屏蔽。", "\nRed may also mean all targets are blocked.")
        NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }
    @objc func settings() {
        let alert = NSAlert()
        alert.messageText = l("检测网址（每行一个 HTTPS 网址）", "Probe URLs (one HTTPS URL per line)")
        alert.informativeText = l("留空恢复 Apple、Google、Cloudflare。自定义网址以同域 HTTP 2xx 为通过；请使用公开、无需登录的小页面，避免认证页。", "Leave empty for Apple, Google and Cloudflare. Custom URLs pass on same-host HTTP 2xx. Use small public pages that do not require sign-in.")
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 440, height: 110))
        let text = NSTextView(frame: scroll.bounds)
        text.isRichText = false
        text.string = (UserDefaults.standard.stringArray(forKey: "targets") ?? []).joined(separator: "\n")
        scroll.documentView = text; scroll.hasVerticalScroller = true
        alert.accessoryView = scroll; alert.addButton(withTitle: l("保存", "Save")); alert.addButton(withTitle: l("取消", "Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let urls = text.string.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            guard urls.count <= 5, urls.allSatisfy({ guard let u = URL(string: $0) else { return false }; return u.scheme == "https" && u.host != nil && u.user == nil && u.password == nil }) else {
                let bad = NSAlert(); bad.messageText = l("请输入最多 5 个有效 HTTPS 网址", "Enter up to 5 valid HTTPS URLs"); bad.runModal(); return
            }
            UserDefaults.standard.set(urls, forKey: "targets"); reset(); tick()
        }
    }
    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        func item(_ title: String, _ action: Selector) -> NSMenuItem {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
            item.target = self
            return item
        }
        _ = item(l("网络状态详情…", "Connection details…"), #selector(showDetails))
        _ = item(l("设置检测网址…", "Probe URLs…"), #selector(settings))
        let login = item(l("登录时启动", "Launch at login"), #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        let languageItem = NSMenuItem(title: "语言 / Language", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for (code, title) in [("auto", "跟随系统 / System"), ("zh", "简体中文"), ("en", "English")] {
            let entry = languageMenu.addItem(withTitle: title, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            entry.target = self; entry.representedObject = code
            entry.state = language == code ? .on : .off
        }
        languageItem.submenu = languageMenu; menu.addItem(languageItem)
        _ = item(l("关于 Network Dot…", "About Network Dot…"), #selector(about))
        menu.addItem(.separator())
        _ = item(l("退出 Network Dot", "Quit Network Dot"), #selector(quit))
        return menu
    }
    func refreshMenus() { dots.forEach { $0.menu = makeMenu() }; update() }
    @objc func changeLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        UserDefaults.standard.set(code, forKey: "language")
        details.removeAll()
        DispatchQueue.main.async { [weak self] in self?.refreshMenus() }
    }
    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch {
            let alert = NSAlert()
            alert.messageText = l("无法更改登录启动", "Could not change launch at login")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        DispatchQueue.main.async { [weak self] in self?.refreshMenus() }
    }
    func welcome() {
        let alert = NSAlert()
        alert.messageText = l("欢迎使用 Network Dot", "Welcome to Network Dot")
        alert.informativeText = l("每个屏幕右下角的小点显示互联网状态。右键点击小点可设置或退出。\n\n建议先把应用移到“应用程序”文件夹。是否登录后自动启动？", "A tiny dot at the bottom-right of each screen shows internet status. Right-click the dot for settings or to quit.\n\nMove the app to Applications first. Would you like it to launch at login?")
        alert.addButton(withTitle: l("启用登录启动", "Enable launch at login"))
        alert.addButton(withTitle: l("暂不开启", "Not now"))
        NSApp.activate(ignoringOtherApps: true)
        UserDefaults.standard.set(true, forKey: "welcomeShown")
        if alert.runModal() == .alertFirstButtonReturn { toggleLogin() }
    }
    @objc func about() {
        let alert = NSAlert()
        alert.messageText = "Network Dot 1.1.2"
        alert.informativeText = l("绿色：最近 2 秒任一检测成功。红色：未连接或检测失败。灰色：初次检测。\n\n不收集遥测，不读取浏览记录。检测请求直接访问所选网址。\nhttps://github.com/A-Very-Long-Name/Network-Dot", "Green: a probe passed in the last 2 seconds. Red: disconnected or probes failed. Gray: checking.\n\nNo telemetry or browsing history access. Probes contact the selected URLs directly.\nhttps://github.com/A-Very-Long-Name/Network-Dot")
        NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }
    func applicationWillTerminate(_ notification: Notification) {
        rawOverlays.forEach { if let raw = $0 { NDRawOverlayDestroy(raw) } }
        rawOverlays = []
    }
    @objc func quit() { NSApp.terminate(nil) }
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
