import AppKit
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

private enum DropInsertionPosition: Equatable {
    case before
    case after
}

private enum PromptAutoScrollEdge: Equatable {
    case top
    case bottom
}

/// 一次拖拽共用一份状态。拖动预览由列表内部绘制，因此不会离开面板或变成系统半透明预览。
private final class PromptDragSession: ObservableObject {
    @Published private(set) var draggedPromptID: UUID?
    @Published private(set) var targetPromptID: UUID?
    @Published private(set) var insertionPosition: DropInsertionPosition?
    @Published private(set) var autoScrollEdge: PromptAutoScrollEdge?
    @Published private(set) var autoScrollTick = 0
    @Published private(set) var pointerLocation: CGPoint?
    @Published private(set) var previewCenterY: CGFloat?
    @Published private(set) var hasMeaningfulMovement = false
    @Published private(set) var sourceFrame: CGRect?

    private var autoScrollTimer: Timer?
    private var grabOffsetY: CGFloat = 0
    private var localMouseUpMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var pendingMouseUpCleanup: DispatchWorkItem?
    private var sessionWatchdog: DispatchWorkItem?

    func begin(promptID: UUID, sourceFrame: CGRect) {
        guard draggedPromptID == nil else { return }
        draggedPromptID = promptID
        self.sourceFrame = sourceFrame
        previewCenterY = sourceFrame.midY
        pointerLocation = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
        installMouseUpMonitors()
        installSessionWatchdog()
    }

    func updatePointer(
        _ location: CGPoint,
        startLocation: CGPoint,
        viewportHeight: CGFloat
    ) {
        guard let sourceFrame else { return }
        if pointerLocation?.x == sourceFrame.midX,
           pointerLocation?.y == sourceFrame.midY {
            grabOffsetY = startLocation.y - sourceFrame.midY
        }

        pointerLocation = location
        hasMeaningfulMovement = hasMeaningfulMovement
            || hypot(location.x - startLocation.x, location.y - startLocation.y) >= 4
        let halfHeight = max(sourceFrame.height / 2, 28)
        let unclampedCenter = location.y - grabOffsetY
        previewCenterY = min(
            max(unclampedCenter, halfHeight + 4),
            max(halfHeight + 4, viewportHeight - halfHeight - 4)
        )

        // 上下各 64pt 是连续滚动热区；预览会贴住边缘，但始终被列表裁切。
        let hotZoneHeight: CGFloat = 64
        let newEdge: PromptAutoScrollEdge?
        if location.y <= hotZoneHeight {
            newEdge = .top
        } else if viewportHeight > 0 && location.y >= viewportHeight - hotZoneHeight {
            newEdge = .bottom
        } else {
            newEdge = nil
        }
        setAutoScrollEdge(newEdge)
    }

    func updateTarget(promptID: UUID?, insertionPosition: DropInsertionPosition?) {
        targetPromptID = promptID
        self.insertionPosition = insertionPosition
    }

    func end() {
        draggedPromptID = nil
        targetPromptID = nil
        insertionPosition = nil
        pointerLocation = nil
        previewCenterY = nil
        hasMeaningfulMovement = false
        sourceFrame = nil
        grabOffsetY = 0
        setAutoScrollEdge(nil)
        pendingMouseUpCleanup?.cancel()
        pendingMouseUpCleanup = nil
        sessionWatchdog?.cancel()
        sessionWatchdog = nil
        removeMouseUpMonitors()
    }

    func stopAutoScroll() {
        setAutoScrollEdge(nil)
    }

    private func setAutoScrollEdge(_ edge: PromptAutoScrollEdge?) {
        guard autoScrollEdge != edge else { return }
        autoScrollEdge = edge
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil

        guard edge != nil else { return }
        let timer = Timer(timeInterval: 0.10, repeats: true) { [weak self] _ in
            self?.autoScrollTick += 1
        }
        RunLoop.main.add(timer, forMode: .common)
        autoScrollTimer = timer
    }

    private func installMouseUpMonitors() {
        removeMouseUpMonitors()
        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.scheduleMouseUpCleanup()
            return event
        }
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            DispatchQueue.main.async {
                self?.scheduleMouseUpCleanup()
            }
        }
    }

    private func scheduleMouseUpCleanup() {
        pendingMouseUpCleanup?.cancel()
        let cleanup = DispatchWorkItem { [weak self] in
            guard self?.draggedPromptID != nil else { return }
            self?.end()
        }
        pendingMouseUpCleanup = cleanup
        // 先让 SwiftUI 的 onEnded 提交排序；如果它因越窗而丢失，这里负责取消残留会话。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: cleanup)
    }

    private func installSessionWatchdog() {
        sessionWatchdog?.cancel()
        let watchdog = DispatchWorkItem { [weak self] in
            guard self?.draggedPromptID != nil else { return }
            self?.end()
        }
        sessionWatchdog = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: watchdog)
    }

    private func removeMouseUpMonitors() {
        if let localMouseUpMonitor {
            NSEvent.removeMonitor(localMouseUpMonitor)
            self.localMouseUpMonitor = nil
        }
        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
            self.globalMouseUpMonitor = nil
        }
    }

    deinit {
        autoScrollTimer?.invalidate()
        if let localMouseUpMonitor { NSEvent.removeMonitor(localMouseUpMonitor) }
        if let globalMouseUpMonitor { NSEvent.removeMonitor(globalMouseUpMonitor) }
    }
}

