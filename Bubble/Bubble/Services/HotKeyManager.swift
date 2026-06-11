import AppKit
import HotKey

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKey: HotKey?
    var onActivate: (() -> Void)?

    private init() {}

    func register(key: Key, modifiers: NSEvent.ModifierFlags) {
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            self?.onActivate?()
        }
    }

    func unregister() {
        hotKey = nil
    }

    func loadSavedOrDefault() {
        // 不能用 keyCode != 0 判断"是否保存过"：Carbon 键码 0 是字母 A 键
        guard UserDefaults.standard.object(forKey: "hotKeyCarbonCode") != nil else {
            registerDefault()
            return
        }

        let keyCode = UserDefaults.standard.integer(forKey: "hotKeyCarbonCode")
        let modifiers = UserDefaults.standard.integer(forKey: "hotKeyCarbonModifiers")

        if let key = Key(carbonKeyCode: UInt32(keyCode)) {
            let flags = NSEvent.ModifierFlags(carbonFlags: UInt32(modifiers))
            register(key: key, modifiers: flags)
        } else {
            registerDefault()
        }
    }

    func registerDefault() {
        register(key: .space, modifiers: [.command, .shift])
    }

    func save(key: Key, modifiers: NSEvent.ModifierFlags) {
        UserDefaults.standard.set(Int(key.carbonKeyCode), forKey: "hotKeyCarbonCode")
        UserDefaults.standard.set(Int(modifiers.carbonFlags), forKey: "hotKeyCarbonModifiers")
        register(key: key, modifiers: modifiers)
    }

    var currentDisplayString: String {
        guard let hotKey, let key = hotKey.keyCombo.key else { return "⌘⇧Space" }
        return modifierString(hotKey.keyCombo.modifiers) + keyString(key)
    }

    private func modifierString(_ modifiers: NSEvent.ModifierFlags) -> String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option)  { result += "⌥" }
        if modifiers.contains(.shift)   { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result
    }

    private func keyString(_ key: Key) -> String {
        switch key {
        case .space:      return "Space"
        case .return:     return "↩"
        case .delete:     return "⌫"
        case .tab:        return "⇥"
        case .escape:     return "Esc"
        case .upArrow:    return "↑"
        case .downArrow:  return "↓"
        case .leftArrow:  return "←"
        case .rightArrow: return "→"
        default:          return key.description.uppercased()
        }
    }
}
