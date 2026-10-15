## 2026-10-15 | 任务：修复 MiniMax 阅读请求的思考预算截断

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-15-minimax-stream-truncation.md)、[MiniMax OpenAI SDK](https://platform.minimax.cn/docs/api-reference/text-openai-api)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

### 用户请求

用户报告 MiniMax 阅读助手返回被截断，提供多段 SEIR 介绍文字，并明确允许使用已保存的
MiniMax 凭据向既有端点发送该原文及阅读提示词复现和验证。完成修复后重新安装供用户测试。

### 变更

- 为 MiniMax M3.1 模型设置 `reasoning_effort: medium`，替代该模型不支持的
  `enable_thinking: false`。保留 8192 token 上限、请求和资源超时，以及其他模型的请求参数。
- 阅读提示词明确要求多句/多段保留整段原文，并同时填写顶层 `translation` 和
  `grammar.translation`，对应现有解码契约。
- 使用临时诊断程序和现有测试验证，没有新增或扩写仓库测试。

### 设计意图

MiniMax 官方契约说明 M3.1 默认 max 思考深度且必须思考，思考消耗输出预算。用户原文在原参数下
实测得到 `finish_reason: length`，思考约 28080 字符、正文 JSON 不完整。降低思考深度能够结束，
但 low 档多次漏字段或输出非法 role；medium 配合明确的多段及重复译文要求，两次通过生产传输及
解码校验。因此采用 medium 并保留原有预算和严格结果校验。

### 验证

- 授权的 MiniMax 真实请求：复现原参数截断；最终参数与提示词通过 `ReadingAIClient.complete`
  和 `ReadingAnalysis.decode`，两次均返回 15 个语法结构，约 11 秒和 27 秒。
- `swift test --filter 'AIWordExplanationTests|ReadingAnalysisTests|GrammarExplanation'`（EasyReadKit）：45 个测试通过。
- `xcodebuild test -workspace EasyRead.xcworkspace -scheme EasyRead -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath <agent-derived-data> -disableAutomaticPackageResolution -only-testing:EasyReadTests/ReadingAIClientTests`：11 个测试通过。
- `git diff --check`：通过。
- `review`：以 `15f50979` 为初始 HEAD，仅审查本任务的两处生产文件差异及其调用、解码约束；未发现本次引入的有效 finding。相比提高所有供应商预算或放宽校验，本次局部参数及提示词修正范围更小。
- `bash scripts/build-local-app.sh`：Release 构建和严格签名校验通过。
- 新旧应用 designated requirement 相同；备份旧应用后覆盖安装回原用户 Applications 路径并启动，进程及二进制哈希核对通过。

### 受影响文件

- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAIClient.swift`
- `EasyReadKit/Sources/EasyReadKit/DeepSeek/ReadingAnalysisPrompt.swift`
- `docs/exec-plans/completed/2026-10/2026-10-15-minimax-stream-truncation.md`
- `docs/histories/2026-10/2026-10-15-minimax-stream-truncation.md`

### 后续事项

- 模型输出仍可能违反 JSON 契约；继续执行既有完整性及原文一致性校验，不能保证所有原文和采样结果均成功。
- 此次未修改先前 review 指出的 `[DONE]` 后仍等待连接关闭的既有行为。
