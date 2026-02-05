# Project State

**Project:** DankChat/Chatterino iOS Port
**Last updated:** 2026-02-06

## Project Reference

### Core Value

DankChat users can switch to iOS without losing any features or behavior they rely on.

### Current Focus

**Active Phase:** Phase 2 - Core Chat Pipeline

**Next Milestone:** Phase 2 - Core Chat Pipeline

**Blockers:** None identified

## Current Position

**Phase:** 2 of 8 (Core Chat Pipeline)

**Current Plan:** 3 of 3 in current phase

**Status:** Phase complete

**Last activity:** 2026-02-06 - Completed 02-03-PLAN.md

**Progress Bar:** ``██████████ 100%`` (5/5 plans complete)

## Performance Metrics

**Requirements:**
- Parity checklist tracked in `.planning/PARITY.md`

**Phases:**
- Total: 8
- Completed: 0
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

None identified.

## Session Continuity

**Last session:** 2026-02-06 21:21

**Stopped at:** Completed 02-03-PLAN.md

**Resume file:** None

**Next Action:** Begin Phase 3 planning

**Context Handoff:** Single-channel chat UI wired; proceed to multi-channel navigation work.

---

*State file maintained by /gsd-new-project and /gsd-plan-phase workflows*
