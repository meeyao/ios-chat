---
phase: 04-emotes-badges-ecosystem
verified: 2026-02-06T07:10:25Z
status: gaps_found
score: 11/12 must-haves verified
gaps:
  - truth: "Provider outages degrade gracefully using last-known cache and emit a banner/toast event"
    status: failed
    reason: "Outage events are recorded but no UI consumes them for banner/toast presentation."
    artifacts:
      - path: "Sources/DankChatCore/Services/ProviderStatusStore.swift"
        issue: "Stores outages only; no presentation layer wired."
      - path: "Sources/DankChatApp/DankChatApp.swift"
        issue: "Injects ProviderStatusStore into environment but no view displays outages."
    missing:
      - "UI component observing providerStatusStore.outages to present a banner/toast"
      - "Wiring in chat layout to surface outage events to the user"
---

# Phase 4: Emotes + Badges Ecosystem Verification Report

**Phase Goal:** Emote and badge rendering matches DankChat including 7TV/BTTV/FFZ with caching and UI tools.
**Verified:** 2026-02-06T07:10:25Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | App configures image pipeline (WebP enabled) on launch | ✓ VERIFIED | `Sources/DankChatApp/DankChatApp.swift:10` calls `ImagePipeline.configure()`, WebP coder configured in `Sources/DankChatApp/ImagePipeline/ImagePipeline.swift`. |
| 2 | Incoming IRC PRIVMSG events carry enough metadata to render Twitch emotes and badges | ✓ VERIFIED | `Sources/DankChatCore/Chat/ChatMessageMapper.swift:47` parses `emotes` and `badges` tags into `ChatMessage`. |
| 3 | App can fetch and cache emote sets for Twitch/BTTV/FFZ/7TV per channel | ✓ VERIFIED | `Sources/DankChatCore/Emotes/EmoteStore.swift` loads global/channel emotes; `Sources/DankChatApp/DankChatApp.swift:436` calls `loadChannelEmotes`. |
| 4 | Provider outages degrade gracefully using last-known cache and emit a banner/toast event | ✗ FAILED | `Sources/DankChatCore/Services/ProviderStatusStore.swift` records outages, but no UI consumes `outages` for banner/toast display. |
| 5 | Chat messages render inline emotes with correct wrapping and spacing rules | ✓ VERIFIED | `Sources/DankChatApp/UI/Chat/RichText/ChatRichTextBuilder.swift` inserts zero-width wrap spacers and inline attachments. |
| 6 | Animated emotes can be disabled via a setting | ✓ VERIFIED | `Sources/DankChatCore/Chat/ChatSettings.swift` includes `allowAnimatedEmotes`; wired in `Sources/DankChatApp/UI/Chat/ChatSettingsView.swift` and `Sources/DankChatApp/UI/Chat/RichText/ChatRichTextView.swift`. |
| 7 | Badges render before usernames with Twitch-first ordering | ✓ VERIFIED | `Sources/DankChatApp/UI/Chat/ChatMessageRow.swift:21` renders badges before username and sorts by provider order. |
| 8 | Users can toggle visibility of badge categories/providers globally | ✓ VERIFIED | `Sources/DankChatCore/Badges/BadgeVisibilitySettings.swift` + `Sources/DankChatApp/UI/Chat/ChatSettingsView.swift` toggles. |
| 9 | User can open an emote menu bottom sheet and insert an emote into the composer without sending | ✓ VERIFIED | `Sources/DankChatApp/UI/Chat/ChatComposerView.swift:57` presents `EmoteMenuSheet` and uses `insertText` without sending. |
| 10 | Menu has tabs, always-visible search, and a recents list limited to ~20 | ✓ VERIFIED | `Sources/DankChatApp/UI/Emotes/EmoteMenuSheet.swift` shows tabs + search; `Sources/DankChatCore/Emotes/EmoteRecentsStore.swift:27` limit 20. |
| 11 | Emote suggestions appear for ':' and word-prefix typing and can be accepted via tap | ✓ VERIFIED | `Sources/DankChatApp/UI/Chat/ChatComposerView.swift:79` computes suggestions; `Sources/DankChatApp/UI/Emotes/EmoteSuggestionsView.swift` uses tap buttons. |
| 12 | Accepting a suggestion replaces the current token and inserts a trailing space without sending | ✓ VERIFIED | `Sources/DankChatApp/UI/Chat/ChatComposerView.swift:127` uses `EmoteTokenization.replacingToken(..., appendSpace: true)`. |

