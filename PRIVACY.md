# EasyRead privacy and data flow

AI and context extraction are off by default. Local Apple Dictionary queries do
not require a DeepSeek key. User-selected non-AI online translation or speech
services inherited from Easydict have their own network behavior; they are not
required for offline dictionary lookup.

## What is read and sent

Selection capture runs through the inherited selection/shortcut flow. Sensitive
apps and native secure fields (including the secure subrole) are blocked before
Accessibility, browser or clipboard fallback selection reads. User exclusions are
checked again before an AI action. These lists cannot identify every sensitive app
or private webpage; configure exclusions and avoid selecting secrets.

When context extraction is enabled, the app asks Accessibility for a bounded text
range around the selection (up to 300 UTF-16 units on either side). It never reads
AXValue as an entire document for context capture. Unsupported range APIs degrade
to selection-only. The context sent to AI is capped at 600 characters and masks
URLs, email addresses and absolute paths. The source bundle identifier remains
local. Masking is best effort and does not make arbitrary source text anonymous.

Explicit word/phrase actions send the selection and, if enabled and available,
limited context. Sentence translation and grammar actions send only the selection.
Selections over 2,000 characters are rejected by reading actions. Automatic AI
word queries require both the master AI switch and the service's automatic-query
setting; sentences are parsed only on a click. API messages contain no tools or
file-upload capability. Quoted reading text is treated as untrusted prompt data;
grammar evidence is checked against the original before display.

Requests use `https://api.deepseek.com` and an ephemeral URLSession without disk
HTTP caching or cookies. Redirects to other hosts or HTTP are refused. DeepSeek
receives the payload and the API key in the Authorization header. Its processing,
retention and billing are governed by its own policies. EasyRead does not operate
an account server or proxy.

## API key and local storage

DeepSeek keys are saved only by an explicit save action to a non-synchronizing,
this-device Keychain item accessible while unlocked. A legacy plaintext preference
is migrated into Keychain and cleared after a successful migration. Migration
failure retains the legacy value for a later retry; the app does not use that
plaintext value to make requests. A non-sensitive revision/presence marker drives
UI updates. Deletion errors are reported; deletion or disabling AI cancels reading
requests. Restoring old backups may restore previously stored plaintext settings.

Selection context and sentence-analysis results stay in memory and are replaced
on a new query. Automatic recent-query history is off by default; enabling it
stores query text and results locally in preferences. Explicit favorites and the
optional vocabulary notebook remain user-controlled local storage. Deleting a key
does not delete favorites/history. Remove saved entries separately when needed.
The app does not save complete pages or documents as reading context.

## Logs and permissions

Reading transport/schema failures log anonymous codes or validation field names,
not keys, original sentences or model output. Active selection/query log calls
that included reading text have been removed. Telemetry and crash reporting are
off by default. Inherited optional online features and diagnostics should still be
reviewed before enabling them on sensitive material. The repository contains no
real API key; offline transport tests use dummy keys.

Accessibility permission is optional for application startup and manual lookup.
OCR is inherited and user-triggered; it is not used as an automatic context fallback.
EasyRead has no cloud synchronization. Distribution builds, permission handling in
real apps and end-to-end privacy behavior still need the runtime checks listed in
the test plan.
