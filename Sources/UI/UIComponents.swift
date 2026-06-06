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
