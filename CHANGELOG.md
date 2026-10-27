# Changelog

## v0.1.1 — Explicit selection queries

- Require a click or shortcut to translate selections; hovering no longer submits queries.
- Apply click-to-query behavior regardless of main window visibility and remove the old hover setting.
- Correct menu, feedback and About links to point to the EasyRead repository.
- Simplify both READMEs around an animated AI selection-translation example.

[Download and release notes](https://github.com/RickyW0529/EasyRead/releases/tag/v0.1.1).
Apple Silicon preview, development-signed and not notarized.

## v0.1.0 — First preview

- Developed from Easydict with the EasyRead product and bundle names; retained GPL-3.0 and upstream attribution.
- Added dictionary-first reading with Apple Dictionary and optional local MDict imports.
- Added configurable AI reading providers, API endpoints and models, with keys stored in Keychain.
- Combined original text, translation, dictionary results and sentence analysis in one selection panel.
- Added continuous grammar underlines with labels below them and explanations beside the sentence.
- Made query windows adapt to content and available screen space.
- Added opt-in bounded context extraction, sensitive-source exclusions, cancellation and source-text validation.
- Added standalone context, privacy, transport and grammar tests in EasyReadKit.

- Added invalid-JSON repair, query-owned context and reliable analysis retry.
- Unified displayed, copied and reverse translation results and restored context evidence.
- Protected HTTP selection access with a Keychain-backed Bearer token.
- Fixed the reproduced crash during repeated Apple Dictionary lookups.
- Standardized EasyRead project names and migrated screenshot preference keys.

Apple Silicon preview packages are available from the
[v0.1.0 release](https://github.com/RickyW0529/EasyRead/releases/tag/v0.1.0).
The app is development-signed and not notarized. See the
[release notes](docs/user-docs/en/Release-v0.1.0.md) for requirements and limitations.
