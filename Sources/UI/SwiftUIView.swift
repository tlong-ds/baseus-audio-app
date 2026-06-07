import SwiftUI
import Cocoa

class AppState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var deviceName: String = "Baseus Headset"
    @Published var batteryLevel: Int = 100
    @Published var ancMode: Int = 1 // 0 = Transparency, 1 = ANC
    @Published var ancProfile: String = "BA340166" // Commuting, Indoor, Outdoor
    @Published var spatialAudio: String = "BA4300" // None, Music, Movie
    @Published var isBassBoostEnabled: Bool = false
    @Published var isLDACEnabled: Bool = false
    @Published var isAncHardwareEnabled: Bool = true
    @Published var isStartAtLoginEnabled: Bool = false
    
    var onAncToggle: ((Int) -> Void)?
    var onAncProfileSelect: ((String) -> Void)?
    var onSpatialSelect: ((String) -> Void)?
    var onBassBoostToggle: ((Bool) -> Void)?
    var onLDACToggle: ((Bool) -> Void)?
    var onStartAtLoginToggle: ((Bool) -> Void)?
    var onQuit: (() -> Void)?
}

struct MainPopoverView: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.isConnected {
                ConnectedHeaderView(state: state)
                
                Divider().padding(.vertical, 4)
                
                // Pill
                SlidingPillSwiftUI(selectedIndex: $state.ancMode, isEnabled: state.isAncHardwareEnabled) { newMode in
                    state.onAncToggle?(newMode)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                Divider().padding(.vertical, 4)
                
                // Noise Profiles
                MenuTextItem(title: "Noise Profiles")
                MenuItem(title: "Commuting", icon: "tram.fill", isSelected: state.ancProfile == "BA340165", isEnabled: state.ancMode == 1 && state.isAncHardwareEnabled) { state.onAncProfileSelect?("BA340165") }
                MenuItem(title: "Indoor", icon: "house.fill", isSelected: state.ancProfile == "BA340166", isEnabled: state.ancMode == 1 && state.isAncHardwareEnabled) { state.onAncProfileSelect?("BA340166") }
                MenuItem(title: "Outdoor", icon: "sun.max.fill", isSelected: state.ancProfile == "BA340167", isEnabled: state.ancMode == 1 && state.isAncHardwareEnabled) { state.onAncProfileSelect?("BA340167") }
                
                Divider().padding(.vertical, 4)
                
                // Spatial Audio
                MenuTextItem(title: "Spatial Audio")
                MenuItem(title: "None", icon: "speaker.fill", isSelected: state.spatialAudio == "BA4300", isEnabled: true) { state.onSpatialSelect?("BA4300") }
                MenuItem(title: "Music", icon: "music.note", isSelected: state.spatialAudio == "BA4301", isEnabled: true) { state.onSpatialSelect?("BA4301") }
                MenuItem(title: "Movie", icon: "film.fill", isSelected: state.spatialAudio == "BA4302", isEnabled: true) { state.onSpatialSelect?("BA4302") }
                
                Divider().padding(.vertical, 4)
                
                // Settings
                MenuTextItem(title: "Settings")
                MenuToggleItem(title: "Bass Boost", isOn: $state.isBassBoostEnabled) { val in state.onBassBoostToggle?(val) }
                MenuToggleItem(title: "LDAC", isOn: $state.isLDACEnabled) { val in state.onLDACToggle?(val) }
                MenuToggleItem(title: "Start at Login", isOn: $state.isStartAtLoginEnabled) { val in state.onStartAtLoginToggle?(val) }
                
                Divider().padding(.vertical, 4)
            } else {
                DisconnectedView()
                Divider().padding(.vertical, 4)
            }
            
            MenuItem(title: "Quit", icon: "power", isSelected: false, isEnabled: true) { state.onQuit?() }
        }
        .padding(.vertical, 8)
        .frame(width: 260)
    }
}

