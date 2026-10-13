## 2026-10-13 | 任务：修复划词启动并统一上下文阅读体验

**Links:** [已完成计划](../../exec-plans/completed/2026-10/2026-10-12-launch-selection-recovery.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

### 用户请求

修复重复菜单栏实例和辅助功能开启后仍不能取词的问题；划词后自动调用 DeepSeek，单词和短语
直接显示释义及上下文 tip，句子显示译文且只保留解析按钮。一次准备全部对应结果并缓存，
使用通用 JSON 支持多语言，原文按语法角色着色并在悬浮时显示解释，完成测试及独立 Review。

### 变更

- 在应用副作用之前检查旧实例并取得进程锁，重复启动转交参数；提供固定开发签名的本地构建脚本。
- 阅读助手统一完成分类、上下文解释、翻译和适用的语法结果。等待同一次划词上下文采集，沿用
  AI、密钥、来源和长度门禁，移除旧 DeepSeek 服务的重复自动请求。
- 单词、短语直接渲染可复用的结构化 tip；句子解析只切换本地展示。内存缓存至多 12 项、10 分钟，
  以原文、上下文、语言和服务配置区分，隐私或密钥变化清除结果；开启 AI 仅恢复当前卡片查询。
- 通用 JSON 显式区分源语言、目标语言和解释语言，保留旧公开字段解码兼容，并校验原文和证据。
  语法片段按角色、出现序号定位，支持重复词与非空格文字，兼容中英混排。
- 独立 TextKit 测量避免原文溢出；粗彩色下划线与底纹增强可见性，主动 NSPopover 支持移入阅读。
  查询输入框关闭自动文字修正，防止原文被改写后取消分析。
- 苹果词典保留词条查询，明显句子不再自动查词典；更新六种语言的提示和中文本地使用文档。
  未新增或扩写测试文件。

### 设计意图

在启动、查询提交、结构化解码和展示边界统一处理问题。AI 结果准备只有一个入口，界面选择
不创建第二个分析请求；缓存保持有限且仅在内存中，不因便利绕过隐私条件。系统辅助功能授权
仍由用户管理，不改写 TCC 数据库；稳定签名与安装位置使后续更新使用一致的应用身份。

### 验证

- `bash scripts/build-local-app.sh`：最终 Release 构建成功；`codesign --verify --deep --strict`
  成功。使用专用 agent DerivedData，跳过全仓 formatter；早期构建缓存被误删的失败未计为通过。
- `xcrun swift test --package-path EasyReadKit --scratch-path <temporary-path>`：130 项现有测试通过。
- `xcodebuild test`：专用 DerivedData，Debug/arm64，AppleDictionaryTests、ReverseTranslationTests、
  UtilityFunctionsTests、ThrottleGateTests 共 27 项通过，最后原文保真增量已重新运行。
- `git diff --check`、String Catalog JSON、工程 plist 与脚本语法检查通过。
- 单实例：三个同时启动的副本退出，已有实例接收查询；菜单栏仅一个项目。清理本应用旧权限登记，
  用户重新授权后实际辅助功能检查为 true；后续稳定签名替换仍保持授权。
- 实机：TextEdit 首次 bank 划词直接返回“河岸”和来源证据；bank of the river 显示名词短语 tip，
  两者均无三个动作按钮。重复选择短语立即显示缓存；当前卡片 AI 关闭再开启后恢复分析。
- 实机：英文、中文句子自动翻译；“我每天用Python编程。”原文保持不变，返回
  “I program in Python every day.”。解析按钮立即展示原文；鼠标悬浮实际弹出中文主语、方式状语等解释。
- 实机：中文词语“河岸”返回英文 riverbank 释义和中文解释；无上下文时明确显示仅依据所选词语。
- 独立 review 技能审查：已修复词边界、重复片段、浮层移入、开启 AI、隐藏窗口重复发送、混排定位
  等有效问题；最终快照无未处理 finding，最后输入框保真变更也已增量复核。

### 受影响文件

- `EasyRead/App/ApplicationInstance.swift`、应用入口及 `Localizable.xcstrings`
- `EasyRead/Swift/Feature/ReadingAssistant/`
- `EasyRead/Swift/Feature/ContextExtraction/ContextExtractor.swift`
- `EasyRead/Swift/Service/DeepSeek/DeepSeekService.swift`
- `EasyRead/Swift/Service/Dictionary/AppleDictionary/AppleDictionary.swift`
- `EasyRead/objc/ViewController/View/QueryView/EZQueryView.m`
- `EasyRead/objc/ViewController/Window/BaseQueryWindow/EZBaseQueryViewController.m`
- `EasyReadKit/Sources/EasyReadKit/DeepSeek/`、`EasyReadKit/Sources/EasyReadKit/Models/`
- `EasyRead.xcodeproj/project.pbxproj`、`scripts/build-local-app.sh`
- `docs/user-docs/zh/Local-development-build.md` 与本任务 plan/history

### 后续事项

- 实机范围为当前 Mac、TextEdit 和中英文代表性输入；未穷举所有源应用及语言。
- 系统截屏未能生成图片，使用 Accessibility 读取实际窗口和鼠标事件验证悬浮；无像素截图验收。
- DeepSeek 的 JSON mode 配合本地校验降低格式失败，不能保证模型及网络永不失败；无效结果保留重试入口。
