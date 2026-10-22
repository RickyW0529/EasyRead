## 2026-10-22 | 任务：重构划词翻译浮动面板

**Links:** [exec plan](../../exec-plans/completed/2026-10/2026-10-22-selection-panel-layout.md)

### 执行上下文

- **Agent Name:** `Grok`
- **Model:** `Grok 4.7`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

### 用户请求

把划词翻译窗口改成紧凑的深色浮动面板：标题栏、一行语言、原文、一条译文，以及句子解析、词典和其他译文三个标签。保留原有查询、词典、朗读和复制能力。

### 变更

- 查询表改为可选输入行加一个面板行。Mini 和 Fixed 不再单独列出语言行和每个服务卡片。
- 标题栏改为应用图标、「划词翻译」、固定、朗读原文、复制和设置。
- 句子解析复用阅读模型的语法结构；词典和其他译文复用缓存的结果视图。
- 补齐 `selection.panel.*` 文案。

### 设计意图

空白来自表格把阅读行的回退高度和每张服务卡片加在一起，不是内边距过大。面板行只按测得的内容和当前标签的服务视图计算高度，系统标题栏仍负责窗口按钮和浮动层级。

### 验证

- `xcodebuild build`（Debug，agent DerivedData，跳过包更新）：`** BUILD SUCCEEDED **`。
- 调试应用打开例句 “This website presents a set of lectures on quantitative economic modeling.”，窗口截图与目标面板的层级一致。
- 未运行测试套件，也没有逐项点击词典、其他译文、超长文本和失败态。

### 受影响文件

- `EasyRead/Swift/Feature/ReadingAssistant/SelectionPanelView.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAssistantHostView.swift`
- `EasyRead/objc/ViewController/Window/BaseQueryWindow/EZBaseQueryViewController.m`
- `EasyRead/objc/ViewController/Window/BaseQueryWindow/EZBaseQueryWindow.m`
- `EasyRead/objc/ViewController/View/Titlebar/EZTitlebar.h`
- `EasyRead/objc/ViewController/View/Titlebar/EZTitlebar.m`
- `EasyRead/App/Localizable.xcstrings`
- `EasyRead.xcodeproj/project.pbxproj`
- `docs/exec-plans/completed/2026-10/2026-10-22-selection-panel-layout.md`

### 后续事项

- Mini 和 Fixed 在没有 OCR 图片时不再显示行内输入框，聚焦输入的快捷键在那里不会作用到可见输入框。
- 「显示快捷操作按钮」不再往标题栏加按钮；换行、去注释和分词仍在标题栏右键菜单，Google、苹果词典和欧路的全局快捷键仍调用原来的按钮对象。
- 介词短语若被解析为状语，颜色沿用现有绿色，不按示意图改成紫色。
