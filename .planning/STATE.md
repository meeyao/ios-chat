# Project State

**Project:** DankChat/Chatterino iOS Port
**Last updated:** 2026-02-06

## Project Reference

### Core Value

DankChat users can switch to iOS without losing any features or behavior they rely on.

### Current Focus

**Active Phase:** Phase 5 - Social + Moderation

**Next Milestone:** Phase 5 - Social + Moderation

**Blockers:** Build verification pending (swift toolchain unavailable in this environment)

## Current Position

**Phase:** 5 of 8 (Social + Moderation)

**Current Plan:** Not started

**Status:** Phase 4 complete (verified)

**Last activity:** 2026-02-06 - Phase 4 human verification approved

**Progress Bar:** ``░░░░░░░░░░ 0%`` (0/0 plans complete)

## Performance Metrics

**Requirements:**
- Parity checklist tracked in `.planning/PARITY.md`

**Phases:**
- Total: 8
- Completed: 3
- In Progress: 1
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

### TODO

**Immediate:**
- Verify Phase 1 implementation with `swift test` in a Swift/Xcode environment
- Run `swift test --filter IRCMessageParserTests` in a Swift toolchain
- Use `.planning/PARITY.md` to drive Phase 2+ scope

**Upcoming:**
- Implement OAuth flow with Twitch
- Set up Twitch IRC WebSocket connection
- Implement rate limiting and join pacing
- Build connection state machine with backoff

### Blockers

- Swift toolchain unavailable for build verification in this environment (swift build skipped for 04-08 and 04-09).

## Session Continuity

**Last session:** 2026-02-06 17:00 UTC

**Stopped at:** Phase 4 verification approved

**Resume file:** None

**Next Action:** Discuss Phase 5 scope (`/gsd-discuss-phase 5`)

**Context Handoff:** Phase 4 gaps closed and human verification approved. Phase 5 (Social + Moderation) is ready to plan.

---

*State file maintained by /gsd-new-project and /gsd-plan-phase workflows*
