import Cocoa
import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var btManager = BluetoothManager()
    var appState = AppState()
    
    var lastBassBoostTime = Date.distantPast
    var lastSpatialTime = Date.distantPast
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Setup Popover and SwiftUI View
        let popoverView = MainPopoverView(state: appState)
        let hostingController = NSHostingController(rootView: popoverView)
        
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = hostingController
        
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .intrinsicContentSize
        }
        
        // Setup Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if let customIcon = NSImage(named: "MenubarIconTemplate") {
                let size = NSSize(width: 18, height: 18)
                
                // Create the Light Mode image (Yellow background, black logo)
                let lightImage = NSImage(size: size, flipped: false) { rect in
                    let yellow = NSColor(calibratedRed: 255/255.0, green: 226/255.0, blue: 0/255.0, alpha: 1.0)
                    yellow.setFill()
                    NSBezierPath(ovalIn: rect).fill()
                    
                    let iconRect = rect.insetBy(dx: 2, dy: 2)
                    customIcon.isTemplate = false
                    customIcon.draw(in: iconRect)
                    return true
                }
                
                // Create the Dark Mode image (Transparent background, white logo)
                let darkImage = NSImage(size: size, flipped: false) { rect in
                    let iconRect = rect.insetBy(dx: 2, dy: 2)
                    
                    let tinted = customIcon.copy() as! NSImage
                    tinted.lockFocus()
                    NSColor.white.set()
                    NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
                    tinted.unlockFocus()
                    
                    tinted.draw(in: iconRect)
                    return true
                }
                
                // Dynamic image that evaluates on every render
                let dynamicImage = NSImage(size: size, flipped: false) { rect in
                    let isDark = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    if isDark {
                        darkImage.draw(in: rect)
                    } else {
                        lightImage.draw(in: rect)
                    }
                    return true
                }
                
                dynamicImage.isTemplate = false
                button.image = dynamicImage
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Restore saved profile states instantly on launch
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "savedANCIndex") == nil {
            defaults.set(1, forKey: "savedANCIndex")
            defaults.set("BA340166", forKey: "savedANCHex")
            defaults.set("BA4300", forKey: "savedEQHex")
        }
        appState.ancMode = defaults.integer(forKey: "savedANCIndex")
        appState.ancProfile = defaults.string(forKey: "savedANCHex") ?? "BA340166"
        appState.spatialAudio = defaults.string(forKey: "savedEQHex") ?? "BA4300"
        appState.isBassBoostEnabled = defaults.bool(forKey: "savedBassBoost")
        appState.isLDACEnabled = defaults.bool(forKey: "savedLDAC")
        appState.isStartAtLoginEnabled = SMAppService.mainApp.status == .enabled
        
        // Setup Callbacks from SwiftUI View
        appState.onAncToggle = { [weak self] mode in
            guard let self = self else { return }
            if mode == 0 {
                self.btManager.sendCommand(hexString: "BA3402FF")
                self.saveProfileState(ancIndex: 0, ancHex: "BA3402FF", eqHex: nil)
            } else {
                let lastANCHex = defaults.string(forKey: "savedANCHex") ?? "BA340166"
                let hexToSend = lastANCHex.hasPrefix("BA3401") ? lastANCHex : "BA340166"
                self.btManager.sendCommand(hexString: hexToSend)
                self.saveProfileState(ancIndex: 1, ancHex: hexToSend, eqHex: nil)
            }
            self.appState.ancMode = mode
        }
        
        appState.onAncProfileSelect = { [weak self] hex in
            self?.btManager.sendCommand(hexString: hex)
            self?.saveProfileState(ancIndex: 1, ancHex: hex, eqHex: nil)
            self?.appState.ancProfile = hex
            self?.appState.ancMode = 1
        }
        
        appState.onSpatialSelect = { [weak self] hex in
            self?.btManager.sendCommand(hexString: hex)
            self?.saveProfileState(ancIndex: nil, ancHex: nil, eqHex: hex)
            self?.appState.spatialAudio = hex
            self?.lastSpatialTime = Date()
        }
        
        appState.onBassBoostToggle = { [weak self] isOn in
            defaults.set(isOn, forKey: "savedBassBoost")
            self?.lastBassBoostTime = Date()
            self?.btManager.sendCommand(hexString: isOn ? "BA5401" : "BA5400")
            self?.appState.isBassBoostEnabled = isOn
        }
        
        appState.onLDACToggle = { [weak self] isOn in
            defaults.set(isOn, forKey: "savedLDAC")
            self?.btManager.sendCommand(hexString: isOn ? "BA2401" : "BA2400")
            self?.appState.isLDACEnabled = isOn
        }
        
        appState.onStartAtLoginToggle = { [weak self] isOn in
            let service = SMAppService.mainApp
            do {
                if isOn { try service.register() }
                else { try service.unregister() }
                self?.appState.isStartAtLoginEnabled = isOn
            } catch {
                print("Failed to update SMAppService: \(error)")
                self?.appState.isStartAtLoginEnabled = !isOn
            }
        }
        
        appState.onQuit = {
            NSApplication.shared.terminate(nil)
        }
        
        // Setup Bluetooth Manager Listeners
        btManager.onConnectionStateChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.appState.isConnected = connected
                self?.appState.deviceName = self?.btManager.peripheral?.name ?? "Baseus Headset"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self?.updatePopoverSize()
                }
            }
            if connected {
                self?.btManager.sendCommand(hexString: "BA0500")
            }
        }
        
        btManager.onEventReceived = { [weak self] bytes in
            guard let self = self else { return }
            
            let hexStr = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
            self.logEvent(hexStr)
            
            DispatchQueue.main.async {
                // ANC update
                if bytes[1] == 0x33 && bytes.count >= 4 {
                    let hex = String(format: "BA34%02X%02X", bytes[2], bytes[3])
                    
                    if bytes[2] == 0x00 {
                        self.appState.isAncHardwareEnabled = false
                    } else {
                        self.appState.isAncHardwareEnabled = true
                        if bytes[2] == 0x02 {
                            self.appState.ancMode = 0
                            self.saveProfileState(ancIndex: 0, ancHex: hex, eqHex: nil)
                        } else if bytes[2] == 0x01 {
                            self.appState.ancMode = 1
                            self.appState.ancProfile = hex
                            self.saveProfileState(ancIndex: 1, ancHex: hex, eqHex: nil)
                        }
                    }
                }
                // Overall Device State (Battery, ANC Mode)
                else if bytes[1] == 0x02 && bytes.count >= 6 {
                    let mode = bytes[5]
                    if mode == 0x02 {
                        self.appState.ancMode = 0
                        self.saveProfileState(ancIndex: 0, ancHex: "BA3402FF", eqHex: nil)
                    } else if mode == 0x01 {
                        self.appState.ancMode = 1
                        self.saveProfileState(ancIndex: 1, ancHex: nil, eqHex: nil)
                    }
                }
                // Spatial Audio update
                else if bytes[1] == 0x43 && bytes.count >= 3 {
                    if Date().timeIntervalSince(self.lastSpatialTime) > 1.0 {
                        let currentHex = defaults.string(forKey: "savedEQHex") ?? "BA4300"
                        let nextHex: String
                        if currentHex == "BA4300" { nextHex = "BA4301" }
                        else if currentHex == "BA4301" { nextHex = "BA4302" }
                        else { nextHex = "BA4300" }
                        
                        self.appState.spatialAudio = nextHex
                        self.saveProfileState(ancIndex: nil, ancHex: nil, eqHex: nextHex)
                    }
                }
                // Bass Boost update
                else if bytes[1] == 0x54 && bytes.count >= 3 {
                    if Date().timeIntervalSince(self.lastBassBoostTime) > 1.0 {
                        let newState = !self.appState.isBassBoostEnabled
                        self.appState.isBassBoostEnabled = newState
                        defaults.set(newState, forKey: "savedBassBoost")
                    }
                }
                // LDAC update
                else if bytes[1] == 0x23 && bytes.count >= 3 {
                    let isOn = bytes[2] == 0x01
                    self.appState.isLDACEnabled = isOn
                    defaults.set(isOn, forKey: "savedLDAC")
                }
            }
        }
    }
    
    func logEvent(_ hexStr: String) {
        let fm = FileManager.default
        if let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDir = appSupportURL.appendingPathComponent("BaseusController")
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
            let logURL = appDir.appendingPathComponent("hidden_events.log")
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write((hexStr + "\n").data(using: .utf8)!)
                handle.closeFile()
            } else {
                try? (hexStr + "\n").write(to: logURL, atomically: true, encoding: .utf8)
            }
        }
    }
    
    func saveProfileState(ancIndex: Int?, ancHex: String?, eqHex: String?) {
        let defaults = UserDefaults.standard
        if let ancIndex = ancIndex { defaults.set(ancIndex, forKey: "savedANCIndex") }
        if let ancHex = ancHex { defaults.set(ancHex, forKey: "savedANCHex") }
        if let eqHex = eqHex { defaults.set(eqHex, forKey: "savedEQHex") }
    }
    
    func updatePopoverSize() {
        if let hostingController = popover.contentViewController as? NSHostingController<MainPopoverView> {
            let newSize = hostingController.sizeThatFits(in: NSSize(width: 260, height: 1000))
            if newSize.height > 0 {
                popover.contentSize = newSize
            }
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                updatePopoverSize()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
