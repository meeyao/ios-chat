# Roadmap

**Project:** DankChat/Chatterino iOS Port
**Last updated:** 2026-02-06
**Scope:** 1:1 feature parity with DankChat (see `.planning/PARITY.md`)
**Depth:** Full parity (8 phases)

## Overview

This roadmap targets a full parity port of DankChat to iOS/Swift. The parity checklist is the source of truth for scope; phases below group features into deliverable, dependency-aware milestones.

## Phases

### Phase 1: Foundation (Auth + Connectivity)

**Goal:** Users can authenticate and maintain a stable IRC connection with reconnection and rate limiting.

**Dependencies:** None

**Scope:** OAuth, token storage, IRC connection supervisor, rate limiting, join pacing, network/lifecycle resilience, config scaffolding.

**Plans:** 2 plans

Plans:
- [x] 01-01-PLAN.md — OAuth login + token storage + app wiring
- [x] 01-02-PLAN.md — IRC connectivity supervisor, rate limiting, lifecycle resilience

**Success Criteria:**
1. OAuth login + token persistence works reliably.
2. IRC connection reconnects with backoff and survives network changes.
3. Join/send pacing prevents disconnects under normal usage.

**Key Risks:** Token refresh failures, reconnect storms, improper IRC rate limits.

---

### Phase 2: Core Chat Pipeline

**Goal:** A single channel chat works end-to-end with correct message parsing and baseline UI.

**Dependencies:** Phase 1

**Scope:** IRC parsing, message models, timeline rendering, timestamps, link handling, basic settings (timestamps/usernames/scrollback), send/receive, system messages.

**Plans:** 3 plans (3/3 complete)

Plans:
- [x] 02-01-PLAN.md — IRCv3 message parser with tag unescape
- [x] 02-02-PLAN.md — Chat domain models + mapping + session wiring
- [x] 02-03-PLAN.md — Single-channel chat UI + composer + link handling

**Success Criteria:**
1. Messages render with correct username, content, timestamp, and link handling.
2. Send/receive latency and ordering match expected behavior.
3. System/notice messages are displayed correctly.

**Key Risks:** Parsing edge cases, UI performance under load.

---

### Phase 3: Multi-Channel Navigation

**Goal:** Users can manage multiple channels with tabbed navigation and independent state.

**Dependencies:** Phase 2

**Scope:** Channel list, add/remove, rename, tabs, per-channel unread/mention counts, connection status per channel.

**Plans:** 3 plans (3/3 complete)

**Completion:** 2026-02-06

Plans:
- [x] 03-01-PLAN.md — Channel models + per-channel store + IRC routing
- [x] 03-02-PLAN.md — Channel switcher UI + management + app shell wiring
- [x] 03-03-PLAN.md — Unread/mention indicators + scroll state preservation

**Success Criteria:**
1. Users can join, rename, and remove channels.
2. Switching tabs preserves per-channel state and unread/mentions.
3. Connection state is visible per channel.

**Key Risks:** State bleed, reconnect storms when many channels are active.

---

### Phase 4: Emotes + Badges Ecosystem

**Goal:** Emote and badge rendering matches DankChat including 7TV/BTTV/FFZ with caching and UI tools.

**Dependencies:** Phase 2-3

**Scope:** Twitch/BTTV/FFZ/7TV emotes, caching, animated GIF control, emote menu (tabs + recents), emote suggestions, badge rendering + visibility toggles, 7TV live updates.

**Success Criteria:**
1. Emotes/badges render accurately with correct positioning and caching.
2. Emote menu + suggestions behave like DankChat.
3. 7TV live updates apply without UI stalls.

**Key Risks:** Performance regressions, cache growth, third-party API outages.

---

### Phase 5: Social + Moderation

**Goal:** Mentions, whispers, replies, user actions, and moderation tools reach parity.

**Dependencies:** Phase 2-4

**Scope:** Mentions tab, whispers tab, reply threads, user popup (profile, followage, block), moderation actions (timeout/ban/delete/unban), room state controls, custom commands + command suggestions.

**Success Criteria:**
1. Mentions/whispers/replies flow matches DankChat UX.
2. Moderation actions work with correct permissions and feedback.
3. Custom commands and suggestions match behavior.

**Key Risks:** API permission gaps, inconsistent mod state handling.

---

### Phase 6: Highlights + Notifications

**Goal:** Highlight rules, ignore lists, and notification behavior match DankChat.

**Dependencies:** Phase 2-5

**Scope:** Highlight rules editor, highlight types/colors, ignore list, mention/whisper notifications, notification formatting.

**Success Criteria:**
1. Highlights trigger accurately and persist across sessions.
2. Ignore list filters correctly.
3. Notifications match mention/whisper behavior and format.

**Key Risks:** False positives, notification spam, background limitations.

---

### Phase 7: Streams + Tools

**Goal:** Stream viewing tools and utility features reach parity.

**Dependencies:** Phase 3-6

**Scope:** Stream info, WebView stream panel, PiP, stream settings, image uploader + history, TTS tooling.

**Success Criteria:**
1. Stream info + toggle behave like DankChat.
2. PiP + WebView stream are stable.
3. Image uploads and TTS tools match behavior/settings.

**Key Risks:** WebView stability, PiP constraints, upload failures.

---

### Phase 8: Settings + Polish

**Goal:** Full settings suite, changelog, and polish are complete.

**Dependencies:** All prior phases

**Scope:** Appearance settings, developer settings, about + changelog, secret danker mode, localization readiness, performance polish.

**Success Criteria:**
1. All settings screens function and persist correctly.
2. Changelog + about match DankChat behavior.
3. Performance remains stable under high load.

**Key Risks:** Settings regression, performance regressions, UI inconsistencies.

---

## Progress

| Phase | Status | Completion |
|-------|--------|------------|
| Phase 1: Foundation (Auth + Connectivity) | In Progress | 0% |
| Phase 2: Core Chat Pipeline | Complete | 100% |
| Phase 3: Multi-Channel Navigation | Complete | 100% |
| Phase 4: Emotes + Badges Ecosystem | Pending | 0% |
| Phase 5: Social + Moderation | Pending | 0% |
| Phase 6: Highlights + Notifications | Pending | 0% |
| Phase 7: Streams + Tools | Pending | 0% |
| Phase 8: Settings + Polish | Pending | 0% |

**Overall Progress:** 25%

## Dependency Graph

```
Phase 1 (Foundation)
    ↓
Phase 2 (Core Chat)
    ↓
Phase 3 (Multi-Channel)
    ↓
Phase 4 (Emotes + Badges)
    ↓
Phase 5 (Social + Moderation)
    ↓
Phase 6 (Highlights + Notifications)
    ↓
Phase 7 (Streams + Tools)
    ↓
Phase 8 (Settings + Polish)
```

## Notes

- `.planning/PARITY.md` is the parity checklist and defines completion criteria.
- Some settings UI may be implemented earlier as needed to support active features.
- Performance and resilience are validated throughout, not only in Phase 8.
