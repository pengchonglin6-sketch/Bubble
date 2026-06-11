import SwiftUI
import SwiftData

struct PromptCardView: View {
    let prompt: Prompt
    var onEdit: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showCopied = false
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

    private func actionButton(systemName: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint ?? Color.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)
        withAnimation(.spring(duration: 0.2)) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.2)) { showCopied = false }
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