struct MainPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Prompt.sortOrder) private var prompts: [Prompt]
    let onRequestClose: () -> Void

    @State private var searchText = ""
    @State private var selectedTag: String? = nil
    @StateObject private var dragSession = PromptDragSession()
    @State private var promptFrames: [UUID: CGRect] = [:]
    @State private var reorderErrorMessage: String? = nil
    // 调试/截图用：--page=create 直接打开新建表单
    @State private var currentPage: PanelPage =
        CommandLine.arguments.contains("--page=create") ? .create : .list

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
        .background(ColoredGlassBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
        )
        .preferredColorScheme(.light)
        .alert("排序保存失败", isPresented: Binding(
            get: { reorderErrorMessage != nil },
            set: { if !$0 { reorderErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(reorderErrorMessage ?? "")
        }
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
                onRequestClose()
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
        GeometryReader { viewport in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    // 拖动期间保持所有卡片视图存活；否则源卡片滚出可视区时系统会取消它的手势。
                    VStack(spacing: 6) {
                        if filteredPrompts.isEmpty {
                            emptyState
                        } else {
                            ForEach(filteredPrompts) { prompt in
                                ReorderablePromptCard(
                                    prompt: prompt,
                                    dragSession: dragSession,
                                    onDragBegan: {
                                        beginDragging(prompt)
                                    },
                                    onDragChanged: { value in
                                        updateDragging(
                                            prompt,
                                            value: value,
                                            viewportHeight: viewport.size.height
                                        )
                                    },
                                    onDragEnded: {
                                        finishDragging()
                                    },
                                    onEdit: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            currentPage = .edit(prompt)
                                        }
                                    },
                                    onCopyComplete: onRequestClose
                                )
                                .id(prompt.id)
                                .background {
                                    GeometryReader { geometry in
                                        Color.clear.preference(
                                            key: PromptCardFramePreferenceKey.self,
                                            value: [
                                                prompt.id: geometry.frame(in: .named("promptListViewport"))
                                            ]
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .scrollDisabled(dragSession.draggedPromptID != nil)
                .coordinateSpace(name: "promptListViewport")
                .overlay(alignment: dragSession.autoScrollEdge == .top ? .top : .bottom) {
                    if dragSession.autoScrollEdge != nil {
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.16), .clear],
                            startPoint: dragSession.autoScrollEdge == .top ? .top : .bottom,
                            endPoint: dragSession.autoScrollEdge == .top ? .bottom : .top
                        )
                        .frame(height: 48)
                        .allowsHitTesting(false)
                    }
                }
                .overlay {
                    // 尺寸直接来自当前列表容器；尺寸尚未建立时不绘制，绝不使用 0 宽度回退值。
                    if viewport.size.width > 24,
                       viewport.size.height > 0,
                       let draggedPrompt,
                       let previewCenterY = dragSession.previewCenterY,
                       let sourceFrame = dragSession.sourceFrame {
                        PromptDragPreview(prompt: draggedPrompt)
                            .frame(
                                width: viewport.size.width - 24,
                                height: sourceFrame.height
                            )
                            .position(
                                x: viewport.size.width / 2,
                                y: previewCenterY
                            )
                            .allowsHitTesting(false)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .animation(
                    .spring(response: 0.20, dampingFraction: 0.78),
                    value: dragSession.draggedPromptID
                )
                // 对滚动内容与拖动预览统一裁切；避免 mask 触发整列离屏合成。
                .clipped(antialiased: false)
                .onPreferenceChange(PromptCardFramePreferenceKey.self) { promptFrames = $0 }
                .onChange(of: dragSession.autoScrollTick) { _, _ in
                    guard let edge = dragSession.autoScrollEdge else { return }
                    autoScroll(
                        edge: edge,
                        using: scrollProxy,
                        viewportHeight: viewport.size.height
                    )
                }
                .onDisappear { dragSession.end() }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var draggedPrompt: Prompt? {
        guard let draggedPromptID = dragSession.draggedPromptID else { return nil }
        return prompts.first { $0.id == draggedPromptID }
    }

    private func beginDragging(_ prompt: Prompt) {
        guard let sourceFrame = promptFrames[prompt.id], sourceFrame != .zero else { return }
        dragSession.begin(promptID: prompt.id, sourceFrame: sourceFrame)
    }

    private func updateDragging(
        _ prompt: Prompt,
        value: DragGesture.Value,
        viewportHeight: CGFloat
    ) {
        guard dragSession.draggedPromptID == prompt.id,
              dragSession.sourceFrame != nil,
              viewportHeight > 0 else { return }

        dragSession.updatePointer(
            value.location,
            startLocation: value.startLocation,
            viewportHeight: viewportHeight
        )
        updateDragTarget(at: value.location.y, viewportHeight: viewportHeight)
    }

    private func updateDragTarget(at pointerY: CGFloat, viewportHeight: CGFloat) {
        guard let sourceID = dragSession.draggedPromptID else { return }
        let constrainedY = min(max(pointerY, 0), viewportHeight)
        let candidates = filteredPrompts.compactMap { prompt -> (Prompt, CGRect)? in
            guard prompt.id != sourceID,
                  let frame = promptFrames[prompt.id],
                  frame.maxY > 0,
                  frame.minY < viewportHeight else { return nil }
            return (prompt, frame)
        }
        guard let nearest = candidates.min(by: {
            abs($0.1.midY - constrainedY) < abs($1.1.midY - constrainedY)
        }) else {
            dragSession.updateTarget(promptID: nil, insertionPosition: nil)
            return
        }

        dragSession.updateTarget(
            promptID: nearest.0.id,
            insertionPosition: constrainedY < nearest.1.midY ? .before : .after
        )
    }

    private func finishDragging() {
        defer { dragSession.end() }
        guard dragSession.hasMeaningfulMovement,
              let sourceID = dragSession.draggedPromptID,
              let targetID = dragSession.targetPromptID,
              let insertionPosition = dragSession.insertionPosition else { return }
        _ = movePrompt(
            sourceID,
            relativeTo: targetID,
            placeAfterTarget: insertionPosition == .after
        )
    }

    private func autoScroll(
        edge: PromptAutoScrollEdge,
        using proxy: ScrollViewProxy,
        viewportHeight: CGFloat
    ) {
        if let pointerY = dragSession.pointerLocation?.y {
            updateDragTarget(at: pointerY, viewportHeight: viewportHeight)
        }
        let visibleIndices = filteredPrompts.indices.filter { index in
            guard let frame = promptFrames[filteredPrompts[index].id] else { return false }
            return frame.maxY > 0 && frame.minY < viewportHeight
        }
        guard let firstVisible = visibleIndices.first,
              let lastVisible = visibleIndices.last else {
            dragSession.stopAutoScroll()
            return
        }

        let targetIndex: Int
        let anchor: UnitPoint
        switch edge {
        case .top:
            guard firstVisible > 0 else {
                dragSession.stopAutoScroll()
                return
            }
            targetIndex = firstVisible - 1
            anchor = .top
        case .bottom:
            guard lastVisible < filteredPrompts.count - 1 else {
                dragSession.stopAutoScroll()
                return
            }
            targetIndex = lastVisible + 1
            anchor = .bottom
        }

        // 不排队动画：每次计时只完成一次确定的滚动，避免拖久后主线程积压布局任务。
        proxy.scrollTo(filteredPrompts[targetIndex].id, anchor: anchor)
    }

    /// 将拖动的卡片插入目标卡片之前或之后，并把顺序写回 SwiftData。
    /// 只更新现有对象的 sortOrder，不删除、重建或替换任何提示词。
    private func movePrompt(
        _ sourceID: UUID,
        relativeTo targetID: UUID,
        placeAfterTarget: Bool
    ) -> Bool {
        guard sourceID != targetID,
              let sourceIndex = prompts.firstIndex(where: { $0.id == sourceID })
        else { return false }

        var reorderedPrompts = prompts
        let movingPrompt = reorderedPrompts.remove(at: sourceIndex)

        guard let targetIndex = reorderedPrompts.firstIndex(where: { $0.id == targetID }) else {
            return false
        }

        let insertionIndex = targetIndex + (placeAfterTarget ? 1 : 0)
        reorderedPrompts.insert(movingPrompt, at: insertionIndex)

        withAnimation(.easeInOut(duration: 0.18)) {
            for (index, prompt) in reorderedPrompts.enumerated() {
                prompt.sortOrder = index
            }
        }

        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            reorderErrorMessage = error.localizedDescription
            return false
        }
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

/// 只在列表内部工作的按住拖动手势；系统不会再生成能飞出窗口的拖放预览。
private struct ReorderablePromptCard: View {
    let prompt: Prompt
    @ObservedObject var dragSession: PromptDragSession
    var onDragBegan: () -> Void
    var onDragChanged: (DragGesture.Value) -> Void
    var onDragEnded: () -> Void
    var onEdit: () -> Void
    var onCopyComplete: () -> Void

    private var visibleInsertionPosition: DropInsertionPosition? {
        guard dragSession.draggedPromptID != nil,
              dragSession.targetPromptID == prompt.id else { return nil }
        return dragSession.insertionPosition
    }

    private var isBeingDragged: Bool {
        dragSession.draggedPromptID == prompt.id
    }

    var body: some View {
        PromptCardView(
            prompt: prompt,
            onEdit: onEdit,
            onCopyComplete: onCopyComplete
        )
        .overlay(
            alignment: visibleInsertionPosition == .before ? .top : .bottom
        ) {
            if let visibleInsertionPosition {
                HStack(spacing: 0) {
                    Circle()
                        .frame(width: 7, height: 7)
                    Rectangle()
                        .frame(height: 3)
                    Circle()
                        .frame(width: 7, height: 7)
                }
                .foregroundStyle(Color.accentColor)
                .shadow(color: Color.accentColor.opacity(0.42), radius: 3)
                .padding(.horizontal, 3)
                .offset(y: visibleInsertionPosition == .before ? -4 : 4)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        // 原位置保留一个明确的占位；不透明预览由列表最上层单独绘制。
        .scaleEffect(isBeingDragged ? 0.80 : 1)
        .opacity(isBeingDragged ? 0.24 : 1)
        .animation(
            .spring(response: 0.20, dampingFraction: 0.78),
            value: isBeingDragged
        )
        .animation(.easeInOut(duration: 0.12), value: visibleInsertionPosition)
        .simultaneousGesture(reorderGesture)
        .help("按住并拖动可调整顺序")
    }

    private var reorderGesture: some Gesture {
        DragGesture(
            minimumDistance: 3,
            coordinateSpace: .named("promptListViewport")
        )
            .onChanged { value in
                onDragBegan()
                onDragChanged(value)
            }
            .onEnded { value in
                onDragChanged(value)
                onDragEnded()
            }
    }
}

private struct PromptDragPreview: View {
    let prompt: Prompt

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: prompt.tagColor))
                .frame(width: 4)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(prompt.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if !prompt.tag.isEmpty {
                        Text(prompt.tag)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(hex: prompt.tagColor).opacity(0.28), in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color(hex: prompt.tagColor).opacity(0.42), lineWidth: 1)
                            )
                            .foregroundStyle(Color.primary.opacity(0.78))
                    }
                }

                Text(prompt.content)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.primary.opacity(0.66))
                    .lineLimit(2)
            }
            .padding(.leading, 10)
            .padding(.vertical, 10)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color(red: 0.955, green: 0.965, blue: 0.982))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(Color.white.opacity(0.95), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
        // 长按后拖动中的实体卡片缩小到 80%，松手时随会话消失并由原卡片恢复到 1.0。
        .scaleEffect(0.80)
    }
}

private struct PromptCardFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

/// 不依赖窗口后方内容的实色玻璃底板。
/// 多层柔和渐变和细小高光颗粒让它保留“玻璃照片”的质感，但完全不透明。
private struct ColoredGlassBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.93, green: 0.94, blue: 0.96)

            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.97, blue: 0.98),
                    Color(red: 0.90, green: 0.93, blue: 0.97),
                    Color(red: 0.95, green: 0.91, blue: 0.94),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.80, green: 0.90, blue: 1.0).opacity(0.44),
                    .clear,
                ],
                center: UnitPoint(x: 0.08, y: 0.04),
                startRadius: 0,
                endRadius: 300
            )

            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.82, blue: 0.90).opacity(0.28),
                    .clear,
                ],
                center: UnitPoint(x: 0.92, y: 0.88),
                startRadius: 0,
                endRadius: 270
            )

            Canvas { context, size in
                for index in 0..<96 {
                    let x = CGFloat((index * 47) % 101) / 100 * size.width
                    let y = CGFloat((index * 71) % 103) / 102 * size.height
                    let diameter = CGFloat(1 + (index % 3)) * 0.55
                    let speck = CGRect(
                        x: x,
                        y: y,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(
                        Path(ellipseIn: speck),
                        with: .color(.white.opacity(index.isMultiple(of: 4) ? 0.28 : 0.12))
                    )
                }
            }
            .blendMode(.softLight)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.38),
                    Color.white.opacity(0.05),
                    Color.white.opacity(0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.34))
                .frame(height: 1)
        }
    }
}
