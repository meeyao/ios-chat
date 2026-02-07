---
phase: 05-social-moderation
plan: 06
subsystem: room-state
tags: [helix, room-state, chat-settings, irc, roomstate, moderation-controls]
dependency-graph:
  requires: [05-05]
  provides: [room-state-model, roomstate-parser, helix-chat-settings-service, room-state-controls-ui]
  affects: [05-07]
tech-stack:
  added: []
  patterns: [irc-tag-parsing-merge, helix-patch-with-nil-omission, scope-gated-controls]
key-files:
  created:
    - Sources/DankChatCore/Chat/RoomState.swift
    - Sources/DankChatCore/Chat/RoomStateParser.swift
    - Sources/DankChatCore/Services/Helix/HelixChatSettingsService.swift
  modified:
    - Sources/DankChatCore/Channels/ChannelState.swift
    - Sources/DankChatCore/Channels/ChannelStore.swift
    - Sources/DankChatCore/Chat/ChatSession.swift
    - Sources/DankChatCore/Services/Helix/ModerationContext.swift
    - Sources/DankChatApp/DankChatApp.swift
    - Sources/DankChatApp/UI/Chat/ChatSettingsView.swift
decisions:
  - id: roomstate-merge-strategy
    description: "RoomStateParser merges partial ROOMSTATE updates into existing state"
    rationale: "Twitch sends partial ROOMSTATE updates when a single mode changes; merge prevents loss of existing fields"
  - id: custom-encode-patch
    description: "HelixChatSettingsPatch uses custom encode(to:) to omit nil keys"
    rationale: "Helix PATCH endpoint expects missing keys for unchanged fields, not null values"
  - id: slow-mode-zero-means-off
    description: "Slow mode tag value 0 maps to nil (off) in RoomState"
    rationale: "Twitch IRC convention: slow=0 means slow mode disabled"
  - id: followers-negative-one-means-off
    description: "Followers-only tag value -1 maps to nil (off) in RoomState"
    rationale: "Twitch IRC convention: followers-only=-1 means followers-only disabled"
metrics:
  duration: ~4m
  completed: 2026-02-07
---

# Phase 5 Plan 6: Room State Controls Summary

Room state model + IRC ROOMSTATE parser + Helix chat settings service + moderator UI toggles for slow/followers/subs/emote/unique modes.

## What Was Done

### Task 1: RoomState model and IRC ROOMSTATE parsing
- Created `RoomState` struct with `slowModeSeconds`, `followersOnlyMinutes`, `isSubsOnly`, `isEmoteOnly`, `isUniqueChat` properties
- Created `RoomStateParser` enum with static `parse(tags:merging:)` that handles both full and partial ROOMSTATE updates
- Added `roomState: RoomState` property to `ChannelState`
- Added `updateRoomState(channelId:roomState:)` convenience method to `ChannelStore`
- Updated `ChatSession.handleLine()` to parse ROOMSTATE tags and update channel state before mapping to system message
- `RoomState.summary` provides human-readable mode descriptions for display

### Task 2: Helix chat settings service and UI controls
- Created `HelixChatSettingsService` wrapping `GET /chat/settings` and `PATCH /chat/settings`
- Created `HelixChatSettings` response model with `toRoomState()` converter for bidirectional sync
- Created `HelixChatSettingsPatch` with custom `Encodable` that omits nil keys (Helix expects absent keys, not null)
- Added `chatSettingsService` to `ModerationContext` and wired it in `ContentView` init
- Created `RoomStateControlsView` with toggles for all five room modes
- Slow mode and followers-only include steppers for duration/minutes adjustment
- Controls are scope-gated on `moderator:manage:chat_settings`
- After Helix update, response is converted to `RoomState` and synced back to `ChannelStore`
- Error handling shows HTTP status code or authentication messages

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Merge partial ROOMSTATE updates | Twitch sends partial updates when a single mode changes; merge prevents loss of existing field values |
| Custom Encodable for patch payload | Helix PATCH endpoint expects missing keys for unchanged fields, not JSON null |
| RoomState stored in ChannelState | Keeps room state co-located with other per-channel metadata (connection state, unread counts) |
| RoomStateControlsView as separate view | Decouples room state controls from ChatSettingsView; can be placed independently in channel detail |
| toRoomState() on HelixChatSettings | Bidirectional sync: IRC ROOMSTATE populates initial state, Helix response confirms updates |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Custom Encodable for HelixChatSettingsPatch**
- **Found during:** Task 2
- **Issue:** Default Swift Encodable encodes nil Optional values as JSON null; Helix PATCH endpoint expects absent keys for unchanged fields
- **Fix:** Added custom CodingKeys and encode(to:) implementation that only encodes non-nil values
- **Files modified:** Sources/DankChatCore/Services/Helix/HelixChatSettingsService.swift
- **Commit:** 82ed20f

## Task Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | RoomState model and IRC ROOMSTATE parsing | 0000523 | RoomState.swift, RoomStateParser.swift, ChannelState.swift, ChatSession.swift |
| 2 | Helix chat settings service and UI controls | 82ed20f | HelixChatSettingsService.swift, ModerationContext.swift, ChatSettingsView.swift, DankChatApp.swift |

## Verification

- `swift build`: Skipped (Swift toolchain unavailable in this environment -- known blocker from STATE.md)
- All type references are consistent across modules
- RoomStateParser correctly handles partial and full ROOMSTATE updates
- HelixChatSettingsPatch custom encoding omits nil keys
- Room state controls are scope-gated and disabled when scope is missing
- Helix response is synced back to ChannelStore room state after update

## Next Phase Readiness

Plan 05-06 is complete. All room state infrastructure is in place:
- IRC ROOMSTATE tags are parsed and stored in ChannelState
- Helix chat settings can be read and updated
- UI controls are available via RoomStateControlsView
- ModerationContext now provides chatSettingsService to any view

Plan 05-07 can proceed to complete the remaining social/moderation features.

## Self-Check: PASSED
