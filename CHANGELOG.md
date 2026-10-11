# Changelog

## Unreleased — EasyRead V1 development

- Forked Easydict at `cfda6e2f`; renamed the product and bundle identifiers to EasyRead.
- Defaulted to Apple Dictionary, with AI and telemetry off; removed the upstream update channel.
- Added bounded, opt-in reading context extraction and sensitive-source exclusions.
- Stored DeepSeek keys in Keychain, with connection testing and classified failures.
- Added structured word/phrase explanations, explicit sentence translation and grammar parsing.
- Validated echoed source text and grammar excerpts; bounded retries, deadlines and cancellation.
- Added a progressive SwiftUI reading card with copy, retry and cancellation.
- Disabled automatic query history by default and removed reading text from active query logs.
- Added offline contract tests and development/privacy/upstream documentation.

App builds, signed artifacts, runtime screenshots and manual compatibility checks
are pending full Xcode verification. No EasyRead release has been published.
