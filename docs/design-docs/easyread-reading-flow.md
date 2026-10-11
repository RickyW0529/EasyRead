# EasyRead reading flow

EasyRead reuses Easydict's selection workflow, query windows, Apple Dictionary and
service framework. The local `EasyReadKit` SwiftPM package owns Foundation/Security
logic that can be verified without building the full application.

1. `SelectionWorkflow` checks sensitive applications and secure AX subroles before
   each selection strategy, then creates a fresh in-memory selection identity.
2. `ContextExtractionCoordinator` stores a selection-only placeholder immediately.
   Opt-in AX capture reads a bounded string range. `SelectionContextStore` accepts
   completion only for the still-current identity and source application.
3. `QueryModel` attaches context only to selection-triggered queries. Local dictionary
   results use the existing independent service rows. Manual/OCR input never borrows
   a previous identical word's context.
4. `DeepSeekService` provides opt-in structured automatic word explanation. It rereads
   the current snapshot at request assembly, classifies API errors and suppresses
   cancelled or stale results. The endpoint remains the official HTTPS endpoint.
5. `ReadingAssistantHostView` embeds a SwiftUI card as a separate row before service
   results. `ReadingAssistantModel` handles explicit word/phrase, translation and
   grammar intents. Its request identity, task cancellation and selection identity
   prevent stale answers from updating the card.
6. `DeepSeekChatClient` sends non-streaming JSON with thinking disabled. The ephemeral
   transport has a total monotonic deadline, per-attempt timeouts and at most two
   bounded backoff retries. Model IDs come from `DeepSeekModel` in the app.
7. `AIWordExplanation`, `SentenceTranslation` and `GrammarExplanation` validate model
   output before display. Original-text echo allows whitespace normalization only;
   each grammar excerpt must be a source substring. Oversized or incomplete responses
   fail safely. Translation stays visible if a later grammar action fails.

Keys live in Keychain; a non-sensitive revision marker drives settings updates and
cancels requests on key replacement/removal. AI/context/exclusion policy changes cancel
in-flight reading requests. Window-close callbacks cancel the independent reading task.
Automatic recent-query persistence is separately opt-in. See [privacy](../../PRIVACY.md)
and [verification](../user-docs/en/EASYREAD_TEST_PLAN.md).
