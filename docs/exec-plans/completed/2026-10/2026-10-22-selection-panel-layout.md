# 划词翻译面板布局重构

- 状态：completed
- 创建日期：2026-10-22
- 负责人：Grok
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `Grok`
- **Model:** `Grok 4.7`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

## 背景

划词窗口用 `NSTableView` 纵向堆叠输入框、语言栏、阅读助手和每个翻译服务卡片。阅读行在内容测高之前使用 380–640 的回退高度，服务行又各自占一张完整卡片，所以短句也会留下大块空白，并且 AI 译文和引擎译文同时展开。

目标是同一套查询、词典和朗读能力，呈现为紧凑的深色浮动面板：标题栏、一行语言、原文、一条主要译文，以及「句子解析 / 词典 / 其他译文」。

## 目标与范围

- 目标结果：Mini 和 Fixed 划词窗口按目标面板展示；Main 窗口保留可输入的查询框，其下使用同一面板。窗口高度跟随内容，超过现有最大高度后只由外层表格滚动。
- 允许修改路径：
  - `EasyRead/Swift/Feature/ReadingAssistant/`
  - `EasyRead/objc/ViewController/Window/BaseQueryWindow/`
  - `EasyRead/objc/ViewController/View/Titlebar/`
  - `EasyRead/App/Localizable.xcstrings`
  - `EasyRead.xcodeproj/project.pbxproj`
  - `docs/exec-plans/active/2026-10-22-selection-panel-layout.md`
  - `docs/histories/2026-10/2026-10-22-selection-panel-layout.md`
- 同任务 history：`docs/histories/2026-10/2026-10-22-selection-panel-layout.md`
- 用户限制：直接改现有代码；不重写项目；不改提示词和解析后端；不加入壁纸或 Dock；不添加没有实现的按钮；不提交无关的既有改动。
- 非目标：迁移窗口框架、改查询服务实现、新增测试、推送远程。
- 验收标准：
  - 短句面板紧凑，原文和一条译文直接可见。
  - 三个标签同时只显示一个模块，切换不重新请求。
  - 语法颜色来自解析出的句子成分。
  - 固定、复制、朗读、设置、Esc 和语言切换仍可用。
  - 工程能构建。实际窗口对照截图；做不到的部分明确写出。

## 工作计划

1. 用一个面板行替换语言行和服务行。Mini/Fixed 不显示输入行；Main 和带 OCR 图片的窗口保留输入行。
2. 重做标题栏为图标、「划词翻译」、固定、朗读原文、复制、设置。外部词典链接和快捷操作留在右键菜单，快捷键继续打开原按钮。
3. 句子解析复用 `ReadingAssistantModel` 和 `GrammarStructure`。词典与其他译文复用缓存的 `EZResultView`。
4. 补齐六种语言的文案，构建，并在可能时启动窗口截图。

## 风险与决策

- 结果视图原先靠表格行查找。改为按服务标识缓存，否则词典 HTML 高度回调会丢失视图。
- 不把 `EZResultView` 放进 SwiftUI，避免 Auto Layout 被宿主视图拉伸。
- 语法标注按 `sourceRange` 做不重叠的最长片段，颜色用 `GrammarRole`，不按词序写死。
- 语言菜单用 AppKit `NSMenu`，因为浮动窗口是 nonactivating panel，SwiftUI `Menu` 不稳定。
- 单行高度为测得的 SwiftUI 高度加当前标签的服务视图高度。系统标题栏保持 28pt，不在内容里再做一条工具栏。

## 进度

- [x] 面板与宿主
- [x] 窗口、结果缓存和标题栏
- [x] 文案与工程引用
- [x] 构建和界面核对

## 验证

- `xcodebuild build -workspace EasyRead.xcworkspace -scheme EasyRead -configuration Debug -skipPackageUpdates -onlyUsePackageVersionsFromResolvedFile -derivedDataPath ~/Library/Developer/Xcode/DerivedData/Easydict-Agent/<checkout-id>`：`** BUILD SUCCEEDED **`。最终一次构建已去掉临时截图代码。
- 用调试包 `--queryText` 打开 Fixed 窗口，并由窗口自身导出截图。普通英文句子下，标题栏、语言行、原文、一条译文、三个标签和语法分析与目标面板一致。语法颜色来自真实成分：主语红、谓语黄、宾语蓝、状语绿。
- `git diff --check` 通过。`selection.panel.title` 的 zh-Hans 为「划词翻译」。
- 未运行完整测试套件。词典标签、其他译文标签、超长文本、失败态和固定后继续划词没有逐项点击验证。

## 完成条件

- 构建通过，或失败原因已记录。
- history 写入 `docs/histories/2026-10/`，本计划移到 `docs/exec-plans/completed/2026-10/`。
- 只提交本次相关文件。
