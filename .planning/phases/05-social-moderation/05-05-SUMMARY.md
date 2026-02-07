---
phase: 05-social-moderation
plan: 05
subsystem: moderation
tags: [helix, moderation, ban, timeout, delete, action-sheet, timeline-feedback]
dependency-graph:
  requires: [05-04]
  provides: [helix-moderation-service, chat-messages-service, moderation-action-sheet, moderation-timeline-feedback]
  affects: [05-06, 05-07]
tech-stack:
  added: []
  patterns: [environment-object-injection, system-message-feedback, context-menu-actions]
key-files:
  created:
    - Sources/DankChatCore/Services/Helix/HelixModerationService.swift
    - Sources/DankChatCore/Services/Helix/HelixChatMessagesService.swift
    - Sources/DankChatCore/Services/Helix/ModerationContext.swift
    - Sources/DankChatApp/UI/Chat/ModerationActionSheet.swift
  modified:
    - Sources/DankChatCore/Chat/ChatEvent.swift
    - Sources/DankChatCore/Channels/ChannelStore.swift
    - Sources/DankChatApp/UI/Chat/ChatMessageRow.swift
    - Sources/DankChatApp/DankChatApp.swift
decisions:
  - id: moderation-context-env-object
    choice: "ModerationContext environmentObject wrapping services + channelStore"
    rationale: "Avoids passing services through multiple view layers; consistent with existing environmentObject pattern"
  - id: shared-channel-store-for-feedback
    choice: "Reuse single ChannelStore instance for moderation feedback"
    rationale: "Timeline feedback must appear in the same store the timeline renders from"
  - id: system-message-kind-moderation
    choice: "Added .moderation case to SystemMessageKind"
    rationale: "Distinguishes moderation feedback from IRC notices for future styling or filtering"
metrics:
  duration: ~5 minutes
  completed: 2026-02-07
---

# Phase 5 Plan 5: Moderation Actions Summary

Helix ban/timeout/unban/delete endpoints wrapped as services, surfaced via context-menu action sheet with timeline feedback.

## What Was Built

### Task 1: Helix Moderation Services

Created two Helix service wrappers following the established pattern (HelixBlockService, HelixWhisperService):

**HelixModerationService** (`Sources/DankChatCore/Services/Helix/HelixModerationService.swift`):
- `banUser(broadcasterId:moderatorId:userId:reason:)` -- permanent ban via POST /moderation/bans
- `timeoutUser(broadcasterId:moderatorId:userId:durationSeconds:reason:)` -- timeout with duration via POST /moderation/bans
- `unbanUser(broadcasterId:moderatorId:userId:)` -- remove ban/timeout via DELETE /moderation/bans
- All gated by `moderator:manage:banned_users` scope
- Returns typed `HelixBanResult` with creation time and optional end time

**HelixChatMessagesService** (`Sources/DankChatCore/Services/Helix/HelixChatMessagesService.swift`):
- `deleteMessage(broadcasterId:moderatorId:messageId:)` -- delete single message via DELETE /moderation/chat
- `clearChat(broadcasterId:moderatorId:)` -- clear all chat via DELETE /moderation/chat (no message_id)
- Gated by `moderator:manage:chat_messages` scope

**TimeoutDuration enum** -- preset durations from 1 second to 2 weeks with human-readable labels.

**SystemMessageKind.moderation** -- new case added to ChatEvent.swift for moderation feedback messages.

### Task 2: Moderation Action UI and Timeline Feedback

**ModerationActionSheet** (`Sources/DankChatApp/UI/Chat/ModerationActionSheet.swift`):
- List-based sheet with sections: Timeout (expandable duration picker), Ban, Unban, Delete Message
- Loading overlay during action execution
- Detailed error descriptions mapping HelixError HTTP status codes to user-friendly messages
- Automatically appends `[Mod]` or `[Mod Error]` system messages to the channel timeline

**ChatMessageRow updates**:
- Added context menu with "Moderate" option (only visible when signed in)
- Sheet presentation of ModerationActionSheet with all required dependencies

**ChannelStore.appendSystemMessage(channelId:text:kind:)**:
- Public helper to inject system messages into a channel's ChatStore
- Defaults to `.moderation` kind
- Used by ModerationActionSheet for success/failure feedback

**ModerationContext** (`Sources/DankChatCore/Services/Helix/ModerationContext.swift`):
- Observable wrapper providing HelixModerationService, HelixChatMessagesService, and ChannelStore
- Injected as environmentObject from ContentView
- Avoids deep prop drilling through the view hierarchy

**ContentView wiring**:
- ChannelStore now created as a named local before StateObject wrapping (needed for shared reference)
- ModerationContext created with shared helixClient and channelStore
- Added `.environmentObject(moderationContext)` to view hierarchy

## Task Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Implement Helix moderation services | c4d9e5c | HelixModerationService.swift, HelixChatMessagesService.swift, ChatEvent.swift |
| 2 | Add moderation action UI and timeline feedback | d7db26d | ModerationActionSheet.swift, ModerationContext.swift, ChatMessageRow.swift, ChannelStore.swift, DankChatApp.swift |

## Decisions Made

1. **ModerationContext as environmentObject**: Rather than passing individual services through view parameters, created a lightweight observable context object. Consistent with existing UserProfileStore, WhisperStore patterns. Avoids touching intermediate view signatures.

2. **Shared ChannelStore instance**: The ModerationContext holds a reference to the same ChannelStore that ContentView uses. This ensures moderation feedback system messages appear in the correct timeline. Refactored ContentView init to capture the ChannelStore as a named local before wrapping in StateObject.

3. **SystemMessageKind.moderation**: Added a dedicated enum case rather than reusing `.notice`. This enables future differentiation in rendering (e.g., different colors or icons for moderation feedback vs IRC notices).

4. **Context menu for moderation**: Used SwiftUI `.contextMenu` (long-press) rather than an always-visible button. Keeps the message row clean and follows platform conventions.

## Deviations from Plan

None -- plan executed exactly as written.

## Verification

- Build verification skipped (Swift toolchain unavailable in this environment, as documented in STATE.md).
- Code follows established patterns from HelixBlockService, HelixWhisperService, UserPopupView.
- All files created/modified as specified in plan.

## Next Phase Readiness

- Moderation services are ready for 05-06 (chat settings/slow mode) and 05-07 (remaining moderation features).
- The `ModerationContext` pattern can be extended with additional services (e.g., HelixChatSettingsService) without changing the view hierarchy.
- `ChannelStore.appendSystemMessage` is a general-purpose helper available for any feature needing timeline feedback.

## Self-Check: PASSED
