# EasyRead

中文 · [English](README.md)

选中英文，用 AI 读懂。

面向 macOS 的英语阅读助手。选中文字，在原文旁查看译文与句子解析，不打断阅读。

![选中英文、按 Option+D、查看 AI 译文](docs/images/ai-selection-translation.gif)

*交互示意动图，使用示例结果，并非屏幕实录；实际 AI 输出因服务商与模型而异。*

## 开始使用

[下载 v0.1.1](https://github.com/RickyW0529/EasyRead/releases/tag/v0.1.1)
· macOS 13 及以上 · Apple Silicon

1. 打开 **设置 → AI 翻译**，配置服务商与模型，测试连接后开启 AI 阅读。
2. 选中英文，按 **Option+D** 或点击划词图标。
3. 对照原文阅读译文，通过句子解析理解语法结构。

仅把鼠标移到划词图标上不会提交查询。快捷键可以在设置中修改。
按提示授予辅助功能权限后，即可在支持的应用中划词。

AI 阅读默认关闭。密钥保存在 macOS Keychain，API 费用由所选服务商决定；
上下文提取需单独开启。详见[隐私与数据流](PRIVACY.md)。

ZIP 与 DMG 包含相同应用。当前预览版使用开发证书签名，**尚未经过 Apple 公证**，
macOS Gatekeeper 可能阻止打开。安装说明与校验方式见[发行说明](docs/user-docs/en/Release-v0.1.1.md)。

## 源码构建

安装 Xcode 与 CocoaPods 后运行：

```bash
git clone https://github.com/RickyW0529/EasyRead.git
cd EasyRead
pod install
open EasyRead.xcworkspace
```

选择 **EasyRead** scheme 运行。开发与测试见 [CONTRIBUTING.md](CONTRIBUTING.md)，
本机签名和划词授权见[本地构建指南](docs/user-docs/zh/Local-development-build.md)。

## 致谢

基于 [Easydict](https://github.com/tisfeng/Easydict) 开发。
感谢 **tisfeng 及所有 Easydict 贡献者**在划词、词典和翻译能力上的开源工作。

EasyRead 继续遵循 [GPL-3.0](LICENSE)，保留上游版权及[第三方归属说明](THIRD_PARTY_NOTICES.md)。
