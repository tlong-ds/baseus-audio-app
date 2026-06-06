import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var btManager = BluetoothManager()
    
    let menu = NSMenu()
    var statusMenuItem: NSMenuItem!
    var slidingPill: SlidingPillControl!
    
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
                    let isDark = NSAppearance.current.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
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
        
        // 2. Airpods-style Pill control
        setupIOSStyleControl()
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
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        let quitView = ProfileMenuItemView(title: "Quit", icon: "power", item: quitItem)
        quitItem.view = quitView
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        updateProfileEnabling()
        
        btManager.onConnectionStateChanged = { [weak self] connected in
            self?.statusMenuItem.title = connected ? "Status: Connected" : "Status: Disconnected"
            if connected {
                // Request current hardware state dump (ANC mode, spatial audio, battery, etc.)
                self?.btManager.sendCommand(hexString: "BA0500")
            }
        }
        
        btManager.onEventReceived = { [weak self] bytes in
            guard let self = self else { return }
            
            // ANC update
            if bytes[1] == 0x33 && bytes.count >= 4 {
                let hex = String(format: "BA34%02X%02X", bytes[2], bytes[3])
                if bytes[2] == 0x02 {
                    self.slidingPill.setSelectedIndex(0, sendAction: false)
                } else if bytes[2] == 0x01 {
                    self.slidingPill.setSelectedIndex(1, sendAction: false)
                }
                self.updateMenuState(ancHex: hex)
                self.updateProfileEnabling()
            } 
            // Spatial Audio / EQ update
            else if bytes[1] == 0x43 && bytes.count >= 3 {
                let hex = String(format: "BA43%02X", bytes[2])
                self.updateMenuState(eqHex: hex)
            }
        }
    }
    
    func setupIOSStyleControl() {
        let viewWidth: CGFloat = 260
        let viewHeight: CGFloat = 70
        let customView = NSView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: viewHeight))
        
        slidingPill = SlidingPillControl(frame: NSRect(x: 20, y: 25, width: viewWidth - 40, height: 36))
        slidingPill.target = self
        slidingPill.action = #selector(noiseControlChanged)
        customView.addSubview(slidingPill)
        
        let segmentWidth = (viewWidth - 40) / 2
        
        // Labels
        let leftLabel = NSTextField(labelWithString: "Transparency")
        leftLabel.font = NSFont.systemFont(ofSize: 11)
        leftLabel.textColor = .secondaryLabelColor
        leftLabel.alignment = .center
        leftLabel.isBezeled = false
        leftLabel.drawsBackground = false
        leftLabel.isEditable = false
        leftLabel.frame = NSRect(x: 20, y: 5, width: segmentWidth, height: 15)
        customView.addSubview(leftLabel)
        
        let rightLabel = NSTextField(labelWithString: "Noise Canc.")
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
    }
    
    @objc func noiseControlChanged() {
        if slidingPill.selectedIndex == 0 {
            btManager.sendCommand(hexString: "BA3402FF")
            updateMenuState(ancHex: "BA3402FF")
        } else {
            btManager.sendCommand(hexString: "BA340166")
            updateMenuState(ancHex: "BA340166")
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
                } else if hex == "BA3402FF" {
                    slidingPill.setSelectedIndex(0, sendAction: false)
                }
                updateMenuState(ancHex: hex)
                updateProfileEnabling()
            } else if hex.hasPrefix("BA43") {
                updateMenuState(eqHex: hex)
            }
        }
    }
}
