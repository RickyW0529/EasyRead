# EasyRead macOS 阅读助手

中文 · [English](README.md)

EasyRead 是基于 [Easydict](https://github.com/tisfeng/Easydict) 开发的英语阅读助手，
遵循 [GPL-3.0](LICENSE)，目标系统为 macOS 13 及以上。目前处于开发阶段，已通过本地
Xcode 构建，可供试用；正式分发签名、公证与发布尚未完成。

## 使用

1. 在支持的应用中选词，或在查询窗口手动输入。无需 API Key 或网络即可使用 Apple 系统词典；
   需先在 macOS「词典」App 中下载并启用相应词库。
   [系统词典设置](docs/user-docs/zh/How-to-use-macOS-system-dictionary-in-Easydict.md)。
2. 如需 AI，在设置 → 服务 → DeepSeek 中保存自己的 API Key（存入 Keychain），测试连接，
   再主动开启 DeepSeek。API 会按 [DeepSeek 官方规则](https://api-docs.deepseek.com/quick_start/pricing/)
   计费；默认模型为 `deepseek-flash`，阅读操作关闭 thinking，仅访问官方 HTTPS API。
3. 阅读卡提供「解释单词／短语」「翻译句子」「解析句子」。解析成功后先显示中文翻译，
   语法详情按需展开；支持取消、重试、复制。AI 故障不影响独立的本地词典结果。
   句子解析必须点击触发，不自动生成长篇报告。
4. 上下文提取默认关闭。可在设置 → 隐私中开启并配置排除应用。仅通过 Accessibility 读取
   限定范围；不支持时明确降级为仅选中文字，不猜测原句。

AI、自动查询历史与遥测默认关闭；可选本地 MDict 导入与继承的非 AI 翻译服务仍在设置中保留。
V1 唯一可配置 AI 是 DeepSeek。详见 [PRIVACY.md](PRIVACY.md)。

## 权限与限制

辅助功能权限用于划词；拒绝权限后仍可手动输入和访问设置。原生密码字段、密码管理器、
终端及排除应用在选区提取前被拦截。敏感来源识别无法覆盖所有软件，请主动添加排除应用。
Safari、Chrome、Preview、VS Code、Obsidian 暴露的 Accessibility 能力不同，不能保证均可取得
原句。超过 2,000 字符的阅读操作会提示缩小选区，语法片段与原文不符时拒绝展示。
离线测试证明数据契约，不证明 AI 理解一定正确。

已使用 Xcode 27 完成应用构建；跨应用划词、真实 DeepSeek 响应与界面验收仍需试用验证。

## 构建

安装完整 Xcode（含 macOS SDK）和 CocoaPods，配置 `xcode-select` 后在仓库运行：

```bash
pod install
open EasyRead.xcworkspace
```

使用共享 **EasyRead** scheme；源码目录、工程、Swift 模块和 Objective-C 桥接均为 EasyRead。
Debug 构建默认支持本机临时签名，也可配置自己的开发签名团队。首次解析依赖需网络；分发签名、公证仍需单独完成。
纯逻辑验证可运行 `swift test --package-path EasyReadKit`，Keychain 测试仅使用随机测试条目。
完整命令及实际验证记录见 [测试计划](docs/user-docs/en/EASYREAD_TEST_PLAN.md)。

贡献规则见 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [AGENTS.md](AGENTS.md)。
[开发任务书](DEVELOPMENT_SPEC.md)、[架构](docs/design-docs/easyread-reading-flow.md)、
[上游跟进](docs/user-docs/en/EASYREAD_UPSTREAM.md)、[第三方归属](THIRD_PARTY_NOTICES.md)
与 [变更记录](CHANGELOG.md) 描述本 fork 的边界。分发时保留 GPL、上游版权与对应源码。
