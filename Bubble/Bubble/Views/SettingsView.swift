import SwiftUI

struct SettingsView: View {
    let onDismiss: () -> Void

    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            .padding(.bottom, 20)

            VStack(spacing: 20) {
                settingRow(
                    icon: "keyboard",
                    title: "全局快捷键",
                    subtitle: "在任意应用中唤起面板"
                ) {
                    Text("⌘ ⇧ Space")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                }

                Divider().padding(.horizontal, 16)

                settingRow(
                    icon: "arrow.clockwise",
                    title: "开机启动",
                    subtitle: "开机自动启动 PromptBubble"
                ) {
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                Divider().padding(.horizontal, 16)

                settingRow(
                    icon: "menubar.rectangle",
                    title: "显示菜单栏入口",
                    subtitle: "在菜单栏显示 PromptBubble 入口"
                ) {
                    Toggle("", isOn: $showMenuBarIcon)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Text("Bubble v1.0.0")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.bottom, 16)
        }
        .frame(width: 420, height: 520)
        .background(.ultraThickMaterial)
    }

    private func settingRow<Trailing: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
    }
}
