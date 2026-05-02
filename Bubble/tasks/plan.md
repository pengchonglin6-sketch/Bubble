# Bubble — macOS 提示词管理工具实施计划

## 项目概述

Bubble 是一款 macOS 菜单栏提示词管理工具，用户通过状态栏图标或全局快捷键唤起磨砂玻璃风格面板，对提示词进行增删改查、分类筛选、一键复制。

## 技术栈

| 层级 | 技术选型 | 说明 |
|------|----------|------|
| UI 框架 | SwiftUI | 声明式 UI，原生磨砂效果 `.ultraThinMaterial` |
| 系统集成 | AppKit | NSStatusItem(菜单栏)、NSPanel(弹窗面板) |
| 数据持久化 | SwiftData | macOS 14+ 原生 ORM，自动迁移 |
| 全局快捷键 | HotKey (开源库) | 基于 Carbon API，支持自定义录制 |
| 开机启动 | ServiceManagement | `SMAppService.mainApp` (macOS 13+) |
| 最低支持 | macOS 14.0 (Sonoma) | SwiftData 最低要求 |

## 依赖关系图

```
┌─────────────────────────────────────────────────┐
│                  BubbleApp (入口)                 │
│            NSStatusItem + NSPanel                │
└──────────┬──────────────┬───────────────┬────────┘
           │              │               │
    ┌──────▼──────┐ ┌─────▼──────┐ ┌──────▼──────┐
    │  主面板 View  │ │ 设置面板    │ │ 全局快捷键   │
    │  MainPanel   │ │ Settings   │ │ HotKey      │
    └──────┬──────┘ └─────┬──────┘ └─────────────┘
           │              │
    ┌──────▼──────┐       │
    │ 新建/编辑    │       │
    │ PromptForm  │       │
    └──────┬──────┘       │
           │              │
    ┌──────▼──────────────▼──────┐
    │      数据层 (SwiftData)     │
    │   Prompt Model + Store     │
    └────────────────────────────┘
```

## 数据模型

```swift
@Model
class Prompt {
    var id: UUID
    var title: String           // 标题
    var content: String         // 提示词内容（最大 2000 字）
    var tag: String             // 分类标签名称
    var tagColor: String        // 标签颜色（hex）
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int          // 排序顺序
}

// UserDefaults 存储
struct AppSettings {
    var globalShortcut: KeyCombo // 默认 Cmd+Shift+Space
    var launchAtLogin: Bool      // 开机启动
    var showMenuBarIcon: Bool    // 显示菜单栏图标
}
```

## 分阶段实施计划

---

### Phase 1: 项目骨架 + 菜单栏基础

**目标**：建立可运行的 macOS 菜单栏 app，点击图标弹出空面板。

#### Task 1.1: Xcode 项目初始化
- 创建 macOS App 项目，Bundle ID: `com.bubble.promptmanager`
- 配置为 Agent 应用（LSUIElement = YES，无 Dock 图标）
- 添加 SwiftData 和 HotKey (SPM) 依赖
- **验收**：项目可编译运行，无 Dock 图标出现

#### Task 1.2: 菜单栏 NSStatusItem
- 创建 AppDelegate，初始化 NSStatusItem
- 设置状态栏图标（SF Symbol: `bubble.left.fill`）
- 左键点击弹出主面板，右键菜单（打开面板/快捷键提示/退出）
- **验收**：状态栏出现图标，左键弹出空窗口，右键出现菜单

#### Task 1.3: NSPanel 弹窗容器
- 创建自定义 NSPanel（无标题栏、磨砂玻璃背景）
- 面板从状态栏图标下方弹出，尺寸约 420×520pt
- 点击面板外部自动关闭（`hidesOnDeactivate`）
- 嵌入 SwiftUI 视图（NSHostingView）
- **验收**：点击图标弹出磨砂玻璃空面板，点外部消失

> **Checkpoint 1**：菜单栏图标可点击，弹出磨砂玻璃空面板，右键菜单可用。

---

### Phase 2: 数据层 + 提示词列表

**目标**：能看到提示词列表，有真实数据支撑。

