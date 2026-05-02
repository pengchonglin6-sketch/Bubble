# Bubble — 任务清单

> 按垂直切片排列，每个任务交付一个完整的可验证功能路径。
> 状态：`[ ]` 待做 · `[~]` 进行中 · `[x]` 完成

---

## Phase 1: 项目骨架 + 菜单栏基础

- [ ] **1.1 Xcode 项目初始化**
  - 创建 macOS App 项目（SwiftUI lifecycle）
  - 配置 LSUIElement = YES（无 Dock 图标）
  - 添加 SPM 依赖：HotKey
  - 添加 SwiftData framework
  - AC: 项目编译运行成功，无 Dock 图标

- [ ] **1.2 菜单栏 NSStatusItem**
  - AppDelegate 中创建 NSStatusItem
  - 状态栏图标使用 SF Symbol `bubble.left.fill`
  - 左键点击：toggle 面板显示
  - 右键菜单：打开面板 / 快捷键提示 / 退出
  - AC: 状态栏图标可见，左键弹窗，右键菜单可用

- [ ] **1.3 NSPanel 磨砂玻璃弹窗**
  - 自定义 NSPanel 子类（styleMask: nonactivating）
  - NSVisualEffectView 作为背景（material: .hudWindow）
  - 面板定位于状态栏图标下方
  - 点击外部自动关闭
  - 内嵌 NSHostingView 承载 SwiftUI
  - AC: 点击图标弹出磨砂面板，点外部关闭

> **Checkpoint 1** ✅ 菜单栏 + 空面板弹窗可用

---

## Phase 2: 数据层 + 提示词列表

- [ ] **2.1 SwiftData 数据模型**
  - 定义 Prompt @Model（id, title, content, tag, tagColor, createdAt, updatedAt, sortOrder）
  - 配置 ModelContainer（in App entry）
  - 预置 4 条示例数据
  - AC: 启动后数据库初始化，示例数据可查询

- [ ] **2.2 提示词列表 UI**
  - 搜索栏（圆角输入框，placeholder "搜索提示词"）
  - 标签筛选栏（横向 ScrollView，彩色胶囊按钮）
  - 提示词卡片（标题 + 内容预览 2 行 + 左侧色条 + 编辑/复制按钮）
  - 底部工具栏（+ 创建 / 设置）
  - AC: 列表展示预置数据，UI 与原型图 1 一致

- [ ] **2.3 搜索与标签筛选**
  - 搜索框实时过滤（匹配 title + content）
  - 标签点击筛选（"全部" = 不过滤）
  - 搜索 + 标签可组合
  - AC: 输入关键词实时过滤，标签切换正确

- [ ] **2.4 一键复制功能**
  - 复制按钮点击 → NSPasteboard 写入 content
  - 按钮变 checkmark 0.5s 后恢复
  - AC: 复制后可在任意 app 粘贴

> **Checkpoint 2** ✅ 主列表 + 搜索筛选 + 复制功能完整

---

## Phase 3: 新建与编辑提示词

- [ ] **3.1 新建提示词表单**
  - 点击 `+ 创建` 切换到表单视图
  - 字段：标题（TextField）、内容（TextEditor, 2000 字上限 + 计数）、标签选择
  - 保存/取消按钮
  - 校验：标题和内容非空
  - AC: 可创建提示词，保存后出现在列表

- [ ] **3.2 编辑提示词**
  - 卡片编辑按钮 → 预填表单
  - 复用 PromptFormView
  - AC: 可编辑已有提示词，保存后列表更新

- [ ] **3.3 删除提示词**
  - 编辑页面底部删除按钮（红色）
  - 删除确认弹窗
  - AC: 确认后提示词从列表移除

- [ ] **3.4 自定义标签**
  - 表单中可输入新标签名
  - 自动收集已用标签到筛选栏
  - 颜色自动分配（预设色板循环）
  - AC: 新标签创建后出现在筛选栏

> **Checkpoint 3** ✅ 完整 CRUD + 自定义标签

---

## Phase 4: 全局快捷键

- [ ] **4.1 默认快捷键注册**
  - HotKey 库注册 Cmd+Shift+Space
  - 按下 toggle 面板
  - AC: 任意 app 中按 Cmd+Shift+Space 唤起/隐藏面板

- [ ] **4.2 快捷键自定义录制器**
  - 设置中的快捷键输入框
  - 点击进入录制模式，按组合键录入
  - 校验：至少一个修饰键 + 一个普通键
  - 冲突检测警告
  - 保存至 UserDefaults
  - AC: 可自定义快捷键，重启后保持

> **Checkpoint 4** ✅ 全局快捷键可用且可自定义

---

## Phase 5: 设置面板

- [ ] **5.1 设置面板 UI**
  - 面板内右侧滑出/覆盖式设置视图
  - 全局快捷键（显示 + 编辑）
  - 开机启动 Toggle
  - 菜单栏入口 Toggle
  - AC: 设置面板 UI 与原型图 3 一致

- [ ] **5.2 开机启动**
  - SMAppService.mainApp.register / unregister
  - Toggle 与实际状态同步
  - AC: 开启后重启 Mac 自动运行

- [ ] **5.3 菜单栏图标控制**
  - Toggle 控制 isVisible
  - 隐藏时确保快捷键仍可用
  - AC: 图标隐藏后快捷键仍可唤起面板

> **Checkpoint 5** ✅ 设置功能全部可用

---

## Phase 6: UI 打磨与收尾

- [ ] **6.1 视觉还原**
  - 磨砂玻璃效果调优
  - 面板圆角 16pt + 阴影
  - 标签颜色匹配原型图
  - 卡片 hover 效果
  - AC: 视觉与原型图高度一致

- [ ] **6.2 动画过渡**
  - 面板弹出/收起动画
  - 视图切换过渡
  - 复制 checkmark 动画
  - AC: 所有过渡流畅无闪烁

- [ ] **6.3 边缘情况**
  - 空列表引导状态
  - 搜索无结果状态
  - 超长内容截断
  - 多显示器面板定位
  - AC: 所有边缘情况有友好 UI

- [ ] **6.4 App 图标与 metadata**
  - App 图标设计
  - Info.plist 版本/版权
  - 状态栏图标 Light/Dark 适配
  - AC: 图标美观，Dark 模式正常

> **Checkpoint 6** ✅ 发布就绪

---

## 总计

- **6 个 Phase**，**18 个 Task**，**6 个 Checkpoint**
- 预估工作量：约 3-5 天（熟练开发者）
