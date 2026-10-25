import AppKit
import ApplicationServices
import Foundation

// MARK: - Window Management Helper
struct WindowInfo {
    let pid: pid_t
    let windowId: CGWindowID
    let ownerName: String
    let windowName: String
    let bounds: CGRect
    let element: AXUIElement
}

class WindowManager {
    static func getVisibleWindows() -> [WindowInfo] {
        var results: [WindowInfo] = []
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return results
        }

        for entry in windowList {
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let ownerName = entry[kCGWindowOwnerName as String] as? String,
                  let windowIdNum = entry[kCGWindowNumber as String] as? UInt32,
                  let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"], let y = boundsDict["Y"],
                  let w = boundsDict["Width"], let h = boundsDict["Height"],
                  w > 50 && h > 50
            else { continue }
            
            let windowName = (entry[kCGWindowName as String] as? String) ?? ""
            let appElement = AXUIElementCreateApplication(pid)
            
            var axWindowsVal: AnyObject?
            let axErr = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &axWindowsVal)
            if axErr == .success, let axWindows = axWindowsVal as? [AXUIElement] {
                var matchedElement: AXUIElement? = nil
                for axWin in axWindows {
                    var titleVal: AnyObject?
                    if AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleVal) == .success,
                       let axTitle = titleVal as? String, axTitle == windowName {
                        matchedElement = axWin
                        break
                    }
                }
                
                if matchedElement == nil {
                    matchedElement = axWindows.first
                }
                
                if let matchedElement = matchedElement {
                    let frame = CGRect(x: x, y: y, width: w, height: h)
                    results.append(WindowInfo(
                        pid: pid,
                        windowId: CGWindowID(windowIdNum),
                        ownerName: ownerName,
                        windowName: windowName,
                        bounds: frame,
                        element: matchedElement
                    ))
                }
            }
        }
        return results
    }
    
    static func isMouseOnAnyWindowTitleBar() -> Bool {
        let mouseLoc = NSEvent.mouseLocation
        guard let mainScreen = NSScreen.screens.first else { return false }
        let screenHeight = mainScreen.frame.height
        // Convert AppKit bottom-left coordinate to CoreGraphics top-left coordinate space
        let cgPoint = CGPoint(x: mouseLoc.x, y: screenHeight - mouseLoc.y)
        
        let windows = getVisibleWindows()
        for window in windows {
            // Define the title bar region as the top 30 points of the window bounds
            let titleBarRect = CGRect(
                x: window.bounds.minX,
                y: window.bounds.minY,
                width: window.bounds.width,
                height: 30.0
            )
            if titleBarRect.contains(cgPoint) {
                return true
            }
        }
        return false
    }
    
    static func focusWindow(_ window: WindowInfo) {
        let app = NSRunningApplication(processIdentifier: window.pid)
        app?.activate()
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
    }
}

// MARK: - Window Switcher HUD Overlay
class WindowSwitcherHUD {
    private var panel: NSPanel?
    private var stackView: NSStackView?
    private var scrollView: NSScrollView?
    private var rowViews: [NSView] = []
    private var titleLabels: [NSTextField] = []
    private var headerLabel: NSTextField?
    
    init() {
        setupPanel()
    }
    
