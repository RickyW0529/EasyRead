## 2026-10-15 | 任务：流式化阅读助手并剥离开头 think 块

**Links:** [已完成计划](../../exec-plans/completed/2026-10/2026-10-15-reading-ai-stream-think-strip.md)

### 执行上下文

- **Agent Name:** `Grok`
- **Model:** `Grok 4.7`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

### 用户请求

继续完成阅读助手 AI 翻译一直转圈的修复：剥离开头的 `<think>` 块，并把阅读请求改成
SSE 流式。DeepSeek 服务端无响应不在本次范围内。

### 变更

- `AIWordExplanation.strippingCodeFences` 在代码围栏之前去掉开头的 `<think>…</think>`；
  未闭合时返回空串，非开头的 think 文本保持不动。词义、语法和阅读分析的解码都走这个入口。
- `ReadingAIClient.complete` 改为 `stream: true`，用 Alamofire 消费 SSE，只累积
  `choices[0].delta.content`，忽略 `reasoning_content`。错误映射、50 秒请求超时和
  60 秒资源超时保持原样；`models()` 仍是非流式。
- 增加 EasyReadKit 与 `ReadingAIClientTests` 覆盖，并把后者接进 `project.pbxproj`。

### 设计意图

MiniMax-M2.7 会把思考写进正文，解析层剥离后现有 JSON 校验可以继续使用。流式传输只改变
取回方式，阅读卡片仍等完整 JSON 再渲染，不改界面、超时或供应商预设。

### 验证

- `swift test --filter 'AIWordExplanationTests|ReadingAnalysisTests|GrammarExplanation'`：通过，3 个 suite、45 个测试。
- `xcodebuild test -workspace EasyRead.xcworkspace -scheme EasyRead -destination 'platform=macOS,arch=arm64' -derivedDataPath ~/Library/Developer/Xcode/DerivedData/Easydict-Agent/<checkout> -only-testing:EasyReadTests/ReadingAIClientTests`：通过，11 个测试。本机没有 `xcbeautify`。
- `git diff --check`：通过。
- 审查：未发现需要再改的缺陷。没有 `choices` 的用量事件会不会被当成无效响应，本次没有供应商样本，未改。

### 受影响文件

- `EasyReadKit/Sources/EasyReadKit/Models/AIWordExplanation.swift`
- `EasyReadKit/Tests/EasyReadKitTests/AIWordExplanationTests.swift`
- `EasyReadKit/Tests/EasyReadKitTests/ReadingAnalysisTests.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAIClient.swift`
- `EasyReadTests/Feature/ReadingAssistant/ReadingAIClientTests.swift`
- `EasyRead.xcodeproj/project.pbxproj`
- `docs/exec-plans/completed/2026-10/2026-10-15-reading-ai-stream-think-strip.md`

### 后续事项

- DeepSeek chat completions 无响应体仍是供应商侧故障，应用大约 60 秒后报超时。
- 若某个供应商在流结束时发送没有 `choices` 的用量事件，当前会把它当成无法解析的事件并失败。
