import SwiftUI
import AppKit

/// Clean, authoritative Settings UI for SiriEdge.
/// Binds directly to EdgeSettings.shared with instant live reflection.
public struct SettingsView: View {
    @ObservedObject var settings = EdgeSettings.shared
    @ObservedObject var power = PowerSource.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Banner
            HStack(spacing: 12) {
                if let icon = NSImage(named: "SiriEdgeMenuBarIcon_128") ?? NSImage(named: "SiriEdgeMenuBarIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                } else {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.cyan, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("SiriEdge")
                        .font(.system(size: 16, weight: .bold))
                    Text("Apple Intelligence Animated Edge Glow")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                statusBadge
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)
            
            Divider()
            
            // Settings Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: - GENERAL
                    sectionCard(title: "GENERAL", systemImage: "gearshape") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Operation Mode")
                                .font(.system(size: 12, weight: .medium))
                            
                            Picker("", selection: $settings.controlMode) {
                                ForEach(EdgeSettings.ControlMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Text(modeDescription)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // MARK: - ANIMATION
                    sectionCard(title: "ANIMATION", systemImage: "sparkles") {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Animation")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text("Thinking (Chasing Flow)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            // Animation Speed
                            sliderRow(
                                title: "Animation Speed",
                                value: $settings.animationSpeed,
                                range: 0.25...2.0,
                                format: "%.2fx",
                                minLabel: "0.25x",
                                maxLabel: "2.0x"
                            )
                            
                            // Border Transparency
                            sliderRow(
                                title: "Border Transparency",
                                value: $settings.transparency,
                                range: 0.10...1.0,
                                format: "%d%%",
                                multiplier: 100,
                                minLabel: "10%",
                                maxLabel: "100%"
                            )
                            
                            // Glow Brightness
                            sliderRow(
                                title: "Glow Brightness",
                                value: $settings.brightness,
                                range: 0.25...1.0,
                                format: "%d%%",
                                multiplier: 100,
                                minLabel: "25%",
                                maxLabel: "100%"
                            )
                            
                            // Glow Width / Halo
                            sliderRow(
                                title: "Glow Width / Halo",
                                value: $settings.glowStrength,
                                range: 0.10...1.0,
                                format: "%d%%",
                                multiplier: 100,
                                minLabel: "10%",
                                maxLabel: "100%"
                            )
                        }
                    }
                    
                    // MARK: - DISPLAY
                    sectionCard(title: "DISPLAY", systemImage: "display") {
                        VStack(spacing: 10) {
                            infoRow(
                                label: "Physical Display",
                                value: NSScreen.main?.localizedName ?? "Built-in Retina Display"
                            )
                            
                            infoRow(
                                label: "Refresh Rate",
                                value: displayRefreshRateString
                            )
                            
                            HStack {
                                Text("Target FPS")
                                    .font(.system(size: 12))
                                Spacer()
                                Picker("", selection: $settings.fpsMode) {
                                    ForEach(EdgeSettings.FPSMode.allCases) { fps in
                                        Text(fps.displayName).tag(fps)
                                    }
                                }
                                .frame(width: 140)
                            }
                            
                            if settings.fpsMode == .custom {
                                HStack {
                                    Text("Custom FPS Target")
                                        .font(.system(size: 12))
                                    Spacer()
                                    Stepper(
                                        "\(settings.customFPS) FPS",
                                        value: $settings.customFPS,
                                        in: 15...120,
                                        step: 5
                                    )
                                }
                            }
                        }
                    }
                    
                    // MARK: - POWER
                    sectionCard(title: "POWER", systemImage: "bolt.fill") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Power Mode")
                                    .font(.system(size: 12))
                                Spacer()
                                Picker("", selection: $settings.powerMode) {
                                    ForEach(EdgeSettings.PowerMode.allCases) { pm in
                                        Text(pm.displayName).tag(pm)
                                    }
                                }
                                .frame(width: 170)
                            }
                            
                            Toggle(isOn: $settings.isBatterySaverEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Battery Saver")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Optimizes GPU fragment shading to preserve battery life")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            
                            HStack {
                                Text("Current Power State")
                                    .font(.system(size: 12))
                                Spacer()
                                Label(
                                    power.isChargerConnected ? "AC Power (Charger Connected)" : "Battery Power (\(power.batteryPercentage ?? 100)%)",
                                    systemImage: power.isChargerConnected ? "bolt.fill" : "battery.75"
                                )
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(power.isChargerConnected ? .green : .orange)
                            }
                        }
                    }
                    
                    // MARK: - SYSTEM
                    sectionCard(title: "SYSTEM", systemImage: "macbook") {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Activity Timeout")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Automatically hides SiriEdge after continuous manual activation")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(settings.activityTimeoutMinutes) minutes")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 460, height: 680)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Helpers
    
    private var isGlowActive: Bool {
        switch settings.controlMode {
        case .forceOff: return false
        case .forceOn: return true
        case .auto: return power.isChargerConnected
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isGlowActive ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
            Text(isGlowActive ? "ACTIVE" : "IDLE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isGlowActive ? .green : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
    
    private var modeDescription: String {
        switch settings.controlMode {
        case .auto:
            return "SiriEdge automatically activates when the charger is connected, and turns off on battery."
        case .forceOn:
            return "SiriEdge stays active continuously (with 5-minute timeout)."
        case .forceOff:
            return "SiriEdge is turned off completely."
        }
    }
    
    private var displayRefreshRateString: String {
        if let screen = NSScreen.main,
           let mode = CGDisplayCopyDisplayMode(screen.displayID ?? CGMainDisplayID()) {
            let hz = mode.refreshRate
            return hz > 0 ? "\(Int(round(hz))) Hz" : "60 Hz"
        }
        return "60 Hz"
    }
    
    @ViewBuilder
    private func sectionCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private func sliderRow(
        title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String,
        multiplier: Float = 1.0,
        minLabel: String,
        maxLabel: String
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                Spacer()
                Text(String(format: format, multiplier > 1.0 ? Int(round(value.wrappedValue * multiplier)) : value.wrappedValue))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            
            Slider(value: value, in: range)
            
            HStack {
                Text(minLabel)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text(maxLabel)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}
