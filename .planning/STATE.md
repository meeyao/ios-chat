# Project State

**Project:** DankChat/Chatterino iOS Port
**Last updated:** 2026-02-07T17:43Z

## Project Reference

### Core Value

DankChat users can switch to iOS without losing any features or behavior they rely on.

### Current Focus

**Active Phase:** Phase 6 - Highlights + Notifications

**Next Milestone:** Phase 6 - Highlights + Notifications

**Blockers:** Build verification pending (swift toolchain unavailable in this environment)

## Current Position

**Phase:** 5 of 8 (Social + Moderation)

**Current Plan:** 7 of 7 complete

**Status:** Phase complete

**Last activity:** 2026-02-07 - Completed 05-07-PLAN.md

**Progress Bar:** ``██████████ 100%`` (24/24 plans complete)

## Performance Metrics

**Requirements:**
- Parity checklist tracked in `.planning/PARITY.md`

**Phases:**
- Total: 8
- Completed: 4
- In Progress: 0
- Blocked: 0

## Accumulated Context

### Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 1:1 parity with DankChat | Preserve all features/behaviors for iOS | Pending implementation |
| iOS 16+ universal app | Modern APIs with iPhone + iPad coverage | Constraint for all phases |
| Native URLSession + URLSessionWebSocketTask | No third-party networking dependency | Simpler stack, fewer dependencies |
| Swift 6.1.2 with SPM | Modern concurrency and package management | Build infrastructure choice |
| SDWebImage cache caps (300 MB disk / 100 MB memory) | Prevent unbounded cache growth for emote assets | Applied in ImagePipeline.configure() |
| Emote/badge stores injected via environment objects | Keep wiring isolated to app shell without UI changes | Applied in DankChatApp.ContentView |
| Default emote recents ordering to most recent | Match expected initial menu behavior | Applied in EmoteMenuSettings |
| UITextView data detectors for rich text links | Preserve tappable links in message renderer | Applied in ChatRichTextView |
| Zero-width wrap points between adjacent emotes | Preserve wrapping when collapsing spaces | Applied in ChatRichTextBuilder |
| Shared badge visibility settings (UserDefaults) | Provide global badge toggles across channels | Applied in BadgeVisibilitySettings |
| Badge name display via tap alert | Minimal badge identification UX | Applied in BadgeView |
| Skip swift build verification in container | Swift toolchain unavailable in this environment | Noted for 04-08 verification |
| Relaxed Sendable on HelixAPIClient | Match existing TwitchEmoteProvider closure pattern | Applied in HelixAPIClient + HelixUsersService |
| convertFromSnakeCase key decoding in Helix client | Auto-map Helix snake_case fields to Swift camelCase | Applied in HelixAPIClient.execute() |
| Centralized default OAuth scopes in HelixScope | Single source of truth for scope constants | Applied in AppConfiguration |
| ReplyMetadata keyed on reply-parent-msg-id presence | Nil when absent, avoids false positives | Applied in ChatMessageMapper |
| Classifier checks userId first for reply detection | Most reliable identity match | Applied in SocialMessageClassifier |
| isMention falls back to defaultNick when identity nil | Backward compatible mention detection | Applied in ContentView.isMention |
| SocialTabStore shares ChatSettings scrollback limits | Consistent memory bounds across stores | Applied in SocialTabStore init |
| EventSub WebSocket via URLSessionWebSocketTask | Consistent with IRCWebSocketClient pattern; no new deps | Applied in EventSubClient |
| Whisper delivery uncertainty UX | Twitch may silently drop whispers; UX must not mislead | Applied in WhisperBubble |
| Conversations keyed by Twitch user ID | User IDs stable; login/display names can change | Applied in WhisperStore |
| EventSub auto-start on identity availability | Identity store onChange avoids duplicate lifecycle code | Applied in ContentView |
| Shared UserProfileStore as environmentObject | Consistent with WhisperStore pattern; reloaded per popup | Applied in ContentView + ChatMessageRow |
| Custom CodingKeys for HelixUserProfile description | Helix 'description' field conflicts with Swift protocol; mapped to userDescription | Applied in HelixUserProfileService |
| Channel login as followage channelId (graceful degradation) | Channel model stores logins not numeric IDs; followage degrades until resolved | Applied in UserProfileStore |
| Paginated block list fetch | Users may have large block lists; loop through all pages | Applied in HelixBlockService |
| ModerationContext environmentObject | Wrap moderation services + channelStore for view injection | Applied in ContentView + ChatMessageRow |
| Shared ChannelStore for moderation feedback | Single instance ensures timeline feedback appears correctly | Applied in ContentView init refactor |
| SystemMessageKind.moderation | Distinguish moderation feedback from IRC notices | Applied in ChatEvent + ChannelStore |
| Context menu for moderation actions | Long-press follows platform convention, keeps row clean | Applied in ChatMessageRow |
| RoomStateParser merges partial ROOMSTATE updates | Twitch sends partial updates when a single mode changes; merge prevents loss of existing fields | Applied in RoomStateParser + ChatSession |
| Custom Encodable for HelixChatSettingsPatch | Helix PATCH endpoint expects missing keys for unchanged fields, not null values | Applied in HelixChatSettingsService |
| RoomState stored in ChannelState | Co-locates room state with other per-channel metadata | Applied in ChannelState + ChannelStore |
| toRoomState() on HelixChatSettings | Bidirectional sync: IRC populates initial state, Helix confirms updates | Applied in HelixChatSettingsService |
| Supinic Android API contract for command suggestions | Match DankChat Android provider endpoints and payloads | Applied in CommandSuggestionsClient |

