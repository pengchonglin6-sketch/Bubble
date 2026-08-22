import SwiftUI

struct TagFilterBar: View {
    let tags: [(String, String)]
    @Binding var selectedTag: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagCapsule(
                    label: "全部",
                    color: .gray,
                    isSelected: selectedTag == nil,
                    action: { selectedTag = nil }
                )

                ForEach(tags, id: \.0) { tag, colorHex in
                    TagCapsule(
                        label: tag,
                        color: Color(hex: colorHex),
                        isSelected: selectedTag == tag,
                        action: { selectedTag = selectedTag == tag ? nil : tag }
                    )
                }
            }
        }
    }
}

private struct TagCapsule: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.30) : color.opacity(0.14))
                )
                .foregroundStyle(Color.primary.opacity(isSelected ? 0.84 : 0.70))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? color.opacity(0.68) : color.opacity(0.28),
                            lineWidth: 1
                        )
                )
                .shadow(color: isSelected ? color.opacity(0.12) : .clear, radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
}