struct DisconnectedView: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 60, height: 60)
                Image(systemName: "headphones")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
            Text("Connect the headphone...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            Text("Ensure your Baseus headset is powered on and connected via Bluetooth.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

struct ConnectedHeaderView: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            if let imageURL = Bundle.main.url(forResource: "image", withExtension: "webp"),
               let nsImage = NSImage(contentsOf: imageURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
            } else {
                Image(systemName: "headphones.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(state.deviceName)
                    .font(.system(size: 14, weight: .bold))
                
                HStack(spacing: 4) {
                    Image(systemName: state.batteryLevel > 20 ? "battery.100" : "battery.25")
                        .foregroundColor(state.batteryLevel > 20 ? .green : .red)
                    Text("\(state.batteryLevel)%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

// Mimics disabled NSMenuItem text
struct MenuTextItem: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
    }
}

// Mimics ProfileMenuItemView
struct MenuItem: View {
    var title: String
    var icon: String
    var isSelected: Bool
    var isEnabled: Bool
    var action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEnabled { action() }
        }
        .foregroundColor(isEnabled ? (isSelected || isHovered ? .white : .primary) : .secondary)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor : (isHovered ? Color.secondary.opacity(0.1) : Color.clear))
                .opacity(isEnabled ? 1.0 : 0.0)
        )
        .padding(.horizontal, 10)
        .onHover { hovering in
            if isEnabled {
                isHovered = hovering
            }
        }
        .disabled(!isEnabled)
    }
}

struct MenuToggleItem: View {
    var title: String
    @Binding var isOn: Bool
    var onChange: (Bool) -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .labelsHidden()
                .controlSize(.small)
                .focusable(false)
                .padding(.trailing, 2)
                .onChange(of: isOn) { val in
                    onChange(val)
                }
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
    }
}

struct SlidingPillSwiftUI: View {
    @Binding var selectedIndex: Int
    var isEnabled: Bool
    var onToggle: (Int) -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    let pillWidth: CGFloat = 236
    let thumbPadding: CGFloat = 3
    let height: CGFloat = 36
    
    var segmentWidth: CGFloat { pillWidth / 2 }
    var leftCenter: CGFloat { segmentWidth / 2 }
    var rightCenter: CGFloat { segmentWidth + (segmentWidth / 2) }
    
    var currentCenter: CGFloat {
        let targetCenter = selectedIndex == 0 ? leftCenter : rightCenter
        let current = targetCenter + dragOffset
        return max(leftCenter, min(rightCenter, current))
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.5))
                    .frame(width: pillWidth, height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                
                let thumbHeight = height - (thumbPadding * 2)
                
                // Thumb
                RoundedRectangle(cornerRadius: thumbHeight / 2)
                    .fill(Color.accentColor)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .frame(width: thumbHeight, height: thumbHeight)
                    .position(x: currentCenter, y: height / 2)
                    .animation(isDragging ? .interactiveSpring() : .easeOut(duration: 0.2), value: currentCenter)
                
                // Icons
                HStack(spacing: 0) {
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: segmentWidth, height: height)
                        .contentShape(Rectangle())
                    
                    Image(systemName: "waveform.path.badge.minus")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: segmentWidth, height: height)
                        .contentShape(Rectangle())
                }
            }
            .frame(width: pillWidth, height: height)
            .opacity(isEnabled ? 1.0 : 0.4)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        isDragging = true
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        guard isEnabled else { return }
                        isDragging = false
                        
                        if abs(value.translation.width) < 5 {
                            // Treat as a tap
                            let newIndex = value.location.x < segmentWidth ? 0 : 1
                            dragOffset = 0
                            if newIndex != selectedIndex {
                                onToggle(newIndex)
                            }
                        } else {
                            // Treat as a drag
                            let threshold: CGFloat = segmentWidth / 3
                            let isSwipingRight = value.predictedEndTranslation.width > threshold || value.translation.width > threshold
                            let isSwipingLeft = value.predictedEndTranslation.width < -threshold || value.translation.width < -threshold
                            
                            var newIndex = selectedIndex
                            if selectedIndex == 0 && isSwipingRight {
                                newIndex = 1
                            } else if selectedIndex == 1 && isSwipingLeft {
                                newIndex = 0
                            }
                            
                            dragOffset = 0
                            if newIndex != selectedIndex {
                                onToggle(newIndex)
                            }
                        }
                    }
            )
            
            // Labels under pill
            HStack(spacing: 0) {
                Text("Transparency")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: pillWidth / 2)
                Text("Noise Canc.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: pillWidth / 2)
            }
            .frame(width: pillWidth)
        }
    }
}