**Score:** 11/12 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `Package.swift` | SDWebImage + WebP coder dependencies | ✓ VERIFIED | Dependencies and target products present. |
| `Sources/DankChatApp/ImagePipeline/ImagePipeline.swift` | Central SDWebImage/WebP configuration | ✓ VERIFIED | Registers WebP coder and cache sizing. |
| `Sources/DankChatCore/Emotes/Twitch/TwitchEmoteTagParser.swift` | Parse Twitch emotes tag | ✓ VERIFIED | Substantive parser used by mapper. |
| `Sources/DankChatCore/Badges/Twitch/TwitchBadgeTagParser.swift` | Parse Twitch badges tag | ✓ VERIFIED | Substantive parser used by mapper. |
| `Tests/DankChatCoreTests/TwitchTagsParsingTests.swift` | Emote/badge parsing tests | ✓ VERIFIED | Tests cover empty + multi-range cases. |
| `Sources/DankChatCore/Emotes/EmoteStore.swift` | Unified emote registry + resolve API | ✓ VERIFIED | Provider fetch + resolve APIs, channel/global cache. |
| `Sources/DankChatCore/Badges/BadgeStore.swift` | Unified badge registry + resolve API | ✓ VERIFIED | Twitch badge resolution via parsed tags. |
| `Sources/DankChatCore/Services/ProviderStatusStore.swift` | Outage events surfaced to UI | ⚠️ PARTIAL | Records outages but no UI surface found. |
| `Sources/DankChatApp/UI/Chat/RichText/ChatRichTextView.swift` | UIKit-backed renderer | ✓ VERIFIED | Uses `UITextView` with emote attachment loading. |
| `Sources/DankChatApp/UI/Chat/RichText/ChatRichTextBuilder.swift` | Inline emote builder | ✓ VERIFIED | Spacing rules + emote resolution implemented. |
| `Sources/DankChatCore/Badges/BadgeVisibilitySettings.swift` | Badge visibility toggles | ✓ VERIFIED | Global/provider/category toggles persisted. |
| `Sources/DankChatApp/UI/Chat/BadgeView.swift` | Badge view + tap-to-name | ✓ VERIFIED | Uses alert with badge name. |
| `Sources/DankChatApp/UI/Emotes/EmoteMenuSheet.swift` | Emote menu bottom sheet | ✓ VERIFIED | Tabs, search, recents implemented. |
| `Sources/DankChatCore/Emotes/EmoteRecentsStore.swift` | Recents tracking | ✓ VERIFIED | Persisted, limited to 20. |
| `Sources/DankChatCore/Emotes/Suggestions/EmoteSuggestionEngine.swift` | Suggestion ranking | ✓ VERIFIED | Prefix + fuzzy matching. |
| `Sources/DankChatApp/UI/Emotes/EmoteSuggestionsView.swift` | Suggestions UI | ✓ VERIFIED | Tap-to-accept list. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Sources/DankChatApp/DankChatApp.swift` | `Sources/DankChatApp/ImagePipeline/ImagePipeline.swift` | `ImagePipeline.configure()` | ✓ WIRED | Called during app init. |
| `Sources/DankChatCore/Chat/ChatMessageMapper.swift` | `Sources/DankChatCore/Emotes/Twitch/TwitchEmoteTagParser.swift` | IRC tag parsing | ✓ WIRED | Parser used in PRIVMSG mapping. |
| `Sources/DankChatCore/Chat/ChatMessageMapper.swift` | `Sources/DankChatCore/Badges/Twitch/TwitchBadgeTagParser.swift` | IRC tag parsing | ✓ WIRED | Parser used in PRIVMSG mapping. |
| `Sources/DankChatApp/DankChatApp.swift` | `Sources/DankChatCore/Emotes/EmoteStore.swift` | StateObject injection | ✓ WIRED | Instantiated and environment-injected. |
| `Sources/DankChatApp/UI/Chat/ChatMessageRow.swift` | `Sources/DankChatApp/UI/Chat/RichText/ChatRichTextView.swift` | SwiftUI wrapper | ✓ WIRED | Rich view used for message text. |
| `Sources/DankChatApp/UI/Chat/ChatMessageRow.swift` | `Sources/DankChatCore/Badges/BadgeStore.swift` | Badge resolution | ✓ WIRED | Resolves + filters badges. |
| `Sources/DankChatApp/UI/Chat/ChatComposerView.swift` | `Sources/DankChatApp/UI/Emotes/EmoteMenuSheet.swift` | `.sheet` presentation | ✓ WIRED | Sheet presented on button. |
| `Sources/DankChatApp/UI/Chat/ChatComposerView.swift` | `Sources/DankChatCore/Emotes/Suggestions/EmoteSuggestionEngine.swift` | Suggestions engine | ✓ WIRED | Engine used for suggestions. |
| `Sources/DankChatApp/DankChatApp.swift` | Provider outage UI | Banner/toast | ✗ NOT_WIRED | No view consumes `providerStatusStore.outages`. |

### Requirements Coverage

| Requirement | Status | Blocking Issue |
| --- | --- | --- |
| EMOTE-01 | ✓ SATISFIED | — |
| EMOTE-02 | ✓ SATISFIED | — |
| EMOTE-03 | ✓ SATISFIED | — |
| EMOTE-04 | ✓ SATISFIED | — |
| EMOTE-05 | ✓ SATISFIED | — |
| EMOTE-06 | ✗ BLOCKED | Inline emote failures lack text fallback in `Sources/DankChatApp/UI/Chat/RichText/ChatRichTextView.swift`. |
| EMOTE-07 | ✓ SATISFIED | — |
| EMOTE-08 | ✗ BLOCKED | Username color not applied in `Sources/DankChatApp/UI/Chat/ChatMessageRow.swift`. |

### Anti-Patterns Found

None detected in the reviewed Phase 4 files.

### Human Verification Required

1. Emote and badge visual parity
   - Test: Load a channel with Twitch/7TV/BTTV/FFZ emotes and badges.
   - Expected: Inline emotes align with text, spacing collapses between adjacent emotes, badges appear before usernames with correct ordering.
   - Why human: Visual layout and animation behavior cannot be confirmed via static analysis.

2. Emote menu UX
   - Test: Open the emote menu, verify tab order, search persistence, recents limit, and insertion behavior.
   - Expected: Tabs order matches spec, search always visible, recents capped ~20, selection inserts without sending.
   - Why human: Sheet sizing and interaction must be observed in UI.

3. Suggestions UX
   - Test: Type ':' and word prefixes, tap a suggestion.
   - Expected: Suggestions appear, replace token, append space, and do not send.
   - Why human: UI timing and interaction require runtime verification.

### Gaps Summary

Provider outage events are recorded but never surfaced to the UI, so the "banner/toast" requirement is not achieved. Additionally, EMOTE-06 and EMOTE-08 requirements remain blocked: inline emote failures lack a text fallback and username colors are not applied.

---

_Verified: 2026-02-06T07:10:25Z_
_Verifier: OpenCode (gsd-verifier)_
