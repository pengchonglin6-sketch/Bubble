# Bubble — macOS 菜单栏提示词管理器 — CLAUDE.md

## 项目简述

Bubble 是一款 macOS 菜单栏应用，通过状态栏图标或全局快捷键唤起实色玻璃风格面板，用户可以快速搜索、创建、编辑、分类、排序和复制自己积累的提示词库。面板可自由移动，首次默认位于屏幕右上方，并会轻微吸附到不含菜单栏与 Dock 的可用屏幕边缘。

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
    var content: String         // 提示词内容（max 5000 字符）
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
| 菜单栏 NSStatusItem + 左键弹窗 | 已完成 | Phase 1 |
| 自定义 NSPanel 实色玻璃面板 | 已完成 | Phase 1 / 6 |
| 提示词列表（搜索 + 标签筛选） | 已完成 | Phase 2 |
| 新建/编辑表单 + CRUD（5000 字符上限） | 已完成 | Phase 3 |
| 一键复制 + 对勾反馈 + 自动收起 | 已完成 | Phase 2 / 6 |
| 全局快捷键（默认 Cmd+Shift+Space） | 已完成 | Phase 4 |
| 快捷键自定义录制 | 已完成 | Phase 4 |
| 快捷键冲突检测 | 待完善 | Phase 4 |
| 设置面板（快捷键/开机启动/菜单栏） | 已完成 | Phase 5 |
| 面板自由移动、右上默认位置、屏幕边缘轻吸附 | 已完成 | Phase 7 |
| 卡片即时拖动排序、80% 预览、插入线、边缘自动滚动 | 已完成 | Phase 7 |
| App 图标资源 | 待完善 | Phase 6 |

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
│   │   └── SettingsManager.swift    // 设置持久化
│   ├── Helpers/
│   │   └── PanelController.swift    // NSPanel 控制
│   └── Resources/Assets.xcassets
├── CLAUDE.md (本文件)
├── README.md
└── tasks/
    ├── plan.md                      // 7 Phase 详细计划
    └── todo.md                      // 当前实施状态与验收清单
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
- 原生 SwiftUI + AppKit 的窗口移动、吸附和视觉效果更贴合 macOS，Electron 需要额外适配
- 体积小（<10MB vs >100MB）
- 与 macOS 系统深度集成（菜单栏、快捷键权限）

---

## 红线与约定

1. **无第三方 UI 框架**：不用 Alamofire、Apollo 等，只用原生 URLSession / SwiftData
2. **无依赖地狱**：SPM 依赖仅允许 HotKey，其他基础能力用原生 API
3. **实色玻璃风格必须保持**：窗口边缘可以透明以实现圆角，但内容区域必须不透明，不能采样或透出后方窗口
4. **提示词数据安全**：排序只能更新现有对象的 `sortOrder`，不可为了重排而删除或重建提示词
5. **中文 UI 完全支持**：所有文案、标签都要支持中文
6. **不做悬浮球**：纯菜单栏 app，无浮窗、无外挂式控件

---

## 任务与计划

详见 `tasks/plan.md`（7 Phase）和 `tasks/todo.md`（带验收标准的当前实施状态）。

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

全局快捷键由 HotKey（Carbon `RegisterEventHotKey`）注册，不依赖辅助功能权限。

### 调试
- 全局快捷键注册日志：查看 Console.app（应用窗口 > Bubble）
- SwiftData 查询日志：在 scheme 中添加 `-com.apple.CoreData.SQLDebug 1`

---

## 完成阶段标记

- [x] Phase 1: 项目骨架 + 菜单栏基础 (Checkpoint 1)
- [x] Phase 2: 数据层 + 列表 (Checkpoint 2)
- [x] Phase 3: CRUD + 自定义标签 (Checkpoint 3)
- [~] Phase 4: 全局快捷键 (可用；冲突检测待完善)
- [x] Phase 5: 设置面板 (Checkpoint 5)
- [~] Phase 6: UI 打磨与收尾 (主要交互已完成；App 图标待完善)
- [x] Phase 7: 面板移动吸附 + 卡片拖动排序
