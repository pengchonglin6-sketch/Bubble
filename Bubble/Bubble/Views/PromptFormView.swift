import SwiftUI
import SwiftData

struct PromptFormView: View {
    @Environment(\.modelContext) private var modelContext
    let prompt: Prompt?
    let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedTag: String = ""
    @State private var selectedColor: String = "#4A90D9"
    @State private var showDeleteConfirm = false

    private let maxContentLength = 2000

    private let presetTags: [(String, String)] = [
        ("写作", "#4A90D9"),
        ("编程", "#50B83C"),
        ("翻译", "#E8913A"),
        ("办公", "#DE3D82"),
        ("营销", "#9C6ADE"),
        ("学习", "#EEC200"),
    ]

    private var isEditing: Bool { prompt != nil }
    private var canSave: Bool { !title.isEmpty && !content.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "编辑提示词" : "新建提示词")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("标题")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("输入提示词标题", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("提示词内容")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(content.count) / \(maxContentLength)")
                                .font(.system(size: 11))
                                .foregroundColor(content.count > maxContentLength ? .red : .gray)
                        }
                        TextEditor(text: $content)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 120)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .onChange(of: content) { _, newValue in
                                if newValue.count > maxContentLength {
                                    content = String(newValue.prefix(maxContentLength))
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("标签（可选）")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(presetTags, id: \.0) { tag, color in
                                    Button(action: {
                                        if selectedTag == tag {
                                            selectedTag = ""
                                            selectedColor = "#4A90D9"
                                        } else {
                                            selectedTag = tag
                                            selectedColor = color
                                        }
                                    }) {
                                        Text(tag)
                                            .font(.system(size: 12))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                Capsule().fill(
                                                    selectedTag == tag
                                                        ? Color(hex: color).opacity(0.2)
                                                        : Color(hex: color).opacity(0.08)
                                                )
                                            )
                                            .foregroundStyle(
                                                selectedTag == tag
                                                    ? Color(hex: color)
                                                    : .secondary
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        TextField("或输入自定义标签", text: Binding(
                            get: {
                                presetTags.contains(where: { $0.0 == selectedTag }) ? "" : selectedTag
                            },
                            set: { newValue in
                                selectedTag = newValue
                                if !newValue.isEmpty {
                                    let colors = ["#4A90D9", "#50B83C", "#E8913A", "#DE3D82", "#9C6ADE", "#EEC200", "#E74C3C", "#95A5A6"]
                                    selectedColor = colors[abs(newValue.hashValue) % colors.count]
                                }
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 16)
            }

            Divider().padding(.horizontal, 16)

            HStack {
                if isEditing {
                    Button("删除", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .foregroundStyle(.red)
                }

                Spacer()

                Button("取消") { onDismiss() }
                    .keyboardShortcut(.cancelAction)

                Button(isEditing ? "保存" : "创建") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 520)
        .background(.ultraThickMaterial)
        .onAppear {
            if let prompt {
                title = prompt.title
                content = prompt.content
                selectedTag = prompt.tag
                selectedColor = prompt.tagColor
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deleteAndDismiss() }
        } message: {
            Text("删除后无法恢复，确定要删除这条提示词吗？")
        }
    }

    private func save() {
        if let prompt {
            prompt.title = title
            prompt.content = content
            prompt.tag = selectedTag
            prompt.tagColor = selectedColor
            prompt.updatedAt = Date()
        } else {
            let newPrompt = Prompt(
                title: title,
                content: content,
                tag: selectedTag,
                tagColor: selectedColor
            )
            modelContext.insert(newPrompt)
        }
        try? modelContext.save()
        onDismiss()
    }

    private func deleteAndDismiss() {
        if let prompt {
            modelContext.delete(prompt)
            try? modelContext.save()
        }
        onDismiss()
    }
}
