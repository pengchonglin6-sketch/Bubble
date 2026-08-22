import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .popUpMenu
        // 圆角窗口本身仍需透明边缘，但内容区域使用固定实色，不再采样后方窗口。
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .utilityWindow

        let solidContainer = NSView(frame: contentRect)
        solidContainer.wantsLayer = true
        solidContainer.layer?.backgroundColor = NSColor(
            red: 0.93,
            green: 0.94,
            blue: 0.96,
            alpha: 1
        ).cgColor
        solidContainer.layer?.cornerRadius = 16
        solidContainer.layer?.masksToBounds = true

        contentView = solidContainer
    }
}

/// 覆盖在面板标题区域上的透明拖动层。
/// 只占用标题左侧，保留右上角关闭按钮的点击区域，也不会抢占卡片拖拽手势。
private final class PanelDragRegionView: NSView {
    var adjustedOrigin: ((NSPoint, NSSize) -> NSPoint)?
    var onDragEnded: (() -> Void)?
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragStartMouseLocation = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let dragStartMouseLocation,
              let dragStartWindowOrigin else { return }

        let mouseLocation = NSEvent.mouseLocation
        let proposedOrigin = NSPoint(
            x: dragStartWindowOrigin.x + mouseLocation.x - dragStartMouseLocation.x,
            y: dragStartWindowOrigin.y + mouseLocation.y - dragStartMouseLocation.y
        )
        let origin = adjustedOrigin?(proposedOrigin, window.frame.size) ?? proposedOrigin
        window.setFrameOrigin(origin)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouseLocation = nil
        dragStartWindowOrigin = nil
        onDragEnded?()
    }
}

final class PanelController {
    private let panel: FloatingPanel
    private let hostingView: NSHostingView<AnyView>
    private var clickMonitor: Any?
    private var hasPositionedPanel = false

    static let panelWidth: CGFloat = 420
    static let panelHeight: CGFloat = 520

    var isVisible: Bool { panel.isVisible }

    init<Content: View>(contentView: Content) {
        let rect = NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight)
        panel = FloatingPanel(contentRect: rect)

        hostingView = NSHostingView(
            rootView: AnyView(
                contentView
                    .frame(width: Self.panelWidth, height: Self.panelHeight)
                    .background(.clear)
            )
        )
        hostingView.frame = rect

        panel.contentView?.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
        ])

        // SwiftUI 卡片本身需要接收拖拽事件来排序，所以窗口移动只放在标题区域。
        let dragRegion = PanelDragRegionView()
        dragRegion.adjustedOrigin = { [weak self] proposedOrigin, panelSize in
            self?.magnetizedOrigin(
                from: proposedOrigin,
                panelSize: panelSize,
                snapDistance: 18
            ) ?? proposedOrigin
        }
        dragRegion.onDragEnded = { [weak self] in
            self?.snapPanelToNearestScreenEdge()
        }
        dragRegion.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(dragRegion, positioned: .above, relativeTo: hostingView)
        NSLayoutConstraint.activate([
            dragRegion.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            dragRegion.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            dragRegion.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -48),
            dragRegion.heightAnchor.constraint(equalToConstant: 46),
        ])
    }

    func show(relativeTo statusItemFrame: NSRect) {
        if !hasPositionedPanel {
            let screen = screenContaining(statusItemFrame) ?? NSScreen.main ?? NSScreen.screens.first
            let screenFrame = screen?.visibleFrame ?? .zero
            let origin = NSPoint(
                x: screenFrame.maxX - Self.panelWidth - 16,
                y: screenFrame.maxY - Self.panelHeight - 12
            )
            panel.setFrameOrigin(origin)
            hasPositionedPanel = true
        }
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }

        startClickMonitor()
    }

    private func screenContaining(_ frame: NSRect) -> NSScreen? {
        guard frame != .zero else { return nil }
        return NSScreen.screens.first { $0.frame.intersects(frame) }
    }

    /// 松手后再以稍宽的范围补一次吸附。
    /// 顶部使用 visibleFrame.maxY，边界正是菜单栏下方那条线。
    private func snapPanelToNearestScreenEdge() {
        let currentFrame = panel.frame
        // 28pt 足以让吸附被感知，但不会在离边缘较远时主动拉走窗口。
        let targetOrigin = magnetizedOrigin(
            from: currentFrame.origin,
            panelSize: currentFrame.size,
            snapDistance: 28
        )

        guard targetOrigin != currentFrame.origin else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrameOrigin(targetOrigin)
        }
    }

    /// 拖动中使用 18pt 的轻磁力，松手时使用 28pt 收尾。
    /// visibleFrame 已排除菜单栏与 Dock，所以顶部永远不会盖住菜单栏。
    private func magnetizedOrigin(
        from proposedOrigin: NSPoint,
        panelSize: NSSize,
        snapDistance: CGFloat
    ) -> NSPoint {
        let proposedFrame = NSRect(origin: proposedOrigin, size: panelSize)
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.screens.max { first, second in
                first.visibleFrame.intersection(proposedFrame).area
                    < second.visibleFrame.intersection(proposedFrame).area
            }
        guard let visibleFrame = targetScreen?.visibleFrame else { return proposedOrigin }

        var origin = proposedOrigin
        if abs(proposedFrame.minX - visibleFrame.minX) <= snapDistance {
            origin.x = visibleFrame.minX
        } else if abs(proposedFrame.maxX - visibleFrame.maxX) <= snapDistance {
            origin.x = visibleFrame.maxX - panelSize.width
        }

        if abs(proposedFrame.minY - visibleFrame.minY) <= snapDistance {
            origin.y = visibleFrame.minY
        } else if abs(proposedFrame.maxY - visibleFrame.maxY) <= snapDistance {
            origin.y = visibleFrame.maxY - panelSize.height
        }
        return origin
    }

    func close() {
        stopClickMonitor()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1.0
        })
    }

    private func startClickMonitor() {
        stopClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            self.close()
        }
    }

    private func stopClickMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }
}

private extension NSRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}
