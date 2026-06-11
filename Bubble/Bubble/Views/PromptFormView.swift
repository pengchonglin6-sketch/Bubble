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
    @State private var saveErrorMessage: String? = nil

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

    // 磨砂深色面板上 .ultraThinMaterial 几乎不可见，输入区域需要明确的底色+描边
    private func inputBackground(cornerRadius: CGFloat = 8) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.primary.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            )
    }
    private var canSave: Bool {
        !title.isEmpty && !content.isEmpty && content.count <= maxContentLength
    }

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
                            .background(inputBackground())
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
                            .background(inputBackground())
                            // 不在 onChange 里硬截断：中文输入法组字阶段（marked text）
                            // 字符数会临时超限，截断会打断输入法。改为超限时禁用保存按钮。
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
                                    // 不能用 hashValue：它每次启动随机化种子，同一标签的颜色会变
                                    let stableHash = newValue.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFFFFFF }
                                    selectedColor = colors[stableHash % colors.count]
                                }
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(8)
                        .background(inputBackground())
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
        .alert("保存失败", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
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
                tagColor: selectedColor,
                sortOrder: nextSortOrder()
            )
            modelContext.insert(newPrompt)
        }
        commitAndDismiss()
    }

    private func nextSortOrder() -> Int {
        var descriptor = FetchDescriptor<Prompt>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        let maxOrder = (try? modelContext.fetch(descriptor))?.first?.sortOrder ?? -1
        return maxOrder + 1
    }

    private func deleteAndDismiss() {
        if let prompt {
            modelContext.delete(prompt)
        }
        commitAndDismiss()
    }

    private func commitAndDismiss() {
        do {
            try modelContext.save()
            onDismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
        }
    }
}
