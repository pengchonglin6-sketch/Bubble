import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panelController: PanelController!
    private var modelContainer: ModelContainer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupModelContainer()
        setupStatusItem()
        setupPanelController()
        setupHotKey()
        applyMenuBarVisibility()
        insertSampleDataIfNeeded()
    }

    private func setupModelContainer() {
        do {
            modelContainer = try ModelContainer(for: Prompt.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: "Bubble")
        button.action = #selector(handleStatusItemClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupPanelController() {
        let contentView = MainPanelView()
            .modelContainer(modelContainer)
        panelController = PanelController(contentView: contentView)
    }

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if panelController.isVisible {
            panelController.close()
        } else {
            guard let button = statusItem.button else { return }
            let buttonFrame = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero
            panelController.show(relativeTo: buttonFrame)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "打开提示词面板", action: #selector(openPanel), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let shortcutItem = NSMenuItem(title: "快捷键: \(HotKeyManager.shared.currentDisplayString)", action: nil, keyEquivalent: "")
        shortcutItem.isEnabled = false
        menu.addItem(shortcutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openPanel() {
        if !panelController.isVisible {
            togglePanel()
        }
    }

    private func setupHotKey() {
        HotKeyManager.shared.onActivate = { [weak self] in
            DispatchQueue.main.async { self?.togglePanel() }
        }
        HotKeyManager.shared.loadSavedOrDefault()
    }

    private func applyMenuBarVisibility() {
        statusItem.isVisible = SettingsManager.shared.showMenuBarIcon
    }

    func setMenuBarVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    private func insertSampleDataIfNeeded() {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<Prompt>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let samples: [(String, String, String, String)] = [
            ("文章润色助手", "请帮我润色以下文案，使其更加出彩流畅。保持原意的基础上，让语言更加优美，逻辑更加清晰。注意维持原文的语气和风格。", "写作", "#4A90D9"),
            ("周报生成器", "根据本周工作内容生成一份结构化周报，重点突出完成的项目、遇到的挑战及下周计划。使用简洁专业的语言。", "办公", "#E8913A"),
            ("邮件回复助手", "请帮我写一封专业的回复邮件，语气要礼貌但不卑微，内容简洁明了。针对对方提出的问题逐一回应。", "办公", "#E8913A"),
            ("头脑风暴助手", "围绕以下话题进行创意头脑风暴，给出至少5个不同角度的创新想法。每个想法附带简短的可行性分析。", "写作", "#4A90D9"),
        ]

        for (i, sample) in samples.enumerated() {
            let prompt = Prompt(
                title: sample.0,
                content: sample.1,
                tag: sample.2,
                tagColor: sample.3,
                sortOrder: i
            )
            context.insert(prompt)
        }

        try? context.save()
    }
}