### Technology Stack

**Core:**
- Swift 6.1.2
- Xcode 16.x
- SwiftUI + UIKit hybrid
- URLSession + URLSessionWebSocketTask

**Third-party Libraries:**
- SDWebImage 5.21.5 (image loading + caching)
- SDWebImageWebPCoder 0.15.0 (WebP support)
- GRDB.swift 7.9.0 (SQLite + FTS)
- SwiftLint 0.63.2 (linting)

### Architecture

**Layered approach:**
- Presentation: Channel tabs, chat timeline, composer, search/highlights
- Domain/State: Chat store, channel store, user store, UI store
- Services: Auth/OAuth, Helix API, chat WS/IRC, emotes resolver
- Storage: Keychain (tokens), image cache, message buffer + search index

**Key patterns:**
- Unidirectional data flow (UDF)
- Message enrichment pipeline
- Connection supervisor
- Helix API client with feature service wrappers
- Observable identity store (refresh on sign-in, clear on sign-out)
- Social classification: stateless classifier + observable store pattern
- Detail tab segments: enum-driven Picker switching between timeline views

### Known Pitfalls & Mitigations

| Pitfall | Prevention Phase | Mitigation Strategy |
|---------|------------------|---------------------|
| Twitch IRC rate limits ignored | Phase 1 | Message/command rate limiting, join pacing, exponential backoff |
| Fragile reconnect/backoff | Phase 1/3 | Connection state machine, backoff with jitter, resume-on-foreground |
| OAuth scope/refresh gaps | Phase 1/2 | Scope matrix per feature, refresh workflow, re-auth UX |
| Emote rendering bottlenecks | Phase 2/3 | Off-main decode, image caching, message caps |
| Cross-channel state bleed | Phase 2 | Namespaced per-channel state, strict channel ID tagging |
| Missing moderation events | Phase 2/4 | Handle clear/timeout/ban events, room state updates |
| Tight coupling to emote services | Phase 2/3 | Lazy-load with cache, graceful degradation to text-only |
| Search/highlight on raw text | Phase 2 | Tokenized message model, structured field search |

### Blockers

- Swift toolchain unavailable for build verification in this environment (swift build skipped for 04-08, 04-09, and 05-06).

## Session Continuity

**Last session:** 2026-02-07 17:43 UTC

**Stopped at:** Completed 05-07-PLAN.md

**Resume file:** None

**Next Action:** Plan Phase 6 (Highlights + Notifications)

**Context Handoff:** Custom commands now persist via CommandStore and expand through CommandResolver before sending. The composer exposes a command management sheet and Supinic-backed command suggestions with debounce. Command suggestions use Supinic command/channel/alias endpoints based on the DankChat Android contract.

---

*State file maintained by /gsd-new-project and /gsd-plan-phase workflows*