    private func setupPanel() {
        DispatchQueue.main.async {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            
            let visualEffect = NSVisualEffectView(frame: panel.contentView!.bounds)
            visualEffect.autoresizingMask = [.width, .height]
            visualEffect.state = .active
            visualEffect.material = .hudWindow
            visualEffect.blendingMode = .behindWindow
            visualEffect.wantsLayer = true
            visualEffect.layer?.cornerRadius = 16
            visualEffect.layer?.masksToBounds = true
            
            let scrollView = NSScrollView()
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.hasVerticalScroller = true
            scrollView.borderType = .noBorder
            scrollView.drawsBackground = false
            
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 8
            stack.translatesAutoresizingMaskIntoConstraints = false
            
            scrollView.documentView = stack
            visualEffect.addSubview(scrollView)
            
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 16),
                scrollView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -16),
                scrollView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 16),
                scrollView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -16),
                stack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
            ])
            
            panel.contentView?.addSubview(visualEffect)
            panel.center()
            
            self.panel = panel
            self.stackView = stack
            self.scrollView = scrollView
        }
    }
    
    func prepare(windows: [WindowInfo]) {
        DispatchQueue.main.async {
            guard let stackView = self.stackView, let panel = self.panel else { return }
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            self.rowViews.removeAll()
            self.titleLabels.removeAll()
            
            let header = NSTextField(labelWithString: "Window Switcher")
            header.font = NSFont.boldSystemFont(ofSize: 13)
            header.textColor = NSColor.secondaryLabelColor
            stackView.addArrangedSubview(header)
            self.headerLabel = header
            
            for window in windows {
                let rowView = NSView()
                rowView.wantsLayer = true
                rowView.layer?.cornerRadius = 8
                rowView.translatesAutoresizingMaskIntoConstraints = false
                rowView.layer?.backgroundColor = NSColor.clear.cgColor
                
                let titleLabel = NSTextField(labelWithString: "\(window.ownerName) — \(window.windowName.isEmpty ? "Untitled" : window.windowName)")
                titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
                titleLabel.textColor = NSColor.labelColor
                titleLabel.lineBreakMode = .byTruncatingTail
                titleLabel.translatesAutoresizingMaskIntoConstraints = false
                
                rowView.addSubview(titleLabel)
                NSLayoutConstraint.activate([
                    rowView.heightAnchor.constraint(equalToConstant: 30),
                    rowView.widthAnchor.constraint(equalToConstant: 400),
                    titleLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
                    titleLabel.leadingAnchor.constraint(equalTo: rowView.leadingAnchor, constant: 12),
                    titleLabel.trailingAnchor.constraint(equalTo: rowView.trailingAnchor, constant: -12)
                ])
                
                stackView.addArrangedSubview(rowView)
                self.rowViews.append(rowView)
                self.titleLabels.append(titleLabel)
            }
            
            let rowHeight: CGFloat = 38
            let calculatedHeight = min(CGFloat(windows.count) * rowHeight + 60, 500)
            panel.setContentSize(NSSize(width: 440, height: calculatedHeight))
            panel.center()
            
            self.panel?.orderFrontRegardless()
        }
    }
    
    func updateSelection(selectedIndex: Int, totalCount: Int) {
        DispatchQueue.main.async {
            self.headerLabel?.stringValue = "Window Switcher (\(selectedIndex + 1)/\(totalCount))"
            
            for (index, rowView) in self.rowViews.enumerated() {
                let isSelected = (index == selectedIndex)
                rowView.layer?.backgroundColor = isSelected ? NSColor.selectedControlColor.withAlphaComponent(0.6).cgColor : NSColor.clear.cgColor
                self.titleLabels[index].font = NSFont.systemFont(ofSize: 13, weight: isSelected ? .bold : .regular)
                self.titleLabels[index].textColor = isSelected ? NSColor.white : NSColor.labelColor
            }
        }
    }
    
    func hide() {
        DispatchQueue.main.async {
            self.panel?.orderOut(nil)
        }
    }
}

// MARK: - Gesture Log Window Controller
class GestureLogWindowController: NSObject {
    private var window: NSWindow?
    private var textView: NSTextView?
    
    func showWindow() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 380),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.title = "GestureSwitch Gesture Logs"
            win.center()
            win.isReleasedWhenClosed = false
            
            let scrollView = NSScrollView(frame: win.contentView!.bounds)
            scrollView.autoresizingMask = [.width, .height]
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            
            let tView = NSTextView(frame: scrollView.bounds)
            tView.autoresizingMask = [.width, .height]
            tView.isEditable = false
            tView.isSelectable = true
            tView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            tView.backgroundColor = NSColor.textBackgroundColor
            tView.textColor = NSColor.textColor
            
            scrollView.documentView = tView
            win.contentView?.addSubview(scrollView)
            self.window = win
            self.textView = tView
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func appendLog(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let textView = self.textView else { return }
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let fullString = "[\(timestamp)] \(message)\n"
            
            if let textStorage = textView.textStorage {
                textStorage.beginEditing()
                textStorage.mutableString.append(fullString)
                textStorage.endEditing()
                textView.scrollToEndOfDocument(nil)
            }
        }
    }
}

