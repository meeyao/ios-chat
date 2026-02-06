# Project State

**Project:** DankChat/Chatterino iOS Port
**Last updated:** 2026-02-06

## Project Reference

### Core Value

DankChat users can switch to iOS without losing any features or behavior they rely on.

### Current Focus

**Active Phase:** Phase 4 - Emotes + Badges Ecosystem

**Next Milestone:** Phase 4 - Emotes + Badges Ecosystem

**Blockers:** Build verification pending (swift toolchain unavailable in this environment)

## Current Position

**Phase:** 4 of 8 (Emotes + Badges Ecosystem)

**Current Plan:** 04-02-PLAN.md (complete)

**Status:** In progress

**Last activity:** 2026-02-06 - Completed 04-02-PLAN.md

**Progress Bar:** ``███████░░░ 67%`` (10/15 plans complete)

## Performance Metrics

**Requirements:**
- Parity checklist tracked in `.planning/PARITY.md`

**Phases:**
- Total: 8
- Completed: 2
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

- Swift toolchain unavailable for build verification in this environment.

## Session Continuity

**Last session:** 2026-02-06 06:34 UTC

**Stopped at:** Completed 04-02-PLAN.md

**Resume file:** None

**Next Action:** Begin Phase 4 Plan 03 (provider clients + unified emote/badge stores)

**Context Handoff:** IRC tag parsing now yields typed Twitch emote/badge metadata; build verification pending due to missing Swift toolchain.

---

*State file maintained by /gsd-new-project and /gsd-plan-phase workflows*
