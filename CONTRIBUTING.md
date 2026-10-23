# 贡献指南

欢迎为 EasyRead 提交缺陷报告、文档改进和代码修复。

## 开始开发

安装完整 Xcode、macOS SDK 和 CocoaPods，在仓库根目录执行：

```bash
pod install
open EasyRead.xcworkspace
```

使用 **EasyRead** scheme。`BuildTools/` 提供格式化工具，`Pods/` 保留 CocoaPods 依赖；
`scripts/codex-runtime/` 是工程会打包的运行时资源准备工具。首次构建需要联网解析依赖。
本机签名和权限设置见[本地构建指南](docs/user-docs/zh/Local-development-build.md)。

## 验证改动

- 纯文档改动检查相对链接及 `git diff --check`。
- Foundation/Security 逻辑可以运行 `swift test --package-path EasyReadKit`。
- 应用源码或工程改动使用 Xcode 构建，并运行直接覆盖修改行为的现有测试。
- 界面改动附实际截图，说明验证环境及尚未验证的场景。
- Keychain 测试使用随机测试条目，不要把真实 API Key 放进测试或日志。

应用源码在 `EasyRead/`，应用测试在 `EasyReadTests/`，可独立测试的逻辑在 `EasyReadKit/`。

## 提交改进

在 [EasyRead Issues](https://github.com/RickyW0529/EasyRead/issues) 提供复现步骤、系统版本和可公开的截图。
较大的功能先讨论目标；Pull Request 向本仓库 `main` 提交，每个 PR 聚焦一项改动，说明用途、
主要变化与验证结果。

请保留原有版权、[GPL-3.0 许可证](LICENSE)与[第三方归属](THIRD_PARTY_NOTICES.md)，不要提交
本地配置、构建产物、密钥、阅读内容或个人 AI 工具资料。
