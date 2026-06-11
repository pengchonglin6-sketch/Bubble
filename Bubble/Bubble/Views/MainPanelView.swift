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
            // Main list layer
            VStack(spacing: 0) {
                headerBar
                searchBar
                TagFilterBar(tags: allTags, selectedTag: $selectedTag)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                promptList
                Divider()
                bottomToolbar
            }
            .opacity(currentPage.isList ? 1 : 0)
            .animation(.easeInOut(duration: 0.18), value: currentPage.isList)

            // Overlay pages with slide-up transition
            Group {
                if case .create = currentPage {
                    PromptFormView(prompt: nil) { withAnimation(.easeInOut(duration: 0.2)) { currentPage = .list } }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if case .edit(let prompt) = currentPage {
                    PromptFormView(prompt: prompt) { withAnimation(.easeInOut(duration: 0.2)) { currentPage = .list } }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if case .settings = currentPage {
                    SettingsView { withAnimation(.easeInOut(duration: 0.2)) { currentPage = .list } }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: currentPage.isList)
        }
        .frame(width: 420, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var headerBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.blue)
            Text("PromptBubble")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.8))
            Spacer()
            Button {
                NSApp.keyWindow?.close()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.tertiary)
                .font(.system(size: 13))
            TextField("搜索提示词", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var promptList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if filteredPrompts.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredPrompts) { prompt in
                        PromptCardView(
                            prompt: prompt,
                            onEdit: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentPage = .edit(prompt)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty && selectedTag == nil
                  ? "bubble.left.and.text.bubble.right"
                  : "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
                .padding(.top, 40)
            Text(searchText.isEmpty && selectedTag == nil ? "还没有提示词" : "没有匹配的结果")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            if searchText.isEmpty && selectedTag == nil {
                Text("点击「+ 创建」添加第一条提示词")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var bottomToolbar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { currentPage = .create }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("创建")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { currentPage = .settings }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
