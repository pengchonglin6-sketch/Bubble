# Bubble — macOS 菜单栏提示词管理器 — CLAUDE.md

## 项目简述

Bubble 是一款 macOS 菜单栏应用，通过状态栏图标或全局快捷键唤起磨砂玻璃风格面板，用户可以快速搜索、创建、编辑、分类和复制自己积累的提示词库。

**项目目录：** `/Users/pengchonglin/Desktop/vibe coding/提示词小弹窗/Bubble/`

---

## 技术栈与约定

| 层级 | 技术 | 说明 |
|------|------|------|
| UI 框架 | SwiftUI + AppKit | SwiftUI 声明式 UI，AppKit 处理 NSStatusItem + NSPanel |
| 数据持久化 | SwiftData | macOS 14+ 原生 ORM，自动 migration |
| 全局快捷键 | HotKey (SPM) | 基于 Carbon API，支持自定义录制 |
| 开机启动 | SMAppService | macOS 13+ 官方 API |
| 剪贴板 | NSPasteboard | 原生 API |
| 最低系统 | macOS 14.0 (Sonoma) | SwiftData 最低要求 |

---

## 数据模型

```swift
@Model
class Prompt {
    var id: UUID
    var title: String           // 标题
    var content: String         // 提示词内容（max 2000 字）
    var tag: String             // 分类标签名
    var tagColor: String        // 标签颜色（hex）
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int          // 排序顺序
}

// UserDefaults 存储
AppSettings:
  - globalShortcut: KeyCombo  (默认 Cmd+Shift+Space)
  - launchAtLogin: Bool       (开机启动)
  - showMenuBarIcon: Bool     (菜单栏入口可见性)
```

---

## 完整特性清单

| 功能 | 状态 | 实施阶段 |
|------|------|----------|
| 菜单栏 NSStatusItem + 左键弹窗 | 计划中 | Phase 1 |
| NSPanel 磨砂玻璃面板 | 计划中 | Phase 1 |
| 提示词列表（搜索+标签筛选） | 计划中 | Phase 2 |
| 新建/编辑表单 + CRUD | 计划中 | Phase 3 |
| 一键复制功能 | 计划中 | Phase 2 |
| 全局快捷键（默认 Cmd+Shift+Space） | 计划中 | Phase 4 |
| 快捷键自定义录制 + 冲突检测 | 计划中 | Phase 4 |
| 设置面板（快捷键/开机启动/菜单栏） | 计划中 | Phase 5 |
| UI 打磨（磨砂/动画/边缘情况） | 计划中 | Phase 6 |

---

## 项目结构（预期）

```
Bubble/
├── Bubble.xcodeproj
├── Bubble/
│   ├── BubbleApp.swift              // App 入口
│   ├── AppDelegate.swift            // NSStatusItem + NSPanel 管理
│   ├── Models/
│   │   └── Prompt.swift             // SwiftData Model
│   ├── Views/
│   │   ├── MainPanelView.swift      // 主面板
│   │   ├── PromptCardView.swift     // 卡片组件
│   │   ├── TagFilterBar.swift       // 标签栏
│   │   ├── PromptFormView.swift     // 表单
│   │   └── SettingsView.swift       // 设置面板
│   ├── Services/
│   │   ├── HotKeyManager.swift      // 快捷键管理
│   │   ├── SettingsManager.swift    // 设置持久化
│   │   └── ClipboardManager.swift   // 剪贴板
│   ├── Helpers/
│   │   └── PanelController.swift    // NSPanel 控制
│   └── Resources/Assets.xcassets
├── CLAUDE.md (本文件)
├── README.md
└── tasks/
    ├── plan.md                      // 6 Phase 详细计划
    └── todo.md                      // 18 个任务清单
```

---

## 关键决策

### 为什么选 SwiftData 而不是 CoreData？
- SwiftData 是 Apple 在 macOS 14+ 推荐的原生方案
- 自动 migration，无需写迁移代码
- 代码量少，与 SwiftUI 集成无缝

### 为什么用 HotKey 库而不是自己写全局快捷键？
- 全局快捷键本身很复杂，涉及 Carbon API + 权限处理
- HotKey 库成熟稳定，社区维护好
- 省时省力，聚焦产品功能而非基础设施

### 为什么选 SMAppService 而不是 LaunchAgent？
- SMAppService 是 macOS 13+ 的官方推荐
- 不需要额外的 Helper App
- 权限管理更简单

### 为什么没有选择 Electron / Tauri？
- 原生 SwiftUI 磨砂效果最佳，Electron 需要 hack
- 体积小（<10MB vs >100MB）
- 与 macOS 系统深度集成（菜单栏、快捷键权限）

---

## 红线与约定

1. **无第三方 UI 框架**：不用 Alamofire、Apollo 等，只用原生 URLSession / SwiftData
2. **无依赖地狱**：SPM 依赖仅允许 HotKey，其他基础能力用原生 API
3. **磨砂玻璃风格必须保持**：不动画式弹窗可以，但底色必须是 NSVisualEffectView
4. **快捷键权限**：首次启动弹窗引导用户开启"辅助功能"权限，自动重试机制
5. **中文 UI 完全支持**：所有文案、标签都要支持中文
6. **不做悬浮球**：纯菜单栏 app，无浮窗、无外挂式控件

---

## 任务与计划

详见 `tasks/plan.md`（6 Phase，18 个垂直切片任务）和 `tasks/todo.md`（带验收标准的任务清单）。

**预估周期：** 3-5 天（熟练开发者）

---

## 资源文件

- **UI 原型图**：`../UI/` 目录，4 张设计稿
  - 图1：主面板（搜索+标签+列表）
  - 图2：新建/编辑表单
  - 图3：设置面板
  - 图4：菜单栏图标+右键菜单

---

## 本地开发

### 环境要求
- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Swift 5.9+

### 快速开始
```bash
cd /Users/pengchonglin/Desktop/vibe\ coding/提示词小弹窗/Bubble
xcode Bubble.xcodeproj  # 或在 Finder 中双击打开
```

按 Cmd+B 编译，Cmd+R 运行。

首次运行会提示"辅助功能"权限，点击"系统偏好设置"并授予权限。

### 调试
- 全局快捷键注册日志：查看 Console.app（应用窗口 > Bubble）
- SwiftData 查询日志：在 scheme 中添加 `-com.apple.CoreData.SQLDebug 1`

---

## 完成阶段标记

- [ ] Phase 1: 项目骨架 + 菜单栏基础 (Checkpoint 1)
- [ ] Phase 2: 数据层 + 列表 (Checkpoint 2)
- [ ] Phase 3: CRUD + 自定义标签 (Checkpoint 3)
- [ ] Phase 4: 全局快捷键 (Checkpoint 4)
- [ ] Phase 5: 设置面板 (Checkpoint 5)
- [ ] Phase 6: UI 打磨与收尾 (Checkpoint 6)
