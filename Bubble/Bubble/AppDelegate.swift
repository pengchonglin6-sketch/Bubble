import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panelController: PanelController!
    private var modelContainer: ModelContainer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted tests must never open or modify the user's real library.
        if NSClassFromString("XCTestCase") != nil { return }

        setupModelContainer()
        setupStatusItem()
        setupPanelController()
        setupHotKey()
        applyMenuBarVisibility()
        importDefaultPromptsIfNeeded()

        // 调试/截图用：open Bubble.app --args --show-panel
        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.togglePanel()
            }
        }
    }

    private func setupModelContainer() {
        // 必须显式指定专属路径：非沙盒应用的 SwiftData 默认存储是共享的
        // ~/Library/Application Support/default.store，会被系统进程
        // （如 icloudmailagent）的 schema 迁移破坏，导致数据全部丢失。
        let storeDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Bubble", isDirectory: true)
        let storeURL = storeDirectory.appendingPathComponent("Bubble.store")

        do {
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(url: storeURL)
            modelContainer = try ModelContainer(for: Prompt.self, configurations: configuration)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "无法打开提示词数据库"
            alert.informativeText = "数据库初始化失败：\(error.localizedDescription)\n\n数据文件位于：\(storeURL.path)\n你可以备份后删除该文件再重新启动应用。"
            alert.addButton(withTitle: "退出")
            alert.runModal()
            NSApp.terminate(nil)
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
        let contentView = MainPanelView { [weak self] in
            self?.panelController?.close()
        }
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

    private func importDefaultPromptsIfNeeded() {
        do {
            try DefaultPromptLibrary.importIfNeeded(into: modelContainer.mainContext)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "内置提示词导入失败"
            alert.informativeText = "现有提示词仍可使用，下次启动时会重试。\n\n\(error.localizedDescription)"
            alert.addButton(withTitle: "继续")
            alert.runModal()
        }
    }
}