#### Task 2.1: SwiftData 模型与容器
- 定义 `Prompt` Model（id, title, content, tag, tagColor, createdAt, updatedAt, sortOrder）
- 在 App 入口配置 ModelContainer
- 添加预置示例数据（文章润色助手、周报生成器等 4 条）
- **验收**：app 启动时数据库初始化成功，预置数据可通过调试查看

#### Task 2.2: 提示词列表 UI
- 搜索栏（顶部，圆角，placeholder "搜索提示词"）
- 标签筛选栏（横向滚动：全部/写作/编程/翻译/办公/营销/学习/自定义，彩色胶囊按钮）
- 提示词卡片列表（ScrollView + LazyVStack）
  - 每张卡片：标题（粗体）+ 内容预览（灰色 2 行截断）+ 左侧色条
  - 右侧：编辑按钮（铅笔图标）+ 复制按钮
- 底部工具栏：`+ 创建` 按钮（左）、`设置` 按钮（右）
- **验收**：面板展示预置提示词列表，UI 与原型图 1 一致

#### Task 2.3: 搜索与筛选功能
- 搜索框实时过滤（匹配标题 + 内容）
- 标签点击筛选（"全部" 显示所有，其他按 tag 过滤）
- 搜索 + 标签可组合使用
- **验收**：输入关键词实时过滤列表，切换标签筛选正确

#### Task 2.4: 复制功能
- 点击复制按钮，将提示词 content 写入系统剪贴板
- 复制后按钮短暂变为 checkmark 反馈（0.5s 后恢复）
- **验收**：点击复制后可在任意应用粘贴出提示词内容

> **Checkpoint 2**：主面板展示提示词列表，搜索筛选可用，复制功能正常。

---

### Phase 3: 新建与编辑提示词

**目标**：完整的提示词 CRUD 功能。

#### Task 3.1: 新建提示词表单
- 点击 `+ 创建` 按钮，面板内容切换为表单视图
- 表单字段：标题输入框、提示词内容（多行 TextEditor，2000 字上限 + 字数统计）、标签选择（可选，彩色标签按钮）
- 保存/取消按钮
- 保存时校验：标题和内容不能为空
- **验收**：能创建新提示词，保存后出现在列表中，字数统计准确

#### Task 3.2: 编辑提示词
- 点击卡片右侧编辑按钮，进入编辑表单（预填现有数据）
- 复用新建表单组件
- **验收**：能编辑已有提示词，保存后列表更新

#### Task 3.3: 删除提示词
- 列表中左滑删除或编辑页面增加删除按钮
- 删除前确认弹窗
- **验收**：能删除提示词，确认后从列表移除

#### Task 3.4: 自定义标签管理
- 用户新建提示词时可输入自定义标签名
- 自动收集已使用的标签用于筛选栏
- 标签颜色自动分配或用户选择
- **验收**：创建自定义标签后，筛选栏自动出现该标签

> **Checkpoint 3**：提示词的增删改查全部可用，自定义标签运作正常。

---

### Phase 4: 全局快捷键

**目标**：通过键盘快捷键随时唤起/隐藏面板。

#### Task 4.1: 默认全局快捷键
- 集成 HotKey 库（SPM）
- 注册默认快捷键 `Cmd + Shift + Space`
- 按下快捷键 toggle 面板显示/隐藏
- **验收**：在任意应用中按 Cmd+Shift+Space 可唤起/隐藏面板

#### Task 4.2: 快捷键自定义录制器
- 设置页面中的快捷键输入框，点击后进入录制模式
- 用户按下新组合键（至少一个修饰键 + 一个普通键）
- 冲突检测：检查是否与系统常用快捷键重复，给出警告
- 保存到 UserDefaults，下次启动自动加载
- **验收**：能自定义快捷键，重启后快捷键保持

> **Checkpoint 4**：全局快捷键可唤起面板，用户可自定义修改。

---

### Phase 5: 设置面板

**目标**：完整的设置功能。

#### Task 5.1: 设置面板 UI
- 点击底部 `设置` 按钮，面板右侧滑出设置视图（或覆盖式）
- 设置项：
  - 全局快捷键（显示当前快捷键 + 编辑按钮）
  - 开机启动（Toggle 开关）
  - 显示菜单栏入口（Toggle 开关）
