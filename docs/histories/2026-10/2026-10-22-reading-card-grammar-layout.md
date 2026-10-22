## 2026-10-22 | 任务：句子结果直接展示语法和翻译

**Links:** 无单独执行计划

### 执行上下文

- **Agent Name:** `Grok`
- **Model:** `Grok 4.7`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

### 用户请求

去掉「解析句子」按钮，句子查询直接给出语法解析。上面是语法结构，下面是翻译。语法详情点开后展开，并整理阅读结构。

### 变更

- 句子结果不再经过按钮切换。语法标注直接显示，翻译放在其下，语法详情默认收起。
- 展开后的详情按句子主干、句子成分、阅读顺序和术语分组。成分沿句子顺序排列，并用与标注相同的颜色区分。
- 句子卡片按实际内容增高，详情在卡片内展开。单词结果保持原来的固定行高和内部滚动。
- 移除不再使用的 `reading.action.grammar`，并为新的小节标题补充六种 locale。

### 设计意图

语法数据本来就和翻译同一次返回，按钮只控制显隐。直接展示可以少一次点击。详情补上原先只在悬停里出现的成分解释，避免展开后仍是一段平铺文字。句子行高跟随内容，是为了展开时不用在固定高度里再套一层滚动。

### 验证

- `BuildTools/.build/release/swiftformat --lint --config .swiftformat` 覆盖两个变更 Swift 文件：通过，0 个文件需要格式化。
- `xcodebuild build -workspace EasyRead.xcworkspace -scheme EasyRead`（agent DerivedData）：两次均 `** BUILD SUCCEEDED **`，退出码 0。本机没有 `xcbeautify`，日志直接写入文件。第二次是行高和单词滚动调整后的增量构建。
- `git diff --check` 与 `jq -e . EasyRead/App/Localizable.xcstrings`：通过。
- 审查变更 diff：句子按钮和 `showsGrammar` 已移除；详情列出全部成分；单词路径仍走 380 点行高和 `ScrollView`。没有需要再改的缺陷。
- 手动检查：未启动应用，没有在真实查询窗口里验收展开后的行高和标注换行。

### 受影响文件

- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAssistantView.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAssistantModel.swift`
- `EasyRead/App/Localizable.xcstrings`

### 后续事项

- 在真实查询窗口里看一句较长的句子：确认语法在上、翻译在下，点开语法详情后窗口跟着增高且文字不被裁切。