// MARK: - Trackpad Gesture Engine
class SwishGestureEngine {
    var isEnabled: Bool = true
    var isLoggingEnabled: Bool = true
    var logHandler: ((String) -> Void)?
    
    private var accumulatedDeltaX: CGFloat = 0.0
    private let swipeThreshold: CGFloat = 30.0
    private let stepCooldown: TimeInterval = 0.22
    private var lastStepTime: Date = .distantPast
    private var scrollMonitor: Any?
    private var clickKeyMonitor: Any?
    private let hud = WindowSwitcherHUD()
    private var windows: [WindowInfo] = []
    private var currentIndex: Int = 0
    private var isSwitcherVisible: Bool = false
    private var commitWorkItem: DispatchWorkItem?

    func start() {
        log("🚀 GestureSwitch Trackpad Gesture Engine started.")
        
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handleScrollEvent(event)
        }

        if scrollMonitor == nil {
            log("⚠️ Global scroll monitor failed. Falling back to local monitor.")
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
                self?.handleScrollEvent(event)
                return event
            }
        }

        clickKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
            guard let self = self, self.isSwitcherVisible else { return }
            if event.type == .keyDown && (event.keyCode == 36 || event.keyCode == 52) {
                self.log("⏎ Enter key pressed. Committing selection.")
                self.commitSelection()
            } else if event.type == .leftMouseDown {
                self.log("🖱️ Mouse click detected. Committing selection.")
                self.commitSelection()
            }
        }
    }

    private func log(_ message: String) {
        if isLoggingEnabled {
            logHandler?(message)
        }
    }

    private func handleScrollEvent(_ event: NSEvent) {
        guard isEnabled else { return }
        guard event.hasPreciseScrollingDeltas else { return }
        
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY
        
        guard abs(deltaX) > abs(deltaY) * 2.0 else { return }

        if event.phase == .ended || event.phase == .cancelled {
            if isSwitcherVisible {
                log("🛑 Gesture ended. Committing selection.")
                commitSelection()
            }
            return
        }

        if !isSwitcherVisible {
            // 🛡️ Require mouse to be over a window's title bar to activate
            guard WindowManager.isMouseOnAnyWindowTitleBar() else { return }
            
            windows = WindowManager.getVisibleWindows()
            guard windows.count > 1 else { return }
            guard abs(deltaX) > 2.0 else { return }
            
            log("✨ Swipe started on title bar! Opening HUD switcher with \(windows.count) windows.")
            isSwitcherVisible = true
            currentIndex = 0
            accumulatedDeltaX = 0.0
            lastStepTime = .distantPast
            
            hud.prepare(windows: windows)
            hud.updateSelection(selectedIndex: currentIndex, totalCount: windows.count)
            rescheduleCommitTimer()
            return
        }
        
        accumulatedDeltaX += deltaX
        let now = Date()
        
        if now.timeIntervalSince(lastStepTime) >= stepCooldown {
            if accumulatedDeltaX > swipeThreshold {
                currentIndex = (currentIndex + 1) % windows.count
                accumulatedDeltaX = 0.0
                lastStepTime = now
                log("👉 Stepped forward -> Index \(currentIndex) [\(windows[currentIndex].ownerName)]")
                hud.updateSelection(selectedIndex: currentIndex, totalCount: windows.count)
            } else if accumulatedDeltaX < -swipeThreshold {
                currentIndex = (currentIndex - 1 + windows.count) % windows.count
                accumulatedDeltaX = 0.0
                lastStepTime = now
                log("👈 Stepped backward -> Index \(currentIndex) [\(windows[currentIndex].ownerName)]")
                hud.updateSelection(selectedIndex: currentIndex, totalCount: windows.count)
            }
        }
        
        rescheduleCommitTimer()
    }

    private func rescheduleCommitTimer() {
        commitWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.isSwitcherVisible else { return }
            self.log("⏱️ Pause timeout reached (1.0s). Committing selection.")
            self.commitSelection()
        }
        commitWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func commitSelection() {
        guard isSwitcherVisible, !windows.isEmpty else { return }
        isSwitcherVisible = false
        commitWorkItem?.cancel()
        hud.hide()
        
        let targetWindow = windows[currentIndex]
        log("⚡️ Switched active window to: [\(targetWindow.ownerName)] \(targetWindow.windowName)")
        WindowManager.focusWindow(targetWindow)
    }
}

