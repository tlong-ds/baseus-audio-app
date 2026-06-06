import Cocoa
import CoreBluetooth

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral?
    var writeCharacteristic: CBCharacteristic?
    
    let serviceUUID = CBUUID(string: "53527AA4-29F7-AE11-4E74-997334782568")
    let charUUID = CBUUID(string: "EE684B1A-1E9B-ED3E-EE55-F894667E92AC")
    
    var onConnectionStateChanged: ((Bool) -> Void)?
    var onEventReceived: (([UInt8]) -> Void)?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
        } else {
            print("Bluetooth is not available.")
            onConnectionStateChanged?(false)
        }
    }
    
    func startScanning() {
        if peripheral == nil {
            print("Scanning for Baseus H1S...")
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Found \(peripheral.name ?? "device")")
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected. Reconnecting...")
        self.peripheral = nil
        self.writeCharacteristic = nil
        onConnectionStateChanged?(false)
        startScanning()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                if service.uuid == serviceUUID {
                    peripheral.discoverCharacteristics([charUUID], for: service)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for char in characteristics {
                if char.uuid == charUUID {
                    self.writeCharacteristic = char
                    print("Ready to send commands!")
                }
                if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                    peripheral.setNotifyValue(true, for: char)
                }
            }
            DispatchQueue.main.async {
                self.onConnectionStateChanged?(true)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, data.count >= 3 else { return }
        let bytes = [UInt8](data)
        if bytes[0] == 0xAA {
            DispatchQueue.main.async {
                self.onEventReceived?(bytes)
            }
        }
    }
    
    func sendCommand(hexString: String) {
        guard let peripheral = peripheral, let char = writeCharacteristic else {
            print("Not connected or characteristic missing")
            return
        }
        
        var bytes = [UInt8]()
        var hex = hexString
        while hex.count > 0 {
            let index = hex.index(hex.startIndex, offsetBy: 2)
            let byteString = String(hex[..<index])
            hex = String(hex[index...])
            if let byte = UInt8(byteString, radix: 16) {
                bytes.append(byte)
            }
        }
        
        let data = Data(bytes)
        peripheral.writeValue(data, for: char, type: .withResponse)
        print("Sent \(hexString)")
    }
}

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

class ProfileMenuItemView: NSView {
    weak var menuItem: NSMenuItem?
    let titleLabel = NSTextField(labelWithString: "")
    let iconView = NSImageView()
    let highlightLayer = CALayer()
    
    var isSelectedMode: Bool = false {
        didSet { updateAppearance() }
    }
    
    var isHovered: Bool = false {
        didSet { updateAppearance() }
    }
    
    var isEnabled: Bool = true {
        didSet { updateAppearance() }
    }
    
    init(title: String, icon: String, item: NSMenuItem) {
        self.menuItem = item
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 30))
        self.wantsLayer = true
        
        highlightLayer.frame = NSRect(x: 10, y: 0, width: 240, height: 30)
        highlightLayer.cornerRadius = 5
        layer?.addSublayer(highlightLayer)
        
        iconView.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
        iconView.frame = NSRect(x: 25, y: 7, width: 16, height: 16)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        addSubview(iconView)
        
        titleLabel.stringValue = title
        titleLabel.font = NSFont.menuBarFont(ofSize: 13)
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.frame = NSRect(x: 55, y: 4, width: 180, height: 18)
        titleLabel.wantsLayer = true
        addSubview(titleLabel)
        
        let trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        
        updateAppearance()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func mouseEntered(with event: NSEvent) {
        if isEnabled { isHovered = true }
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
    
    override func mouseUp(with event: NSEvent) {
        if isEnabled, let item = menuItem {
            if let action = item.action {
                NSApp.sendAction(action, to: item.target, from: item)
            }
        }
    }
    
    func updateAppearance() {
        if !isEnabled {
            highlightLayer.backgroundColor = NSColor.clear.cgColor
            titleLabel.textColor = NSColor.disabledControlTextColor
            iconView.contentTintColor = NSColor.disabledControlTextColor
            return
        }
        
        if isHovered || isSelectedMode {
            highlightLayer.backgroundColor = NSColor.controlAccentColor.cgColor
            titleLabel.textColor = .white
            iconView.contentTintColor = .white
        } else {
            highlightLayer.backgroundColor = NSColor.clear.cgColor
            titleLabel.textColor = NSColor.labelColor
            iconView.contentTintColor = NSColor.labelColor
        }
    }
}

class SlidingPillControl: NSControl {
    private var visualEffectView: NSVisualEffectView!
    private var thumbLayer = CALayer()
    private var leftIcon: NSImageView!
    private var rightIcon: NSImageView!
    
    private var _selectedIndex: Int = 1
    var selectedIndex: Int {
        get { return _selectedIndex }
        set { setSelectedIndex(newValue, sendAction: true) }
    }
    
    func setSelectedIndex(_ index: Int, sendAction: Bool) {
        guard _selectedIndex != index else { return }
        _selectedIndex = index
        animateThumb(to: index)
        if sendAction {
            self.sendAction(action, to: target)
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        // Glass background
        visualEffectView = NSVisualEffectView(frame: bounds)
        visualEffectView.material = .hudWindow // Dark glass look
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = frameRect.height / 2
        visualEffectView.layer?.masksToBounds = true
        addSubview(visualEffectView)
        
        // Thumb layer
        let thumbPadding: CGFloat = 3
        let thumbHeight = frameRect.height - (thumbPadding * 2)
        let segmentWidth = frameRect.width / 2
        let initialCenterX = segmentWidth + segmentWidth / 2
        let initialX = initialCenterX - thumbHeight / 2
        
        thumbLayer.frame = NSRect(x: initialX, y: thumbPadding, width: thumbHeight, height: thumbHeight)
        thumbLayer.cornerRadius = thumbHeight / 2
        thumbLayer.backgroundColor = NSColor.white.cgColor
        thumbLayer.shadowColor = NSColor.black.cgColor
        thumbLayer.shadowOpacity = 0.2
        thumbLayer.shadowRadius = 2
        thumbLayer.shadowOffset = CGSize(width: 0, height: -1)
        visualEffectView.layer?.addSublayer(thumbLayer)
        
        // Icons
        let iconSize: CGFloat = 20
        let iconY = (frameRect.height - iconSize) / 2
        let leftX = segmentWidth / 2 - iconSize / 2
        let rightX = segmentWidth + segmentWidth / 2 - iconSize / 2
        
        leftIcon = NSImageView(frame: NSRect(x: leftX, y: iconY, width: iconSize, height: iconSize))
        leftIcon.image = NSImage(systemSymbolName: "person.wave.2.fill", accessibilityDescription: nil)
        leftIcon.imageScaling = .scaleProportionallyUpOrDown
        leftIcon.wantsLayer = true
        addSubview(leftIcon)
        
        rightIcon = NSImageView(frame: NSRect(x: rightX, y: iconY, width: iconSize, height: iconSize))
        rightIcon.image = NSImage(systemSymbolName: "waveform.path.badge.minus", accessibilityDescription: nil)
        rightIcon.imageScaling = .scaleProportionallyUpOrDown
        rightIcon.wantsLayer = true
        addSubview(rightIcon)
        
        updateIconColors()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func thumbCenter(for index: Int) -> CGFloat {
        let segmentWidth = bounds.width / 2
        return index == 0 ? segmentWidth / 2 : segmentWidth + segmentWidth / 2
    }
    
    private func updateIconColors() {
        // iOS style: selected icon is colored (e.g. blue or dark), unselected is white/light
        leftIcon.contentTintColor = selectedIndex == 0 ? .systemBlue : .white
        rightIcon.contentTintColor = selectedIndex == 1 ? .systemBlue : .white
    }
    
    private func animateThumb(to index: Int) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            let thumbPadding: CGFloat = 3
            let thumbHeight = bounds.height - (thumbPadding * 2)
            let x = self.thumbCenter(for: index) - thumbHeight / 2
            self.thumbLayer.frame.origin.x = x
        }, completionHandler: {
            self.updateIconColors()
        })
    }
    
    override func mouseDown(with event: NSEvent) {
        // Run a local event loop to prevent the menu from tracking the drag and drawing its highlight pill
        var keepOn = true
        var currentEvent = event
        
        while keepOn {
            let point = convert(currentEvent.locationInWindow, from: nil)
            updateThumbTracking(with: point)
            
            if currentEvent.type == .leftMouseUp {
                keepOn = false
                if point.x < bounds.width / 2 {
                    setSelectedIndex(0, sendAction: true)
                } else {
                    setSelectedIndex(1, sendAction: true)
                }
                break
            }
            
            if let nextEvent = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged], until: .distantFuture, inMode: .eventTracking, dequeue: true) {
                currentEvent = nextEvent
            }
        }
    }
    
    private func updateThumbTracking(with point: NSPoint) {
        let thumbPadding: CGFloat = 3
        let thumbHeight = bounds.height - (thumbPadding * 2)
        var x = point.x - thumbHeight / 2
        x = max(thumbPadding, min(x, bounds.width - thumbHeight - thumbPadding))
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        thumbLayer.frame.origin.x = x
        CATransaction.commit()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
