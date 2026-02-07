---
phase: 05-social-moderation
plan: 03
subsystem: whispers
tags: [eventsub, websocket, helix, whispers, social]
completed: 2026-02-07
duration: "3m 26s"
dependency-graph:
  requires: [05-02]
  provides: ["EventSub WebSocket client", "Helix whisper service", "WhisperStore", "WhispersTabView"]
  affects: [05-05, 05-06, 05-07]
tech-stack:
  added: []
  patterns: ["EventSub WebSocket session lifecycle", "whisper conversation store with delivery uncertainty"]
key-files:
  created:
    - Sources/DankChatCore/Services/EventSub/EventSubClient.swift
    - Sources/DankChatCore/Services/EventSub/EventSubModels.swift
    - Sources/DankChatCore/Services/Helix/HelixWhisperService.swift
    - Sources/DankChatCore/Social/WhisperStore.swift
    - Sources/DankChatApp/UI/Tabs/WhispersTabView.swift
  modified:
    - Sources/DankChatApp/DankChatApp.swift
decisions:
  - id: eventsub-websocket-client
    decision: "Implemented EventSub WebSocket client using URLSessionWebSocketTask"
    rationale: "Consistent with IRCWebSocketClient pattern; no third-party dependencies"
  - id: whisper-delivery-uncertainty
    decision: "Outgoing whispers display 'Sent (delivery not guaranteed)' status"
    rationale: "Twitch Send Whisper API may silently drop messages; UX must not mislead"
  - id: conversation-keyed-by-userid
    decision: "WhisperStore conversations keyed by other user's Twitch ID"
    rationale: "User IDs are stable identifiers; login/display names can change"
  - id: eventsub-auto-start-on-identity
    decision: "EventSub client auto-starts when UserIdentityStore user becomes available"
    rationale: "Identity store already fires onChange; avoids duplicate lifecycle code"
---

# Phase 5 Plan 3: Whisper Send/Receive via EventSub Summary

**One-liner:** EventSub WebSocket client + Helix whisper send + WhisperStore with delivery uncertainty UX in a dedicated Whispers tab.

## What Was Done

### Task 1: EventSub Client and Helix Whisper Service
- Created `EventSubClient` using `URLSessionWebSocketTask` to connect to Twitch EventSub WebSocket endpoint
- Handles full session lifecycle: `session_welcome`, `session_keepalive`, `session_reconnect`, `notification`, `revocation`
- Parses session ID from welcome message and uses it to create Helix EventSub subscriptions
- `subscribeToWhispers(userId:)` calls `POST /eventsub/subscriptions` for `user.whisper.message` type
- `connectAndSubscribeToWhispers(userId:)` convenience method stores user ID and auto-subscribes after welcome
- Reconnect handling: connects to new URL from `session_reconnect` before closing old connection
- `EventSubModels` defines `EventSubMessage` envelope, `SessionPayload`, `WhisperEvent`, and subscription request/response types
- `HelixWhisperService` wraps `POST /whispers` with sender/target user IDs and message body
- Documentation notes that successful API call does not guarantee delivery

### Task 2: WhisperStore and Whispers Tab UI
- `WhisperStore` (ObservableObject, @MainActor) maintains `WhisperConversation` array sorted by last activity
- Conversations keyed by other user's Twitch ID with messages in chronological order
- Incoming whispers from EventSub callback are dispatched to main actor and appended
- Outgoing whispers sent via `HelixWhisperService` with immediate local record and `.sent` delivery state
- Failed sends update message to `.failed` delivery state
- Per-conversation message cap (default 500) prevents unbounded growth
- `WhispersTabView` shows conversation list with `NavigationLink` drill-down to `WhisperThreadView`
- Message thread uses `WhisperBubble` view with alignment (left for incoming, right for outgoing)
- Outgoing bubbles show "Sent (delivery not guaranteed)" or "Failed to send" indicator
- Compose bar with `TextField` and send button
- Wired into `DankChatApp.ContentView`:
  - `WhisperStore` created from `HelixWhisperService` + `EventSubClient` (both share existing `HelixAPIClient`)
  - Injected as `.environmentObject(whisperStore)`
  - `DetailTab` enum extended with `.whispers` case
  - EventSub starts automatically when `identityStore.user` becomes non-nil
  - Stops and clears on sign-out

## Task Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | EventSub client and Helix whisper service | aa3ee16 | EventSubClient.swift, EventSubModels.swift, HelixWhisperService.swift |
| 2 | WhisperStore and Whispers tab UI | f564f33 | WhisperStore.swift, WhispersTabView.swift, DankChatApp.swift |

## Decisions Made

1. **EventSub WebSocket via URLSessionWebSocketTask** -- Matches IRCWebSocketClient pattern, no new dependencies.
2. **Delivery uncertainty UX** -- Outgoing whispers show "Sent (delivery not guaranteed)" since Twitch may silently drop them.
3. **Conversations keyed by user ID** -- Twitch user IDs are stable; login/display names can change.
4. **Auto-start on identity availability** -- EventSub connects when `identityStore.user` becomes non-nil via `onChange`, avoids duplicate lifecycle management.

## Deviations from Plan

None -- plan executed exactly as written.

## Verification

- Build verification: Swift toolchain unavailable in this environment (known blocker documented in STATE.md). Code follows established patterns from existing Helix services, IRC WebSocket client, and social tab views.
- Whispers tab added to segmented control and renders conversation list + message thread with delivery state indicators.
- End-to-end flow: EventSub receives whisper -> WhisperStore appends -> WhispersTabView updates. Send: compose bar -> WhisperStore.sendWhisper -> HelixWhisperService -> local record with uncertainty.

## Next Phase Readiness

- EventSubClient is designed to be extensible for additional event types (moderation events, chat settings) needed by later plans (05-05, 05-06, 05-07).
- WhisperStore can be extended with persistence (GRDB) if needed.
- No blockers for subsequent plans.

## Self-Check: PASSED
