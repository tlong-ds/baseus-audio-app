import Cocoa

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
    
    init(frame frameRect: NSRect, leftIconName: String, rightIconName: String) {
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
        leftIcon.image = NSImage(systemSymbolName: leftIconName, accessibilityDescription: nil)
        leftIcon.imageScaling = .scaleProportionallyUpOrDown
        leftIcon.wantsLayer = true
        addSubview(leftIcon)
        
        rightIcon = NSImageView(frame: NSRect(x: rightX, y: iconY, width: iconSize, height: iconSize))
        rightIcon.image = NSImage(systemSymbolName: rightIconName, accessibilityDescription: nil)
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

class SwitchMenuItemView: NSView {
    weak var menuItem: NSMenuItem?
    let titleLabel = NSTextField(labelWithString: "")
    let toggleSwitch = LiquidGlassSwitch(frame: NSRect(x: 200, y: 5, width: 36, height: 20))
    
    init(title: String, item: NSMenuItem) {
        self.menuItem = item
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 30))
        
        titleLabel.stringValue = title
        titleLabel.font = NSFont.menuBarFont(ofSize: 13)
        titleLabel.isBezeled = false
        titleLabel.drawsBackground = false
        titleLabel.isEditable = false
        titleLabel.frame = NSRect(x: 20, y: 6, width: 180, height: 18)
        addSubview(titleLabel)
        
        toggleSwitch.target = self
        toggleSwitch.action = #selector(switchChanged)
        addSubview(toggleSwitch)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    @objc func switchChanged() {
        if let item = menuItem, let action = item.action {
            NSApp.sendAction(action, to: item.target, from: item)
        }
    }
    
    var isOn: Bool {
        get { return toggleSwitch.isOn }
        set { toggleSwitch.isOn = newValue }
    }
}

class LiquidGlassSwitch: NSControl {
    private var visualEffectView: NSVisualEffectView!
    private var thumbLayer = CALayer()
    private var borderLayer = CAShapeLayer()
    
    private var _isOn: Bool = false
    var isOn: Bool {
        get { return _isOn }
        set { setOn(newValue, animated: false) }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.masksToBounds = false
        
        visualEffectView = NSVisualEffectView(frame: bounds)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        
        // Proper masking for visual effect view
        let maskLayer = CAShapeLayer()
        let path = CGPath(roundedRect: bounds, cornerWidth: bounds.height / 2, cornerHeight: bounds.height / 2, transform: nil)
        maskLayer.path = path
        visualEffectView.layer?.mask = maskLayer
        addSubview(visualEffectView)
        
        // Inner border for liquid glass depth
        borderLayer.frame = bounds
        borderLayer.path = path
        borderLayer.fillColor = NSColor.clear.cgColor
        borderLayer.strokeColor = NSColor.white.withAlphaComponent(0.15).cgColor
        borderLayer.lineWidth = 1.0
        visualEffectView.layer?.addSublayer(borderLayer)
        
        let thumbHeight = frameRect.height - 4
        thumbLayer.frame = NSRect(x: 2, y: 2, width: thumbHeight, height: thumbHeight)
        thumbLayer.cornerRadius = thumbHeight / 2
        thumbLayer.backgroundColor = NSColor.white.cgColor
        
        // Liquid glass thumb shadow
        thumbLayer.shadowColor = NSColor.black.cgColor
        thumbLayer.shadowOpacity = 0.35
        thumbLayer.shadowRadius = 3
        thumbLayer.shadowOffset = CGSize(width: 0, height: -1.5)
        
        // Outer glow/shadow
        let outerShadow = CALayer()
        outerShadow.frame = thumbLayer.bounds
        outerShadow.cornerRadius = thumbHeight / 2
        outerShadow.backgroundColor = NSColor.clear.cgColor
        outerShadow.shadowColor = NSColor.white.cgColor
        outerShadow.shadowOpacity = 0.5
        outerShadow.shadowRadius = 1
        outerShadow.shadowOffset = .zero
        thumbLayer.addSublayer(outerShadow)
        
        visualEffectView.layer?.addSublayer(thumbLayer)
        
        updateAppearance(animated: false)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setOn(_ on: Bool, animated: Bool) {
        guard _isOn != on else { return }
        _isOn = on
        updateAppearance(animated: animated)
    }
    
    private func updateAppearance(animated: Bool) {
        let thumbHeight = bounds.height - 4
        let targetX = _isOn ? bounds.width - thumbHeight - 2 : 2
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.thumbLayer.frame.origin.x = targetX
            }
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.thumbLayer.frame.origin.x = targetX
            CATransaction.commit()
        }
        
        // Changing material must be done outside the animation context or it won't apply properly
        self.visualEffectView.material = self._isOn ? .selection : .hudWindow
    }
    
    override func mouseDown(with event: NSEvent) {
        setOn(!_isOn, animated: true)
        self.sendAction(action, to: target)
    }
}
