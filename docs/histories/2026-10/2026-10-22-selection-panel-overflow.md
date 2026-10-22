## 2026-10-22 | 任务：修正语法换行和语言箭头间距

**Links:** [exec plan](../../exec-plans/completed/2026-10/2026-10-22-selection-panel-overflow.md)

### 执行上下文

- **Agent Name:** `Grok`
- **Model:** `Grok 4.7`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

### 用户请求

语法分析里短成分后面空出大片空白，下一成分画出窗口；语言胶囊的箭头贴着文字和边缘。要求看真实窗口截图，而不是只读代码。

### 变更

- 语法原文改成一条按面板宽度换行的下划线句子，成分标签单独换行。
- 解释取消两行省略。
- 语言按钮自己排文字和箭头：左右 12pt，箭头前 10pt。

### 设计意图

不可换行的成分块无法同时避免空洞和溢出。下划线留在原句上，标签改成图例，颜色仍来自 `GrammarRole`。不改解析提示和请求。

### 验证

- `xcodebuild build`（Debug，agent DerivedData，跳过包更新）：`** BUILD SUCCEEDED **`。
- 查看调试窗口截图：例句完整换行，窗口边缘不再裁切 “infectious disease dynamics.”，短主语后没有整行空白。解释里的 “to introduce...” 是解析原文里的省略，不是界面截断。
- 放大新旧语言胶囊：旧箭头贴住右缘；新箭头与「简体中文」约 11pt，与右缘约 12pt。
- 未点击语言菜单、词典和其他译文。

### 受影响文件

- `EasyRead/Swift/Feature/ReadingAssistant/SelectionPanelView.swift`
- `docs/exec-plans/completed/2026-10/2026-10-22-selection-panel-overflow.md`

### 后续事项

- 成分标签不再对齐到对应词组下方。
- Applications 里的 EasyRead.app 仍是 10 月 15 日的安装包；当前界面在 Debug 的 `EasyRead-debug`。
