## 2026-10-15 | 任务：整合 AI 阅读助手并支持多供应商

**Links:** [执行计划](../../exec-plans/completed/2026-10/2026-10-15-reading-ai-providers.md)

### 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

### 用户请求

参考 BranchReport 已有实现，支持多家 AI 供应商并 review。将 AI 开关、供应商和模型下拉框全部放入设置，保持查询窗口简洁；关闭 AI 时隐藏整个阅读助手卡片，只使用普通翻译和词典；移除重复的 DeepSeek 翻译卡。后续用户要求重启，并报告点击无弹窗及应用崩溃。

### 变更

- 增加“设置 → AI 翻译”，集中提供开关、供应商与模型选择、接口地址、Keychain 凭证、模型获取、自定义模型以及连接验证。
- 从 BranchReport 的 `crates/model-provider/src/vendors.rs` 和 `vendor.rs` 移植公共 chat 供应商目录及协议分派方式，转写为 Swift；参考 checkout HEAD 为 `40996d9ce8e06ef78c2e63e077ad28389dd6d9e9`。未复制用户凭证、服务端、部署专用地址、embedding 或 rerank。
- 提供 15 个公共供应商预设及自定义 OpenAI 兼容接口。目录包含 OpenAI、DeepSeek、智谱及 Coding Plan、Kimi、MiniMax、阶跃星辰、百炼、豆包、LongCat、MiMo、百灵、SiliconFlow、OpenRouter、ModelScope。
- AI 阅读请求使用独立 Alamofire 临时会话，禁用缓存和重定向；请求配置冻结，响应提交前重新核对开关、配置和隐私；切换供应商、模型、接口或密钥取消旧请求并清除内存结果。
- 复用已有 DeepSeek 模型键及 Keychain 项，供应商密钥独立存储；Keychain 输入组件不再因某个供应商没有密钥而关闭全局 AI。
- 从普通服务注册表和窗口列表移除 DeepSeek 卡；旧默认安装迁移至苹果词典与 Google 普通翻译，新安装采用同样的非 AI 默认服务。
- 阅读卡仅展示结果与必要操作。AI 关闭时从表格行映射中移除卡片，已有窗口收到开关通知后重排。
- 更新六种 locale 的设置、提示、加载及错误文案，同步新文件的 Xcode group 与 Sources 引用。

- 后续修复查询窗口崩溃：窗口初始化仍从普通翻译注册表创建已隐藏的 Youdao 朗读服务，触发 `LocalStorage.service` 的 Debug 断言。增加独立朗读工厂，更新窗口、音频播放器和单词结果的调用，并让不支持的普通服务保持日志加 `nil` 的 optional 契约。

### 设计意图

将 AI 阅读功能归为一个入口，设置负责供应商配置，查询窗口负责结果展示。使用数据目录加统一兼容适配器，避免重复恢复多个服务卡或引入 Rust 服务端。保留原有结构化阅读解析和隐私边界；配置变化不自动发送当前选中文字。

### 验证

- `swift test --package-path EasyReadKit`：130 项现有测试、11 个 suite 通过。
- `xcodebuild test`（独立 agent DerivedData，`ReverseTranslationTests` 与 `CodexConfigurationMigrationTests`）：最终构建和 16 项现有测试、2 个 suite 通过，退出码 0。
- Xcode 验证遇到 workspace `Package.resolved` 被反复移除，导致致谢资源复制失败。最终运行以临时包装脚本在构建期间恢复原 HEAD 文件的相同字节完成验证，不改变依赖版本。机器同时存在 Xcode IDE 进程，但未证实删除动作的具体进程；该环境问题未作为本任务的工程修复。
- `git diff --check`、`jq -e . EasyRead/App/Localizable.xcstrings`、`plutil -lint EasyRead.xcodeproj/project.pbxproj` 通过；任务 Swift 文件经 SwiftFormat；所有新增 AI 文案包含 en、zh-Hans、zh-Hant、ja、es、sk。
- 按 `review` 技能审查初始 HEAD `d8e5b89809d1d41f430e17f2c0e39a784f5a3658` 到任务工作树的 17 个生产/工程/资源文件，含全部新增文件。初始索引及工作树干净，审查采用文件 SHA-256 快照，修正后复核增量。
- 已修正：Defaults 含点号键名会触发库警告并影响 KVO；完整接口地址带尾斜杠会重复拼接路径；被移除 Google 服务的旧禁用元数据会阻止新插入的普通翻译备用服务工作。最后复验未出现新增 Defaults 键名警告，无未解决 finding。
- 实现方式判断：统一兼容客户端与供应商目录符合本次范围；不需要恢复重复 AI 服务实例。保留旧 DeepSeek 类用于凭证迁移，未重新注册结果卡。
- 手动检查：完成调用链、配置与请求取消路径的静态检查；未进行真实界面交互或所有供应商账号的网络联调。未新增或扩写测试，现有绿色测试不代表新增供应商端到端覆盖。

