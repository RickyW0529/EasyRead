# 修复 MiniMax 阅读请求的思考预算截断

- 状态：completed
- 创建日期：2026-10-15
- 负责人：wangruiqi
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

## 背景

用户重装流式版本后，使用 MiniMax 分析多段 SEIR 介绍文字，阅读助手报告输出被截断。
当前实际模型为 `MiniMax-M3.1-Flash-Preview`。客户端固定输出预算为 8192 token，使用
`enable_thinking: false`，没有设置该模型支持的 `reasoning_effort`。
官方文档说明 M3.1 必须思考，默认思考深度为 max，思考也计入输出预算。

## 目标与范围

- 目标结果：首轮定位并修复思考预算截断；后续按用户明确选择切到 MiniMax-M3 并关闭思考，修复 DONE 后继续等连接的行为。
- 允许修改路径：`EasyRead/Swift/Feature/ReadingAssistant/ReadingAIClient.swift`、`EasyReadKit/Sources/EasyReadKit/DeepSeek/ReadingAnalysisPrompt.swift`、`EasyRead/Swift/Feature/ReadingAssistant/ReadingAIProvider.swift`、本计划及同任务 history。
- 同任务 history：`docs/histories/2026-10/2026-10-15-minimax-stream-truncation.md`
- 用户限制：保留已有工作区改动；不新增或扩写仓库测试；不 push 或创建 PR。
- 非目标：扩大所有供应商的 token/超时预算、实现渐进渲染、重构整个 SSE 传输。
- 后续明确授权：用户再次遇到超时，选择切到同账号 MiniMax-M3 并关闭思考；修复 DONE 后继续等待连接的问题。
- 验收标准：授权的真实原文请求完成且通过生产解码/校验；已有相关测试通过；Release 构建及签名通过并安装启动。

## 工作计划

1. 使用应用真实提示词及用户原文记录结束原因和脱敏 token 统计，单变量验证思考深度设置。
2. 根据复现结果最小修复 MiniMax M3.1 请求参数，明确多段原文及重复译文字段的输出要求，保留现有校验。
3. 运行现有相关测试、真实供应商验证和 Release 构建，执行 review 并修复有效 finding。
4. 更新 history、归档计划、创建仅含本任务文件的本地提交，备份旧应用并按原签名和路径重新安装启动。

## 风险与决策

- 官方契约依据：[MiniMax OpenAI SDK](https://platform.minimax.cn/docs/api-reference/text-openai-api)。
- 真实 API 调用已经获得用户明确授权：使用已保存密钥，将用户给出的 SEIR 原文和阅读提示词发往既有 MiniMax 端点。
- 诊断仅输出结束原因、字符数和 token 用量，密钥只在内存中用于认证，不输出正文或密钥。
- 保留真实截断错误，不能忽略 length 或放行不完整 JSON。
- M3.1 使用 medium：low 虽能结束，但多次漏字段或使用非法 role；medium 配合明确多段/重复译文要求已经通过生产链路验证。保留 8192 token 和原超时。

## 进度

- [x] 真实响应定位与单变量验证。
- [x] 最小修复。
- [x] 现有测试、真实响应校验、Release 构建、签名及 review。
- [x] history、归档及安装启动；按仓库交付规则创建本地提交。

## 验证

- 原参数真实请求：HTTP 200、finish_reason=length、思考 28080 字符、JSON 不完整，85.67 秒结束；诊断脚本不采用应用的 60 秒资源预算，该耗时不是应用耗时。
- low 与 medium 均能正常结束，但模型会漏掉嵌套 grammar.translation，部分响应仅复述首句；需明确提示词的已有契约。
- 最终提示词的 Kit 解析测试 45 个通过。
- medium 与最终提示词的真实生产客户端和 ReadingAnalysis.decode 两次通过，均 15 个语法结构，约 11 秒和 27 秒。
- 最终 xcodebuild test：ReadingAIClientTests 11 个测试通过。
- review：仅审查本任务两处生产文件差异，未发现本次引入的有效 finding；保留已知 DONE 连接收尾问题。
- `bash scripts/build-local-app.sh`：Release 构建和严格签名校验通过。
- 新旧 designated requirement 相同；旧应用已备份，新版本安装回原用户 Applications 路径并启动。

## 后续处理：关闭思考与流结束收尾

- [x] 为 MiniMax-M3 发送 thinking disabled，保留 M3.1 的既有参数。
- [x] 将 MiniMax-M3 加入预设并设为新用户默认模型。
- [x] 收到 DONE 后立即终止观察，并保持任务取消、HTTP/传输错误和截断检查。
- [x] 无思考响应 0 reasoning 字符；单句生产链路约 7 秒通过。客户端测试 11 个通过，review 无新增 finding；Release 构建和严格签名校验通过。
- 已知限制：M3 无思考整段输出存在 JSON 错误或仅处理首句，不将其记为通过。
- [x] 已备份并重新安装，退出后更新用户所选模型为 MiniMax-M3；进程、当前模型及二进制哈希核对通过；归档记录后按仓库规则本地提交。

## 完成条件

- 原文真实请求验证通过，现有测试、Release 构建和适用 review 完成。
- 本任务文档更新并归档、仅提交本任务差异、新应用安装启动。
