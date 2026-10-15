# 阅读助手多供应商与重复入口整合

- 状态：completed
- 创建日期：2026-10-15
- 负责人：Codex
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `Codex`
- **Model:** `GPT-6`
- **Environment:** `macOS 27.0.1 / Xcode 27.0 (27A266a)`

## 背景

阅读助手绑定 DeepSeek，查询窗口另有重复的 DeepSeek 翻译卡。用户要求迁移 BranchReport 的供应商支持并整合入口，再 review。

## 目标与范围

- 目标结果：统一 AI 阅读卡，提供供应商配置与选择，复用旧 DeepSeek 凭证及模型。
- 允许修改路径：阅读助手、服务注册和存储默认值、设置、String Catalog、Xcode 工程、任务文档。
- 同任务 history：`docs/histories/2026-10/2026-10-15-reading-ai-providers.md`
- 用户限制：参考 BranchReport；移除重复 AI 结果入口；开关、供应商和模型下拉框仅放在设置；关闭 AI 后整张阅读助手卡片消失，仅保留普通翻译和词典；完成 review。
- 非目标：迁移 Rust 服务端、报告生成、embedding/rerank；复制源项目的密钥或私有部署地址。
- 验收标准：设置页开关显示“启用 AI 翻译”，供应商与模型均为下拉选择；关闭后无 AI 卡片或 AI 查询；可配置公共供应商和自定义兼容接口；密钥独立存储；变更配置取消旧请求并清缓存；无重复 DeepSeek 卡。

## 工作计划

1. 移植公共供应商目录和兼容请求适配；增加 Keychain 配置、连接验证及模型获取。
2. 接入阅读助手和设置，移除旧服务卡注册，更新所有 locale。
3. 构建及运行现有相关测试；审查请求、隐私、取消和迁移边界。
4. 记录 history、归档 plan、创建本地提交。

## 风险与决策

- BranchReport 使用 Rust/React，移植供应商元数据和适配方式到 Swift，不引入服务端依赖。
- 公共预设使用源项目目录；自定义兼容供应商允许无密钥本地网关。
- 所有凭证保存在 Keychain；请求无缓存、不记录正文、不跟随重定向。
- 默认供应商仍为 DeepSeek，保持既有开关和配置；供应商或配置变更不自动发送文本。
- 遵循仓库规则运行现有测试，不新增或扩写测试。

## 进度

- [x] 现状和参考实现检查；初始 HEAD 为 `d8e5b89809d1d41f430e17f2c0e39a784f5a3658`，工作树干净。
- [x] 实现及六种语言本地化。
- [x] 验证、review、history 与计划归档；按仓库约定交付本地提交。

## 验证

- `swift test --package-path EasyReadKit`：130 项现有测试、11 个 suite 通过。
- `xcodebuild test -workspace EasyRead.xcworkspace -scheme EasyRead -derivedDataPath "$agent_dd" -disableAutomaticPackageResolution -skipPackageUpdates -only-testing:EasyReadTests/ReverseTranslationTests -only-testing:EasyReadTests/CodexConfigurationMigrationTests ENABLE_PREVIEWS=YES`：最终构建和 16 项现有测试、2 个 suite 通过。
- 验证环境存在锁文件被反复移除的问题，导致 `CpResource Package.resolved` 失败；构建期间使用临时包装脚本恢复 HEAD 的相同字节，最终退出码为 0。未修改锁文件内容或依赖版本，未把此环境规避称为工程修复。
- SwiftFormat 仅格式化任务 Swift 文件；`git diff --check`、String Catalog JSON 解析、六种 locale 完整性、工程 plist 检查通过。
- Review：检查任务相对初始 HEAD 的 17 个生产/工程/资源文件及新增文件；修正 Defaults 键名含点号、尾斜杠接口重复拼接、被删除 Google 服务残留禁用元数据的迁移问题；最终无未解决 finding。
- 未验证：各供应商真实账号 API、真实界面人工操作；现有测试不等价于新增供应商端到端覆盖。

## 完成条件

- 范围内实现完成，必要验证和 review 通过，history 更新后归档并本地提交。
