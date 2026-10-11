# EasyRead for macOS

[中文](README_ZH.md) · English

EasyRead is a dictionary-first English reading assistant forked from
[Easydict](https://github.com/tisfeng/Easydict), licensed under [GPL-3.0](LICENSE).
It targets macOS 13 and later. This fork is under development. Local Xcode builds
are available for testing; a distribution-signed and notarized release has not been published.

## Reading workflow

- Select a word in a supported app, or enter it manually in the query window.
  Apple Dictionary works without an API key or a network connection when the
  appropriate dictionaries are installed and enabled in Apple's Dictionary app.
  [Dictionary setup](docs/user-docs/en/How-to-use-macOS-system-dictionary-in-Easydict.md).
- DeepSeek is the only configurable AI provider. In Settings → Services → DeepSeek,
  save your own API key to the macOS Keychain, test the connection, then explicitly
  enable DeepSeek. API use incurs charges under [DeepSeek's pricing](https://api-docs.deepseek.com/quick_start/pricing/).
  The default model is `deepseek-flash`; requests use the official HTTPS API with
  thinking disabled for reading actions.
- Click **Explain word / phrase**, **Translate sentence**, or **Parse sentence** in
  the reading card. Grammar details stay collapsed after a successful analysis.
  Cancel, retry and copy controls are available. Dictionary results remain independent
  when AI fails. Sentence parsing always requires a click.
- Context extraction is off by default. Enable it in Settings → Privacy if desired.
  Only a bounded Accessibility text range is read; unsupported sources degrade to
  selected text only. Source labels distinguish actual context from word-only answers.
- AI, automatic query history and telemetry are off by default. Optional local MDict
  imports and inherited non-AI translation services remain available in settings.
  See [privacy and data flow](PRIVACY.md).

## Permissions and limitations

Accessibility permission enables selection capture. Without it, manual input and
settings remain available. Native secure text fields, password managers, terminals
and user-excluded apps are blocked before selection extraction. Detection is best
effort; add sensitive apps to the exclusion list.

Safari, Chrome, Preview, VS Code and Obsidian expose different Accessibility APIs.
No guarantee is made that an original sentence can be obtained from every app.
Selections exceeding 2,000 characters are rejected by reading actions. Grammar
excerpts must match the selected sentence; an invalid response is rejected.
Offline contract tests do not establish AI semantic accuracy.

Screenshots and cross-application compatibility results remain pending; upstream
Easydict screenshots are not presented as verified screenshots of this fork.

## Build and verify

Install full Xcode with the macOS SDK and CocoaPods, then select Xcode in
`xcode-select`. From the checkout:

```bash
pod install
open EasyRead.xcworkspace
```

Use the shared **EasyRead** scheme. The source directory, module, workspace and
Objective-C bridge use the EasyRead name. Debug builds support local ad hoc signing;
configure your development signing team if needed. Downloading dependencies
requires network access; distribution signing and notarization require separate work.

The Foundation/Security logic can be tested independently:

```bash
swift test --package-path EasyReadKit
```

Keychain tests use unique temporary test items, never your application key.
See the [test plan and actual verification record](docs/user-docs/en/EASYREAD_TEST_PLAN.md)
for Xcode commands and the current validation results.

## Contribute and attribution

Read [CONTRIBUTING.md](CONTRIBUTING.md), [AGENTS.md](AGENTS.md) and the
[development specification](DEVELOPMENT_SPEC.md). Report reproducible bugs without
keys or private reading text. See [upstream tracking](docs/user-docs/en/EASYREAD_UPSTREAM.md),
[third-party notices](THIRD_PARTY_NOTICES.md), [architecture](docs/design-docs/easyread-reading-flow.md)
and [changelog](CHANGELOG.md). Preserve the license, upstream copyrights and the
corresponding-source obligations when distributing derivatives.