- **验收**：设置面板 UI 与原型图 3 一致

#### Task 5.2: 开机启动功能
- 使用 `SMAppService.mainApp.register()` / `.unregister()`
- Toggle 状态与实际注册状态同步
- **验收**：开启后重启 Mac 自动运行 Bubble

#### Task 5.3: 菜单栏图标显示/隐藏
- Toggle 控制 NSStatusItem 的 `isVisible`
- 隐藏菜单栏图标时，确保全局快捷键仍可唤起面板
- 防呆：至少保留一种唤起方式（快捷键），否则无法打开
- **验收**：关闭菜单栏入口后图标消失，快捷键仍可打开面板

> **Checkpoint 5**：设置面板全部功能可用，开机启动和菜单栏控制正常。

---

### Phase 6: UI 打磨与收尾

**目标**：视觉还原度和交互体验达到发布标准。

#### Task 6.1: 磨砂玻璃与视觉打磨
- NSPanel 使用 `NSVisualEffectView`（`.hudWindow` 或 `.popover` material）
- SwiftUI 层面使用 `.ultraThinMaterial` 配合
- 面板圆角（16pt）、阴影
- 标签栏颜色与原型图一致（蓝/绿/橙/粉/紫/黄/红/灰）
- 卡片 hover 效果、按钮点击动画
- **验收**：整体视觉与原型图高度一致，磨砂效果自然

#### Task 6.2: 动画与过渡
- 面板弹出/收起动画（fade + 轻微 scale）
- 列表项出现动画
- 视图切换过渡（列表 ↔ 表单 ↔ 设置）
- 复制成功的 checkmark 动画
- **验收**：所有过渡流畅，无闪烁跳动

#### Task 6.3: 边缘情况处理
- 空列表状态（引导用户创建第一条提示词）
- 搜索无结果状态
- 超长标题/内容截断显示
- 多显示器支持（面板跟随状态栏图标所在屏幕）
- **验收**：所有边缘情况有友好的 UI 反馈

#### Task 6.4: App 图标与 metadata
- 设计 App 图标（气泡风格）
- 设置 Info.plist：版本号、版权信息
- 菜单栏图标适配 Light/Dark 模式
- **验收**：图标清晰美观，Light/Dark 模式下状态栏图标可见

> **Checkpoint 6**：应用视觉打磨完成，可进入测试和发布流程。

---

## 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 全局快捷键需要辅助功能权限 | 首次使用需授权 | 首次启动引导用户开启权限 |
| 快捷键与其他 app 冲突 | 快捷键无响应 | 冲突检测 + 用户可自定义 |
| SwiftData 在 macOS 14 有 bug | 数据丢失 | 备选方案：退回 JSON 文件存储 |
| NSPanel 在多显示器下定位异常 | 面板位置错误 | 计算 NSStatusItem 的 screen frame |

## 文件结构（预期）

```
Bubble/
├── Bubble.xcodeproj
├── Bubble/
│   ├── BubbleApp.swift              // App 入口
│   ├── AppDelegate.swift            // NSStatusItem + NSPanel 管理
│   ├── Models/
│   │   └── Prompt.swift             // SwiftData Model
│   ├── Views/
│   │   ├── MainPanelView.swift      // 主面板（搜索+列表）
│   │   ├── PromptCardView.swift     // 提示词卡片
│   │   ├── TagFilterBar.swift       // 标签筛选栏
│   │   ├── PromptFormView.swift     // 新建/编辑表单
│   │   └── SettingsView.swift       // 设置面板
│   ├── Services/
│   │   ├── HotKeyManager.swift      // 全局快捷键管理
│   │   ├── SettingsManager.swift    // 设置持久化
│   │   └── ClipboardManager.swift   // 剪贴板操作
│   ├── Helpers/
│   │   └── PanelController.swift    // NSPanel 控制器
│   └── Resources/
│       └── Assets.xcassets          // 图标资源
└── tasks/
    ├── plan.md
    └── todo.md
```
