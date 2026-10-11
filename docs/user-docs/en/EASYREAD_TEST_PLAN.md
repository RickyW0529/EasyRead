# EasyRead verification and acceptance plan

## Recorded environment

Xcode was installed and initialized later on 2026-10-11: Xcode 27.0 (27A266a),
macOS 27.0.1 arm64. The renamed EasyRead workspace completed a Debug build.
The standard `swift test --package-path EasyReadKit` run passed 130 tests in 11 suites
with the Xcode toolchain, without the earlier CLT workarounds. The selected Xcode
run passed 25 tests across `UtilityFunctionsTests`, `AppleDictionaryTests`,
`ReverseTranslationTests` and `OpenAIStreamTaskControlTests`. All test sources and
the app test host compiled.

The Release configuration later produced a universal ad-hoc `EasyRead.app`
(`x86_64` and `arm64`, bundle id `com.easyread.EasyRead`) with the hardened
runtime. The first `codesign --verify --deep --strict` failed because the
embedded JLRoutes, Masonry and ReactiveObjC frameworks lost their headers after
signing. Re-signing those frameworks and the app made the strict check pass.
The process launched and stayed running, and no new crash report appeared.
That does not establish dictionary, selection or DeepSeek behavior. The build
is not Developer ID signed or notarized.

### Earlier CLT-only run

2026-10-11: macOS 27.0.1 (arm64), Apple Swift 6.1.2, Command Line Tools only.
Full Xcode is not installed. `xcodebuild -version` fails with “requires Xcode”.
SwiftPM's installed manifest interfaces are inconsistent with its library. The
validation run used a repaired PackageDescription module in a temporary module
cache, a temporary shadow Swift resource directory and `--disable-sandbox` to
avoid nested sandbox execution. No installed toolchain file was changed. These
workarounds are machine-specific, not normal build instructions.

The full EasyReadKit suite passed: 130 test functions, including 32 parameterized
sentence samples. Real Keychain tests required access outside the execution sandbox;
the restricted run failed with `KeychainStoreError(status: -50)` and is not recorded
as passing. Offline grammar samples test contracts and evidence preservation;
they do not test live DeepSeek interpretation or real application compatibility.

## Automated commands

With a healthy full Xcode installation, run:

```bash
swift test --package-path EasyReadKit
checkout_id="$(git rev-parse --show-toplevel | sed -e "s|^$HOME/||" -e 's|/|_|g')"
agent_dd="$HOME/Library/Developer/Xcode/DerivedData/Easydict-Agent/$checkout_id"
xcodebuild test -workspace EasyRead.xcworkspace -scheme EasyRead \
  -derivedDataPath "$agent_dd"
git diff --check
plutil -lint EasyRead.xcodeproj/project.pbxproj
jq -e . EasyRead/App/Localizable.xcstrings
```

Use the workspace. Do not run tests alongside an Xcode Run/Test of the same app.
Release/signing/notarization are separate checks. `swiftc -parse` proves syntax,
not AppKit/SwiftUI type compatibility, bridging or application integration.

Covered logic includes sentence boundaries, context limits and sanitization,
sensitive-source rules, stale capture suppression, request shape, HTTP error mapping,
retry budget and cancellation, Keychain roundtrips, word-answer validation, sentence
translation/grammar source matching and prompt injection kept in JSON data.

## Manual acceptance — pending

The build and automated results above do not establish manual acceptance. Use the exact
cases in [specification section 10](../../../DEVELOPMENT_SPEC.md#10-验收用例必须真实执行)
and record OS, app version, selected text category and outcome without private text.

| Cases | Check |
| --- | --- |
| T01, T12 | No key + offline lookup; enabled dictionary result or honest empty state |
| T02, T06 | Sentence card with/without key; translation first, expandable verified grammar |
| T03–T05 | Live DeepSeek `process` and two `bank` meanings; honest source labels |
| T07–T08 | Malformed model output and API failures; dictionary result remains available |
| T09–T11 | Rapid A/B selections, repeated identical words, cancel, Esc/window close, AI off |
| T13, T16 | Native secure subrole, password managers, terminal, exclusions, key restart/delete |
| T14 | Safari, Chrome, Preview, VS Code and Obsidian; AX range support and selection-only fallback |
| T15 | Light/dark appearance, text selection/copy, expanded card, scaling, two displays and edges |
| T17–T19 | Overlong selection, injection text, denied Accessibility permission and manual lookup |
| T20 | Binary-to-source correspondence, licenses and distribution signing |

Specifically test policy changes while waiting: turn context off, add the source app
to exclusions, replace/delete the key, and disable AI. The request must stop and the
card must leave loading state. Test saving a Keychain key enables model discovery.
Inspect logs for key/source/output leakage using dummy data. Never paste a real key
into a command, fixture or issue report.

Builds use `EASYREAD_RELEASE_PACKAGING=YES` to skip the inherited formatting and
lint phases; those phases were not counted as passing. This avoids automatically
formatting unrelated source while producing a trial application.

Screenshots and performance timings remain pending. No live API or cross-application
manual acceptance item is implied by passing offline tests.
