import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var btManager = BluetoothManager()
    
    let menu = NSMenu()
    var statusMenuItem: NSMenuItem!
    var slidingPill: SlidingPillControl!
    var bassBoostSwitch: SwitchMenuItemView!
    var ldacSwitch: SwitchMenuItemView!
    var startAtLoginSwitch: SwitchMenuItemView!
    
    var lastBassBoostTime = Date.distantPast
    var lastSpatialTime = Date.distantPast
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
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
            } else {
                button.image = NSImage(systemSymbolName: "headphones", accessibilityDescription: "Baseus Controller")
            }
        }
        
        // 1. Status
        statusMenuItem = NSMenuItem(title: "Status: Disconnected", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        // 2. Airpods-style Pill controls
        slidingPill = addPillToggle(
            leftLabelText: "Transparency", rightLabelText: "Noise Canc.",
            leftIcon: "person.wave.2.fill", rightIcon: "waveform.path.badge.minus",
            action: #selector(noiseControlChanged)
        )
        menu.addItem(NSMenuItem.separator())
        
        // 3. Noise Profiles
        let ancTitle = NSMenuItem(title: "Noise Profiles", action: nil, keyEquivalent: "")
        ancTitle.isEnabled = false
        menu.addItem(ancTitle)
        
        addProfileItem(title: "Commuting", icon: "tram.fill", hex: "BA340165")
        addProfileItem(title: "Indoor", icon: "house.fill", hex: "BA340166")
        addProfileItem(title: "Outdoor", icon: "sun.max.fill", hex: "BA340167")
        menu.addItem(NSMenuItem.separator())
        
        // 4. Spatial Audio
        let spatialTitle = NSMenuItem(title: "Spatial Audio", action: nil, keyEquivalent: "")
        spatialTitle.isEnabled = false
        menu.addItem(spatialTitle)
        
        addProfileItem(title: "None", icon: "speaker.fill", hex: "BA4300")
        addProfileItem(title: "Music", icon: "music.note", hex: "BA4301")
        addProfileItem(title: "Movie", icon: "film.fill", hex: "BA4302")
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Settings / Toggles
        let togglesTitle = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        togglesTitle.isEnabled = false
        menu.addItem(togglesTitle)
        
        bassBoostSwitch = addSwitchToggle(title: "Bass Boost", action: #selector(bassBoostChanged))
        ldacSwitch = addSwitchToggle(title: "LDAC", action: #selector(ldacChanged))
        
        startAtLoginSwitch = addSwitchToggle(title: "Start at Login", action: #selector(startAtLoginChanged))
        startAtLoginSwitch.isOn = SMAppService.mainApp.status == .enabled
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        let quitView = ProfileMenuItemView(title: "Quit", icon: "power", item: quitItem)
        quitItem.view = quitView
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        
        // Restore saved profile states instantly on launch
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "savedANCIndex") == nil {
            defaults.set(1, forKey: "savedANCIndex")
            defaults.set("BA340166", forKey: "savedANCHex")
            defaults.set("BA4300", forKey: "savedEQHex")
        }
        let savedANCIndex = defaults.integer(forKey: "savedANCIndex")
        let savedANCHex = defaults.string(forKey: "savedANCHex") ?? "BA340166"
        let savedEQHex = defaults.string(forKey: "savedEQHex") ?? "BA4300"
        let savedBassBoost = defaults.bool(forKey: "savedBassBoost")
        let savedLDAC = defaults.bool(forKey: "savedLDAC")
        
        slidingPill.setSelectedIndex(savedANCIndex, sendAction: false)
        updateMenuState(ancHex: savedANCHex, eqHex: savedEQHex)
        updateProfileEnabling()
        
        bassBoostSwitch.isOn = savedBassBoost
        ldacSwitch.isOn = savedLDAC
        
        btManager.onConnectionStateChanged = { [weak self] connected in
            self?.statusMenuItem.title = connected ? "Status: Connected" : "Status: Disconnected"
            if connected {
                // Request current hardware state dump (ANC mode, spatial audio, battery, etc.)
                self?.btManager.sendCommand(hexString: "BA0500")
            }
        }
        
        btManager.onEventReceived = { [weak self] bytes in
            guard let self = self else { return }
            
            let hexStr = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
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
            
            // ANC update
            if bytes[1] == 0x33 && bytes.count >= 4 {
                let hex = String(format: "BA34%02X%02X", bytes[2], bytes[3])
                if bytes[2] == 0x02 {
                    self.slidingPill.setSelectedIndex(0, sendAction: false)
                    self.saveProfileState(ancIndex: 0, ancHex: hex, eqHex: nil)
                } else if bytes[2] == 0x01 {
                    self.slidingPill.setSelectedIndex(1, sendAction: false)
                    self.saveProfileState(ancIndex: 1, ancHex: hex, eqHex: nil)
                }
                self.updateMenuState(ancHex: hex)
                self.updateProfileEnabling()
            } 
            // Overall Device State (Battery, ANC Mode)
            else if bytes[1] == 0x02 && bytes.count >= 6 {
                let mode = bytes[5]
                // Delay slightly to override the AA 33 profile dump that might arrive simultaneously on connect
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if mode == 0x02 {
                        self.slidingPill.setSelectedIndex(0, sendAction: false)
                        self.saveProfileState(ancIndex: 0, ancHex: "BA3402FF", eqHex: nil)
                    } else if mode == 0x01 {
                        self.slidingPill.setSelectedIndex(1, sendAction: false)
                        self.saveProfileState(ancIndex: 1, ancHex: nil, eqHex: nil)
                    }
                    self.updateProfileEnabling()
                }
            }
            // Spatial Audio update
            else if bytes[1] == 0x43 && bytes.count >= 3 {
                if Date().timeIntervalSince(self.lastSpatialTime) > 1.0 {
                    // External tap cycle
                    let currentHex = UserDefaults.standard.string(forKey: "savedEQHex") ?? "BA4300"
                    let nextHex: String
                    if currentHex == "BA4300" { nextHex = "BA4301" }
                    else if currentHex == "BA4301" { nextHex = "BA4302" }
                    else { nextHex = "BA4300" }
                    
                    self.updateMenuState(eqHex: nextHex)
                    self.saveProfileState(ancIndex: nil, ancHex: nil, eqHex: nextHex)
                }
            }
            // Bass Boost update
            else if bytes[1] == 0x54 && bytes.count >= 3 {
                if Date().timeIntervalSince(self.lastBassBoostTime) > 1.0 {
                    let newState = !self.bassBoostSwitch.isOn
                    self.bassBoostSwitch.isOn = newState
                    UserDefaults.standard.set(newState, forKey: "savedBassBoost")
                }
            }
            // LDAC update
            else if bytes[1] == 0x23 && bytes.count >= 3 {
                let isOn = bytes[2] == 0x01
                self.ldacSwitch.isOn = isOn
                UserDefaults.standard.set(isOn, forKey: "savedLDAC")
            }
        }
    }
    
    func addSwitchToggle(title: String, action: Selector) -> SwitchMenuItemView {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        let switchView = SwitchMenuItemView(title: title, item: item)
        item.view = switchView
        menu.addItem(item)
        return switchView
    }
    
    func addPillToggle(leftLabelText: String, rightLabelText: String, leftIcon: String, rightIcon: String, action: Selector) -> SlidingPillControl {
        let viewWidth: CGFloat = 260
        let viewHeight: CGFloat = 70
        let customView = NSView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        
        let pill = SlidingPillControl(frame: NSRect(x: 20, y: 25, width: viewWidth - 40, height: 36), leftIconName: leftIcon, rightIconName: rightIcon)
        pill.target = self
        pill.action = action
        customView.addSubview(pill)
        
        let segmentWidth = (viewWidth - 40) / 2
        
        let leftLabel = NSTextField(labelWithString: leftLabelText)
        leftLabel.font = NSFont.systemFont(ofSize: 11)
        leftLabel.textColor = .secondaryLabelColor
        leftLabel.alignment = .center
        leftLabel.isBezeled = false
        leftLabel.drawsBackground = false
        leftLabel.isEditable = false
        leftLabel.frame = NSRect(x: 20, y: 5, width: segmentWidth, height: 15)
        customView.addSubview(leftLabel)
        
        let rightLabel = NSTextField(labelWithString: rightLabelText)
        rightLabel.font = NSFont.systemFont(ofSize: 11)
        rightLabel.textColor = .secondaryLabelColor
        rightLabel.alignment = .center
        rightLabel.isBezeled = false
        rightLabel.drawsBackground = false
        rightLabel.isEditable = false
        rightLabel.frame = NSRect(x: 20 + segmentWidth, y: 5, width: segmentWidth, height: 15)
        customView.addSubview(rightLabel)
        
        let menuItem = NSMenuItem()
        menuItem.view = customView
        menu.addItem(menuItem)
        
        return pill
    }
    
    @objc func noiseControlChanged() {
        if slidingPill.selectedIndex == 0 {
            btManager.sendCommand(hexString: "BA3402FF")
            updateMenuState(ancHex: "BA3402FF")
            saveProfileState(ancIndex: 0, ancHex: "BA3402FF", eqHex: nil)
        } else {
            let lastANCHex = UserDefaults.standard.string(forKey: "savedANCHex") ?? "BA340166"
            let hexToSend = lastANCHex.hasPrefix("BA3401") ? lastANCHex : "BA340166"
            btManager.sendCommand(hexString: hexToSend)
            updateMenuState(ancHex: hexToSend)
            saveProfileState(ancIndex: 1, ancHex: hexToSend, eqHex: nil)
        }
        updateProfileEnabling()
    }
    
    func addProfileItem(title: String, icon: String, hex: String) {
        let item = NSMenuItem(title: title, action: #selector(modeSelected(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = hex
        
        let customView = ProfileMenuItemView(title: title, icon: icon, item: item)
        item.view = customView
        menu.addItem(item)
    }
    
    func updateMenuState(ancHex: String? = nil, eqHex: String? = nil) {
        for item in menu.items {
            if let hex = item.representedObject as? String {
                if let target = ancHex, hex.hasPrefix("BA34") {
                    if let customView = item.view as? ProfileMenuItemView {
                        customView.isSelectedMode = (hex == target)
                    }
                }
                if let target = eqHex, hex.hasPrefix("BA43") {
                    if let customView = item.view as? ProfileMenuItemView {
                        customView.isSelectedMode = (hex == target)
                    }
                }
            }
        }
    }
    
    func updateProfileEnabling() {
        let isANC = slidingPill.selectedIndex == 1
        for item in menu.items {
            if let hex = item.representedObject as? String, hex.hasPrefix("BA3401") {
                if let customView = item.view as? ProfileMenuItemView {
                    customView.isEnabled = isANC
                }
            }
        }
    }
    
    @objc func modeSelected(_ sender: NSMenuItem) {
        if let hex = sender.representedObject as? String {
            btManager.sendCommand(hexString: hex)
            
            if hex.hasPrefix("BA34") {
                if hex.hasPrefix("BA3401") {
                    slidingPill.setSelectedIndex(1, sendAction: false)
                    saveProfileState(ancIndex: 1, ancHex: hex, eqHex: nil)
                } else if hex == "BA3402FF" {
                    slidingPill.setSelectedIndex(0, sendAction: false)
                    saveProfileState(ancIndex: 0, ancHex: hex, eqHex: nil)
                }
                updateMenuState(ancHex: hex)
                updateProfileEnabling()
            } else if hex.hasPrefix("BA43") {
                lastSpatialTime = Date()
                updateMenuState(eqHex: hex)
                saveProfileState(ancIndex: nil, ancHex: nil, eqHex: hex)
            }
        }
    }
    
    func saveProfileState(ancIndex: Int?, ancHex: String?, eqHex: String?) {
        let defaults = UserDefaults.standard
        if let ancIndex = ancIndex { defaults.set(ancIndex, forKey: "savedANCIndex") }
        if let ancHex = ancHex { defaults.set(ancHex, forKey: "savedANCHex") }
        if let eqHex = eqHex { defaults.set(eqHex, forKey: "savedEQHex") }
    }
    
    @objc func bassBoostChanged() {
        let isOn = bassBoostSwitch.isOn
        UserDefaults.standard.set(isOn, forKey: "savedBassBoost")
        lastBassBoostTime = Date()
        btManager.sendCommand(hexString: isOn ? "BA5401" : "BA5400")
    }
    
    @objc func ldacChanged() {
        let isOn = ldacSwitch.isOn
        UserDefaults.standard.set(isOn, forKey: "savedLDAC")
        btManager.sendCommand(hexString: isOn ? "BA2401" : "BA2400")
    }
    
    @objc func startAtLoginChanged() {
        let service = SMAppService.mainApp
        do {
            if startAtLoginSwitch.isOn {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("Failed to update SMAppService: \(error)")
            // Revert the visual switch state if it failed
            startAtLoginSwitch.isOn = !startAtLoginSwitch.isOn
        }
    }
}
