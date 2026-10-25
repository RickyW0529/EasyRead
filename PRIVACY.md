# EasyRead privacy and data flow

AI reading and context extraction are off by default. Installed local Apple
Dictionary resources work without an AI key or a network connection. Other enabled
translation, speech or online services have their own network behavior.

## Selection and context

Selection capture uses the application's selection and shortcut flow. Sensitive
application rules, native secure-field checks and user exclusions are applied before
selection extraction. These checks cannot identify every private page or field.
Manual input remains available without Accessibility permission.

The optional local HTTP server's `GET /selectedText` endpoint requires a separate
access token saved in **Settings → Advanced → HTTP Server**. Send it as
`Authorization: Bearer <token>`; unset, deleted or incorrect tokens return HTTP 401.
The token is stored in Keychain. This endpoint applies the same sensitive-app and
secure-field checks as selection capture and discards results if the foreground
application changes during capture. Other HTTP translation endpoints are unchanged.

When context extraction is enabled, Accessibility is asked for a bounded text range
around the selection, up to 300 UTF-16 units on either side. Unsupported APIs fall
back to the selection alone. Context is capped at 600 characters; URLs, email
addresses and absolute paths are masked on a best-effort basis. The source bundle
identifier stays local. This processing does not make arbitrary text anonymous.

## AI requests

Once AI reading is enabled and configured, submitting a supported query can
automatically send the selected text to the configured provider. Limited surrounding
text may also be included when context extraction is enabled and available. Reading
requests reject selections over 2,000 characters. Closing the query or cancelling
an operation cancels its reading task; request identities prevent stale results
from replacing a newer query.

The AI Translation settings choose the provider, endpoint and model. Built-in presets
use HTTPS; custom endpoints accept HTTP or HTTPS. The configured service receives
the request text and, when configured, a Bearer API key. Its processing, retention,
availability and charges depend on that service. EasyRead does not operate an
account server or translation proxy.

The reading client uses an ephemeral URLSession without disk HTTP caching or cookie
storage and does not follow redirects. Requests do not include tools or file-upload
capabilities. Reading text is treated as data, and grammar excerpts are checked
against the original text before display.

## Keys and local data

Provider API keys are stored in macOS Keychain. A non-sensitive revision marker
notifies the interface when a key changes. Legacy DeepSeek preferences have a
migration path into Keychain. Backups may contain old preferences from before
migration.

Selection snapshots and reading analysis are held in memory. The reading cache is
bounded and cleared when relevant AI or privacy configuration changes. Automatic
recent-query history is off by default; enabling it stores queries and results
locally. Favorites and the optional vocabulary notebook also store user-selected
content locally. Removing a key does not remove saved reading entries.

## Diagnostics and permissions

Telemetry and crash reporting are off by default. Development logs can contain
query text from inherited diagnostic paths; they should not be treated as fully
anonymous. Check logs before sharing them and remove private content and credentials.

Accessibility enables selection capture. Screenshot OCR is a separate user-triggered
feature. Application permissions and selection support depend on macOS and the
source application; no complete document is collected as reading context.