// MARK: - Application Delegate (Menu Bar & Lifecycle)
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let gestureEngine = SwishGestureEngine()
    let logWindowController = GestureLogWindowController()
    
    let statusMenuItem = NSMenuItem(title: "Status: Active", action: nil, keyEquivalent: "")
    let toggleEnableMenuItem = NSMenuItem(title: "Disable GestureSwitch", action: #selector(toggleEnable), keyEquivalent: "")
    let toggleLoggingMenuItem = NSMenuItem(title: "Disable Gesture Logging", action: #selector(toggleLogging), keyEquivalent: "")
    
    var permissionTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "macwindow.badge.plus", accessibilityDescription: "GestureSwitch") ?? NSImage(named: NSImage.statusAvailableName)
        }
        
        let menu = NSMenu()
        
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        toggleEnableMenuItem.target = self
        menu.addItem(toggleEnableMenuItem)
        
        toggleLoggingMenuItem.target = self
        menu.addItem(toggleLoggingMenuItem)
        
        let showLogItem = NSMenuItem(title: "Show Gesture Log...", action: #selector(showLogWindow), keyEquivalent: "l")
        showLogItem.target = self
        menu.addItem(showLogItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit GestureSwitch", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        gestureEngine.logHandler = { [weak self] message in
            self?.logWindowController.appendLog(message)
        }
        
        checkAccessibilityAndStart()
    }
    
    func checkAccessibilityAndStart() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        
        if AXIsProcessTrustedWithOptions(options) {
            gestureEngine.start()
        } else {
            statusMenuItem.title = "Status: Needs Accessibility"
            toggleEnableMenuItem.isEnabled = false
            
            logWindowController.appendLog("⚠️ Accessibility permission required. Please enable GestureSwitch in System Settings.")
            
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.permissionTimer = nil
                    self?.statusMenuItem.title = "Status: Active"
                    self?.toggleEnableMenuItem.isEnabled = true
                    self?.gestureEngine.start()
                    self?.logWindowController.appendLog("✅ Accessibility permissions granted automatically!")
                }
            }
        }
    }
    
    @objc func toggleEnable() {
        gestureEngine.isEnabled.toggle()
        if gestureEngine.isEnabled {
            statusMenuItem.title = "Status: Active"
            toggleEnableMenuItem.title = "Disable GestureSwitch"
            statusItem.button?.alphaValue = 1.0
            logWindowController.appendLog("🟢 GestureSwitch enabled.")
        } else {
            statusMenuItem.title = "Status: Disabled"
            toggleEnableMenuItem.title = "Enable GestureSwitch"
            statusItem.button?.alphaValue = 0.4
            logWindowController.appendLog("🔴 GestureSwitch disabled.")
        }
    }
    
    @objc func toggleLogging() {
        gestureEngine.isLoggingEnabled.toggle()
        if gestureEngine.isLoggingEnabled {
            toggleLoggingMenuItem.title = "Disable Gesture Logging"
            logWindowController.appendLog("📝 Gesture logging enabled.")
        } else {
            toggleLoggingMenuItem.title = "Enable Gesture Logging"
        }
    }
    
    @objc func showLogWindow() {
        logWindowController.showWindow()
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - App Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()