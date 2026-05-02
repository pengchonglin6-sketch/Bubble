import SwiftUI

struct PromptCardView: View {
    let prompt: Prompt
    var onEdit: () -> Void

    @State private var showCopied = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: prompt.tagColor))
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(prompt.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(prompt.content)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.leading, 12)
            .padding(.vertical, 8)

            Spacer(minLength: 8)

            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button(action: copyToClipboard) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                            .foregroundStyle(showCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? .white.opacity(0.1) : .white.opacity(0.05))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt.content, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showCopied = false
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
