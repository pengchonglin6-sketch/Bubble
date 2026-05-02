import SwiftUI
import SwiftData

enum PanelPage {
    case list
    case create
    case edit(Prompt)
    case settings

    var isList: Bool {
        if case .list = self { return true }
        return false
    }
}

struct MainPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Prompt.sortOrder) private var prompts: [Prompt]

    @State private var searchText = ""
    @State private var selectedTag: String? = nil
    @State private var currentPage: PanelPage = .list

    private var filteredPrompts: [Prompt] {
        prompts.filter { prompt in
            let matchesSearch = searchText.isEmpty ||
                prompt.title.localizedCaseInsensitiveContains(searchText) ||
                prompt.content.localizedCaseInsensitiveContains(searchText)
            let matchesTag = selectedTag == nil || prompt.tag == selectedTag
            return matchesSearch && matchesTag
        }
    }

    private var allTags: [(String, String)] {
        var seen = Set<String>()
        var result: [(String, String)] = []
        for prompt in prompts where !prompt.tag.isEmpty && !seen.contains(prompt.tag) {
            seen.insert(prompt.tag)
            result.append((prompt.tag, prompt.tagColor))
        }
        return result
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerBar
                searchBar
                TagFilterBar(
                    tags: allTags,
                    selectedTag: $selectedTag
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                promptList

                bottomToolbar
            }
            .opacity(currentPage.isList ? 1 : 0)

            if case .create = currentPage {
                PromptFormView(prompt: nil) { currentPage = .list }
            }
            if case .edit(let prompt) = currentPage {
                PromptFormView(prompt: prompt) { currentPage = .list }
            }
            if case .settings = currentPage {
                SettingsView { currentPage = .list }
            }
        }
        .frame(width: 420, height: 520)
    }

    private var headerBar: some View {
        HStack {
            Text("PromptBubble")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("/")
                .foregroundStyle(.quaternary)
            Text("提示词管理")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Button("关闭") {
                NSApp.keyWindow?.orderOut(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索提示词", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var promptList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if filteredPrompts.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredPrompts) { prompt in
                        PromptCardView(
                            prompt: prompt,
                            onEdit: { currentPage = .edit(prompt) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty && selectedTag == nil ? "还没有提示词" : "没有匹配的结果")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            if searchText.isEmpty && selectedTag == nil {
                Text("点击下方「+ 创建」添加你的第一条提示词")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var bottomToolbar: some View {
        HStack {
            Button(action: { currentPage = .create }) {
                Label("创建", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Spacer()

            Button(action: { currentPage = .settings }) {
                Label("设置", systemImage: "gearshape")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
