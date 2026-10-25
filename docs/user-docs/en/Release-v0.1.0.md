# ✨ feat: Read with translation, context and sentence structure

EasyRead's first preview release builds on [Easydict](https://github.com/tisfeng/Easydict)
and brings translation, local dictionary lookup and AI reading assistance into one panel.

## What's included

- Selection translation, keyboard shortcuts and screenshot OCR on macOS.
- Local Apple Dictionary and MDict integration, independent of AI availability.
- AI word and phrase explanations with context labels, parts of speech and expandable evidence.
- Sentence analysis with continuous underlines, labels below each fragment and a two-column layout when space permits.
- Configurable AI providers, endpoints and models, with credentials in macOS Keychain.
- Structured JSON validation with up to two format-repair requests when a provider returns an invalid analysis.
- Reliable query-owned context, cancellation and retry behavior, plus consistent displayed and reverse translation results.
- Sensitive-source checks and token-protected HTTP selection access.
- EasyRead naming throughout the project and a fix for the reproduced repeated Apple Dictionary lookup crash.

## Download and install

This preview requires **macOS 13 or later on Apple Silicon (arm64)**.
Download either the DMG or ZIP; both contain the same `EasyRead.app`.
The DMG includes an Applications shortcut. Quit an existing copy before replacing it.
Verify downloads against `SHA256SUMS.txt`.

**Signing:** The app uses an Apple Development signature and has **not been notarized**.
It is not a Developer ID distribution build. macOS Gatekeeper may block the downloaded app;
only open a download whose source and checksum you trust. Building from source is also supported.

Enable the dictionaries you need in macOS Dictionary and allow their downloads to finish.
Grant EasyRead Accessibility permission for selection capture. AI reading and context extraction
are off by default; configure a provider and explicitly enable the features you want.

## Compatibility notes

- App version: `0.1.0`; Git tag: `v0.1.0`; build: `68`.
- `GET /selectedText` requires a token saved under Advanced settings, sent as
  `Authorization: Bearer <token>`. Other translation endpoints retain their existing behavior.
- Screenshot preferences migrate to `easyread.*`. Historical migration inputs and the existing
  external Apple Translation shortcut name remain compatible.
- This release does not enable automatic updates. Download future versions from this repository.

## Validation

Existing core, reading-client, reverse-translation and dictionary tests are run before publishing.
The Release app, ZIP and DMG are verified, and checksums accompany the downloads.

## Acknowledgements

Thank you to **tisfeng and all Easydict contributors**, and to the maintainers of the bundled
open-source libraries. EasyRead remains licensed under [GPL-3.0](../../../LICENSE).
See [third-party notices](../../../THIRD_PARTY_NOTICES.md) and the
[source for v0.1.0](https://github.com/RickyW0529/EasyRead/tree/v0.1.0).
