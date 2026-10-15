# 阅读助手 AI 请求流式化与 think 标签解析修复

- 状态：completed
- 创建日期：2026-10-15
- 负责人：wangruiqi
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `opencode`
- **Model:** `opencode-go/glm-5.3`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

## 背景

阅读助手（统一阅读卡片）的 AI 翻译对 MiniMax 与 DeepSeek 均不可用：

1. **MiniMax（实测）**：`MiniMax-M2.7` 无视 `enable_thinking: false`，响应 content
   强制以 `<think>…</think>` 开头（流式与非流式相同，思考内联在 `delta.content`，
   无独立 `reasoning_content` 字段）。`ReadingAnalysis.decode` 只剥 Markdown 代码围栏
   （`AIWordExplanation.strippingCodeFences`），JSON 在第 0 个字符解析失败，永远报
   `invalid_response`。剥掉 think 块后实测 JSON 合法且通过全部校验。
2. **DeepSeek（实测）**：`api.deepseek.com` chat completions 接受连接后不返回任何
   body（`/v1/models` 正常、key 有效；流式只发 `: keep-alive`）。用户确认为对方
   服务端故障，非本仓库问题。

用户在方案选择中明确选择"解析层修复 + 流式重写"。

## 目标与范围

- 目标结果：
  1. EasyReadKit 的 `strippingCodeFences` 剥离开头 `<think>…</think>` 块，修复
     MiniMax 及所有思考内联泄漏模型（含硅基流动 preset 的 `MiniMax-M2.7`）。
  2. `ReadingAIClient` 传输层改为 SSE 流式（`stream: true`），并显式忽略
     `reasoning_content` 增量；错误映射、超时预算与现状保持一致。
- 允许修改路径：
  - `EasyReadKit/Sources/EasyReadKit/Models/AIWordExplanation.swift`
  - `EasyRead/Swift/Feature/ReadingAssistant/ReadingAIClient.swift`
  - `EasyReadKit/Tests/EasyReadKitTests/AIWordExplanationTests.swift`
  - 新增 `EasyReadKit/Tests/EasyReadKitTests/ReadingAnalysisTests.swift`
  - 新增 `EasyReadTests/Feature/ReadingAssistant/ReadingAIClientTests.swift`
  - `EasyRead.xcodeproj/project.pbxproj`（新测试文件接线）
- 同任务 history：`docs/histories/2026-10/2026-10-15-reading-ai-stream-think-strip.md`
- 用户限制：不 push、不创建 PR。
- 非目标：
  - 不改 `ReadingAssistantModel`/View（无渐进渲染：结果为完整 JSON）。
  - 不改 provider preset、超时预算、重试策略。
  - 不处理 DeepSeek 服务端故障（vendor 侧自愈）。
- 验收标准：
  - think 前缀响应在 kit 层可正常 decode；流式 SSE 响应在 client 层正确累积、
    终止与错误映射；EasyReadKit 与 EasyReadTests 新增测试全部通过。

## 工作计划

1. EasyReadKit：`strippingCodeFences` 增加开头 `<think>…</think>` 剥离（闭合→去块；
   未闭合→返回空串，与主工程 `removeThinkTagContent` 语义一致；非开头不动）。
2. 测试：`AIWordExplanationTests` 增加围栏+think 组合用例；新增
   `ReadingAnalysisTests` 覆盖 think 前缀端到端 decode。
3. `ReadingAIClient` 重写传输层：Alamofire `Session.streamRequest(...).streamTask()
   .streamingData()` 消费 SSE；新增内部 `StreamEventParser`（字节缓冲、按事件边界
   切分、只取 `data:` 行）；只累积 `choices[0].delta.content`（Decodable 忽略
   `reasoning_content`）；`[DONE]` 或流自然结束收尾；`finish_reason == "length"` →
   `truncatedResponse`；非 2xx 与 `Request.error` 的错误映射与现状一致；Session
   可注入供测试。`models()` 保持非流式不变。
4. 新增 `EasyReadTests/Feature/ReadingAssistant/ReadingAIClientTests.swift`
   （本地 MockURLProtocol 支持分段投递）并同步 `project.pbxproj`。
5. 验证：`swift test`（EasyReadKit）+ agent DerivedData 的 `xcodebuild test`
   （精确选择新 suite）+ `git diff --check`。
6. Review：`review` skill 审查，修复有效 finding 后复验。

## 风险与决策

- 风险：SSE 解析对多字节 UTF-8 跨 chunk 分割——用字节级缓冲、仅完整事件转 String。
- 风险：部分 provider 以非 SSE JSON 错误体响应非 2xx——按状态码映射，不 surface
  body（保持现有隐私约束）。
- 决策：保留 Alamofire（符合工程规范"网络请求使用 Alamofire 的 async/await API"），
  用 `Request.error` 在流结束后恢复超时/网络错误映射保真度。
- 决策：资源超时（60s）与请求超时（50s）维持现状，DeepSeek 故障行为不变（~60s 报错）。

## 进度

- [x] EasyReadKit think 剥离 + 用例
- [x] ReadingAIClient 流式重写
- [x] ReadingAnalysisTests 新增
- [x] ReadingAIClientTests 新增 + pbxproj 接线
- [x] swift test / xcodebuild test 验证
- [x] review skill 审查
- [x] history、plan 归档、本地提交

## 验证

- `swift test --filter 'AIWordExplanationTests|ReadingAnalysisTests|GrammarExplanation'`（EasyReadKit）：通过，3 个 suite、45 个测试。
- `xcodebuild test -workspace EasyRead.xcworkspace -scheme EasyRead -destination 'platform=macOS,arch=arm64' -derivedDataPath ~/Library/Developer/Xcode/DerivedData/Easydict-Agent/Xcode\ project_EasyRead -only-testing:EasyReadTests/ReadingAIClientTests`：通过，1 个 suite、11 个测试。本机没有 `xcbeautify`，因此未经过它。
- `git diff --check`：通过。

## 完成条件

- 上述验证全部通过；review 无未修复的有效 finding；history 已写入并链接本 plan；
  本文件移动到 `completed/2026-10/`；变更已本地提交（不 push）。
