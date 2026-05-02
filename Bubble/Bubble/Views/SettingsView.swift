import SwiftUI
import HotKey

struct SettingsView: View {
    let onDismiss: () -> Void

    @State private var hotKeyDisplay: String = HotKeyManager.shared.currentDisplayString
    @State private var isRecording = false
    @State private var launchAtLogin = SettingsManager.shared.launchAtLogin
    @State private var showMenuBarIcon = SettingsManager.shared.showMenuBarIcon

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar

            ScrollView {
                VStack(spacing: 0) {
                    hotKeySection
                    Divider().padding(.horizontal, 16)
                    launchAtLoginSection
                    Divider().padding(.horizontal, 16)
                    menuBarSection
                }
                .padding(.top, 8)
            }

            Spacer()
            versionFooter
        }
        .frame(width: 420, height: 520)
        .background(.ultraThickMaterial)
    }

    private var headerBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Text("设置")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var hotKeySection: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("全局快捷键")
                    .font(.system(size: 13, weight: .medium))
                Text("在任意应用中唤起面板")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HotKeyRecorderView(
                display: $hotKeyDisplay,
                isRecording: $isRecording,
                onCommit: { key, modifiers in
                    HotKeyManager.shared.save(key: key, modifiers: modifiers)
                    hotKeyDisplay = HotKeyManager.shared.currentDisplayString
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var launchAtLoginSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("开机启动")
                    .font(.system(size: 13, weight: .medium))
                Text("开机自动启动 PromptBubble")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: launchAtLogin) { _, newValue in
                    SettingsManager.shared.launchAtLogin = newValue
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var menuBarSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("显示菜单栏入口")
                    .font(.system(size: 13, weight: .medium))
                Text("关闭后仍可用快捷键唤起面板")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $showMenuBarIcon)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: showMenuBarIcon) { _, newValue in
                    SettingsManager.shared.showMenuBarIcon = newValue
                    if let delegate = NSApp.delegate as? AppDelegate {
                        delegate.setMenuBarVisible(newValue)
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var versionFooter: some View {
        HStack {
            Spacer()
            Text("Bubble v1.0.0")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.bottom, 16)
    }
}

struct HotKeyRecorderView: View {
    @Binding var display: String
    @Binding var isRecording: Bool
    let onCommit: (Key, NSEvent.ModifierFlags) -> Void

    @State private var pendingDisplay = ""
    @State private var monitor: Any?

    var body: some View {
        Button(action: startRecording) {
            Text(isRecording ? (pendingDisplay.isEmpty ? "按下快捷键…" : pendingDisplay) : display)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(isRecording ? .blue : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.blue.opacity(0.1) : Color.primary.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(isRecording ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .onDisappear { stopMonitoring() }
    }

    private func startRecording() {
        guard !isRecording else {
            stopRecording()
            return
        }
        isRecording = true
        pendingDisplay = ""

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !modifiers.isEmpty,
                  let key = Key(carbonKeyCode: UInt32(event.keyCode)) else {
                if event.keyCode == 53 { // Escape
                    self.stopRecording()
                }
                return nil
            }

            self.pendingDisplay = self.modifierString(modifiers) + self.keyDisplayString(key)
            self.onCommit(key, modifiers)
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        pendingDisplay = ""
        stopMonitoring()
    }

    private func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func modifierString(_ modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option)  { result += "⌥" }
        if modifiers.contains(.shift)   { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result
    }

    private func keyDisplayString(_ key: Key) -> String {
        switch key {
        case .space: return "Space"
        case .return: return "↩"
        case .delete: return "⌫"
        case .tab: return "⇥"
        case .escape: return "Esc"
        default: return key.description.uppercased()
        }
    }
}