- 崩溃诊断：2026-10-15 11:32:08 的 SIGTRAP 栈包含 `LocalStorage.service → setupServices → initWithWindowType`。此前窗口测试使用继承的 nib 初始化入口，未覆盖真实服务初始化；没有将测试通过视为该入口已验证。
- 后续 `xcodebuild test` 运行 `ReverseTranslationTests` 与 `AppleSpeechServiceTests`：13 项现有测试、2 个 suite 通过。直接以 `--queryText ""` 启动 Debug 应用，日志确认固定查询窗口成功创建；系统窗口列表记录 480 × 267 窗口，进程持续运行后正常退出。截图未成功，未据此声称完成视觉验收。

- 后续 Release 构建：`bash scripts/build-local-app.sh` 成功，`codesign --verify --deep --strict` 通过；新旧应用 designated requirement 完全一致，备份旧应用后安装回原路径并启动。系统窗口列表确认 Release 查询窗口可见（480 × 447），进程保持运行。重启时曾误启独立 Debug 应用导致辅助功能身份变化，现已退出 Debug 并恢复使用原 Release 身份。
- 后续 Review：基线 `1fe8156ed134656131f98eca158e02b4584cc30f`，5 个生产文件及相关调用链；工作树 SHA-256 快照在审查后保持一致，无未解决 finding。独立朗读创建覆盖全部五种 TTS 类型，避免重新注册已隐藏的翻译卡，当前实现范围和复杂度合适。

### 受影响文件

- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAIProvider.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAIConfiguration.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAIClient.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAISettingsView.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAssistantModel.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAssistantView.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAssistantHostView.swift`
- `EasyRead/Swift/Feature/ReadingAssistant/ReadingAnalysisCache.swift`
- `EasyRead/Swift/Feature/Configuration/Defaults.Keys+Extension.swift`
- `EasyRead/Swift/Service/Model/QueryServiceFactory.swift`
- `EasyRead/Swift/Service/Model/Storage/LocalStorage.swift`
- `EasyRead/Swift/Service/Model/Storage/LocalStorage+ReadingAI.swift`
- `EasyRead/Swift/View/SettingView/SettingView.swift`
- `EasyRead/Swift/View/SettingView/Tabs/ServiceConfigurationView/KeychainInputCell.swift`
- `EasyRead/objc/Service/AudioPlayer/EZAudioPlayer.m`
- `EasyRead/objc/ViewController/View/WordResultView/EZWordResultView.m`
- `EasyRead/objc/ViewController/Window/BaseQueryWindow/EZBaseQueryViewController.m`
- `EasyRead/App/Localizable.xcstrings`
- `EasyRead.xcodeproj/project.pbxproj`
- `docs/exec-plans/completed/2026-10/2026-10-15-reading-ai-providers.md`

### 后续事项

- 使用目标供应商账号，在设置中测试连接并验证结构化阅读结果；模型可用性以账号权限和供应商实际返回为准。
- workspace 锁文件被移除的本机环境问题仍需单独定位。
