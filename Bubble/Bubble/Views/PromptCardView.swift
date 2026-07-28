import SwiftUI
import SwiftData

struct PromptCardView: View {
    let prompt: Prompt
    var onEdit: () -> Void
    var onCopyComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showCopied = false
    @State private var isCopyAnimating = false
    @State private var isCopyPendingClose = false
    @State private var isHovered = false
    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 0) {
            // Left color accent
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: prompt.tagColor))
                .frame(width: 3)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(prompt.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if !prompt.tag.isEmpty {
                        Text(prompt.tag)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: prompt.tagColor).opacity(0.15), in: Capsule())
                            .foregroundStyle(Color(hex: prompt.tagColor))
                    }
                }

                Text(prompt.content)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.leading, 10)
            .padding(.vertical, 10)

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                actionButton(systemName: "square.and.pencil", action: onEdit)

                actionButton(
                    systemName: showCopied ? "checkmark" : "doc.on.doc",
                    tint: showCopied ? .green : nil,
                    scale: isCopyAnimating ? 0.78 : 1,
                    action: copyToClipboard
                )

                actionButton(
                    systemName: "trash",
                    tint: .red.opacity(0.85),
                    action: { showDeleteConfirm = true }
                )
            }
            .opacity(isHovered ? 1 : 0)
            .padding(.trailing, 8)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
        )
        .scaleEffect(isCopyAnimating ? 0.992 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.58), value: isCopyAnimating)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .alert("删除「\(prompt.title)」？", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deletePrompt() }
        } message: {
            Text("删除后无法恢复。")
        }
    }

    private func deletePrompt() {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(prompt)
        }
        try? modelContext.save()
    }

    private func actionButton(
        systemName: String,
        tint: Color? = nil,
        scale: CGFloat = 1,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint ?? Color.secondary)
                .scaleEffect(scale)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2, dampingFraction: 0.52), value: scale)
    }

    private func copyToClipboard() {
        guard !isCopyPendingClose else { return }
        isCopyPendingClose = true

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)

        withAnimation(.spring(response: 0.18, dampingFraction: 0.55)) {
            isCopyAnimating = true
            showCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.58)) {
                isCopyAnimating = false
            }
        }

        // 留出足够时间让用户看到按压和成功对勾，再收起整个面板。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            onCopyComplete()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showCopied = false
                isCopyPendingClose = false
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
