# 🐞 fix: Translate selections only when you ask

## What's Changed

- Prevent accidental translation when the pointer enters the selection icon. Click the icon or press **Option+D** to submit a query, whether the main window is visible or hidden.
- Remove the old hover-query setting and explain click-to-query behavior in all supported interface languages.
- Point version, feedback, GitHub and contributor links to **EasyRead**, with upstream attribution preserved.
- Add a simple animated AI selection-translation walkthrough to both READMEs. The animation is an illustration with example output, not a screen recording.

## Download and install

Requires **macOS 13 or later on Apple Silicon (arm64)**. Download the ZIP or DMG;
both contain the same `EasyRead.app`. Quit EasyRead before replacing your existing copy.
The DMG includes an Applications shortcut. Verify downloads against `SHA256SUMS.txt`.

**Signing:** Apple Development signature; **not notarized** and not a Developer ID
distribution build. macOS Gatekeeper may block the downloaded app. Building from source
is also supported.

Grant Accessibility permission for selection capture. To use AI reading, configure
a provider and model under **Settings → AI Translation**, test the connection, and enable AI reading.
AI reading and context extraction remain off by default. Existing provider settings are retained.

## Version and validation

- App version: `0.1.1`; Git tag: `v0.1.1`; build: `69`.
- Release build, signature, ZIP and DMG integrity verified before publishing.
- The selection and reading fixes passed 18 existing query and reading-client tests.
- Automatic updates remain disabled. Download updates from this repository.

## Acknowledgements

Built on [Easydict](https://github.com/tisfeng/Easydict). Thank you to tisfeng and all
Easydict contributors. EasyRead remains licensed under
[GPL-3.0](https://github.com/RickyW0529/EasyRead/blob/v0.1.1/LICENSE).

[Full changelog](https://github.com/RickyW0529/EasyRead/compare/v0.1.0...v0.1.1)
