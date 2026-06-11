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
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .utilityWindow

        let visualEffect = NSVisualEffectView(frame: contentRect)
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true

        contentView = visualEffect
    }
}

final class PanelController {
    private let panel: FloatingPanel
    private let hostingView: NSHostingView<AnyView>
    private var clickMonitor: Any?

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
    }

    func show(relativeTo statusItemFrame: NSRect) {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero

        var panelX = statusItemFrame.midX - Self.panelWidth / 2
        var panelY = statusItemFrame.minY - Self.panelHeight - 4

        if statusItemFrame == .zero {
            panelX = screenFrame.midX - Self.panelWidth / 2
            panelY = screenFrame.maxY - Self.panelHeight - 40
        }

        panelX = max(screenFrame.minX + 8, min(panelX, screenFrame.maxX - Self.panelWidth - 8))

        let origin = NSPoint(x: panelX, y: panelY)
        panel.setFrameOrigin(origin)
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
