# Upstream and source tracking

EasyRead is a GPL-3.0 derivative of [tisfeng/Easydict](https://github.com/tisfeng/Easydict).
Its baseline is upstream `dev` at `cfda6e2f`; the local task branch is `easyread-v1`.
Existing source copyright headers and dependency licenses remain intact.

Phase 1 was recorded in `bb3fdb67`, and Phase 2 in `70b274e2`. Later local changes
add DeepSeek BYOK reading actions, validation and privacy controls. The development
specification is [DEVELOPMENT_SPEC.md](../../../DEVELOPMENT_SPEC.md).

Upstream service classes are retained for shared-code compatibility. The registration
surface limits AI to DeepSeek and defaults to Apple Dictionary. Product and bundle
names are EasyRead; workspace, scheme and Swift module retain Easydict names.
The upstream automatic update feed is disabled to prevent installing Easydict over
this fork. Upstream links identify the source project, not a published EasyRead release.

When following upstream, fetch and review changes explicitly, then integrate only
approved commits in a separate task branch. Check selection APIs, ObjC/Swift bridges,
service defaults, local package linkage, licensing and the disabled update channel.
Do not copy upstream secrets or restore default telemetry, AI providers or update feeds.
No push, remote repository creation, release or notarization was performed by this task.
