# EasyRead

中文 · [English](README.md)

面向 macOS 的英语阅读助手。遇到不熟悉的词、术语或长难句时，在一个划词面板里完成查词、
翻译和语法理解，减少阅读过程中的来回切换。

## 界面与使用示例

<img src="docs/images/easyread-menu.png" alt="EasyRead 菜单，包含划词、剪贴板和截图翻译入口" width="240">

选中英文后，**点击划词图标**或按 **Option+D**（默认划词快捷键）打开阅读面板。
仅把鼠标移到图标上不会提交查询。快捷键可在设置中修改。

菜单顶部的 **EasyRead + 版本号**打开 [EasyRead 发行页](https://github.com/RickyW0529/EasyRead/releases)，
**帮助 → 反馈**打开 [EasyRead 问题反馈](https://github.com/RickyW0529/EasyRead/issues)。
关于页的 GitHub 与贡献者按钮也指向本仓库。

例如，阅读技术文档时选中这句话：

> The process that handles incoming requests runs in the background.

开启 AI 阅读后，可以在面板中对照译文、理解句子结构。以下为说明性示例，实际输出随所配置的
服务商与模型而变化。

| 面板内容 | 示例 |
| --- | --- |
| 翻译 | 处理传入请求的进程在后台运行。 |
| 主语 | **The process**：被描述的进程。 |
| 定语从句 | **that handles incoming requests**：修饰 process，说明它负责处理传入请求。 |
| 谓语 | **runs**：进程的运行状态。 |
| 状语 | **in the background**：说明在后台运行。 |
| 词典查询 | 单独选中 **process**，用已启用的词典查看释义。 |

## 基于 Easydict 开发与致谢

EasyRead 基于开源项目 [Easydict](https://github.com/tisfeng/Easydict) 开发，沿用了它在
划词捕获、查询窗口、系统词典和翻译服务上的基础能力。感谢 **tisfeng 及所有 Easydict
贡献者**提供这些扎实的开源工作。

EasyRead 在此基础上聚焦英语阅读理解，把词典释义、译文和语法解析放进同一个阅读面板。
本项目是 Easydict 的衍生项目，继续遵循 [GPL-3.0](LICENSE)，保留原有版权声明与
[第三方归属说明](THIRD_PARTY_NOTICES.md)。

## 目标用户是谁？

适合已经有一定英语基础，但阅读时仍会被生词、专业术语和复杂句子打断的 Mac 用户：

- **学生与研究者**：阅读英文论文、教材、课程资料。
- **开发者与专业读者**：阅读技术文档、英文参考资料和行业文章。
- **英语学习者**：不只想知道中文意思，也想看懂句子的组成和表达方式。

只需了解一个词时，可以直接查本地词典；需要理解语境或长句时，再使用 AI 辅助。

## 怎么使用 EasyRead？

### 1. 安装或源码构建

下载 **[v0.1.0 预览版](https://github.com/RickyW0529/EasyRead/releases/tag/v0.1.0)**，
支持 Apple Silicon 芯片及 macOS 13 以上系统。ZIP 和 DMG 包含同一应用，下载页附有 SHA256 校验文件。
该预览版使用开发证书签名，**尚未经过 Apple 公证**，macOS Gatekeeper 可能阻止打开。
详情见[发行说明](docs/user-docs/en/Release-v0.1.0.md)。

也可从源码构建，需要完整 Xcode、macOS SDK 和 CocoaPods：

```bash
git clone https://github.com/RickyW0529/EasyRead.git
cd EasyRead
pod install
open EasyRead.xcworkspace
```

在 Xcode 中选择 **EasyRead** scheme 后运行。固定本机签名身份、安装路径与划词授权的步骤，
见[本地构建指南](docs/user-docs/zh/Local-development-build.md)。

### 2. 先配置本地词典

打开 macOS「词典」App，在设置中勾选需要的词典，等待资源下载完成；再在 EasyRead 的服务设置中
启用「苹果词典」。配置完成后，本地查词不需要 AI API Key，也不依赖网络。

需要划词时，按提示授予辅助功能权限；也可以在查询窗口手动输入。不同应用提供的辅助功能能力
不同，能否取得选中文字取决于来源应用。

### 3. 按需开启 AI 阅读

进入 **设置 → AI 翻译**，选择服务商，按需填写自己的 API Key 并选择模型，点击「测试连接」，
确认可用后开启 AI 阅读。也可以配置自定义接口地址和模型名称。密钥保存在 macOS Keychain 中，
API 的可用性与费用由所选服务决定。

AI 默认关闭。开启后，提交符合条件的查询会自动生成阅读辅助结果。上下文提取在「隐私」设置中
单独开启；开启且成功取得上下文时，有限的周边文本也可能发送给所选 AI 服务。
具体见[隐私与数据流](PRIVACY.md)。

### 4. 在划词面板中阅读

在支持的应用中选中文字，通过已配置的划词操作或快捷键唤起 EasyRead：

- **原文与翻译结果**：对照阅读，译文标题旁可以朗读和复制。
- **句子解析**：原文片段下方有对应语法标签，空间足够时，逐项解释在右侧并排显示。
- **词典**：查看苹果词典及其他已启用词典的释义。
- **其他译文**：对照其他已启用服务的翻译结果。

查询窗口随内容和屏幕可用空间调整尺寸；长内容可以展开或滚动查看，窄窗口会改为上下排版。
AI 请求失败不会阻止独立的本地词典查询。

## 为什么使用 AI 辅助翻译？

译文能告诉你一段话「说了什么」，阅读学习还需要理解「为什么这样表达」。AI 可以帮助连接
原文、词义和句子结构：

- **结合语境理解词义**：例如操作系统文档中的 *process* 通常指「进程」，需要结合上下文
  区分它与日常语言里的其他含义。
- **拆解长难句**：把主语、谓语、修饰成分和插入语对应到原文片段，减少读到句尾却找不到主干的情况。
- **通过对照积累阅读能力**：原文、译文和解释同时保留，看完解释后还能回到英语本身，理解术语和表达。

本地词典适合快速、离线地查定义，AI 则补充词典难以直接提供的解释。AI 也可能理解错误，
重要内容应结合原文核对。

## 参与开发

应用源码位于 `EasyRead/`，应用测试位于 `EasyReadTests/`；上下文和隐私逻辑位于可独立验证的
`EasyReadKit/`。

```bash
swift test --package-path EasyReadKit
```

构建和贡献说明见 [CONTRIBUTING.md](CONTRIBUTING.md)。
