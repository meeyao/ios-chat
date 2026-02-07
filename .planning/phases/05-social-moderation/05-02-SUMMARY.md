---
phase: 05-social-moderation
plan: 02
subsystem: social
tags: [reply-metadata, mentions, replies, social-tabs, irc-tags, classifier]

# Dependency graph
requires:
  - phase: 05-social-moderation
    plan: 01
    provides: "HelixAPIClient, HelixUser, UserIdentityStore"
provides:
  - "ReplyMetadata struct on ChatMessage for IRC reply tags"
  - "SocialMessageClassifier for mention/reply detection"
  - "SocialTabStore with mentionsStore and repliesStore"
  - "MentionsTabView and RepliesTabView rendering social timelines"
  - "ReplyThreadView for parent message context display"
  - "Segmented Chat/Mentions/Replies tab control in channel detail"
affects:
  - 05-social-moderation (subsequent plans use SocialTabStore for whispers, moderation surfaces)
  - 03-multi-channel-navigation (channel detail now has tab segments)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SocialMessageClassifier as stateless struct for mention/reply classification"
    - "SocialTabStore wraps two ChatStores and classifies via identity"
    - "Segmented Picker in channelDetail for Chat/Mentions/Replies switching"
    - "ReplyThreadView presented as sheet from reply indicator in ChatMessageRow"

key-files:
  created:
    - Sources/DankChatCore/Social/SocialMessageClassifier.swift
    - Sources/DankChatCore/Social/SocialTabStore.swift
    - Sources/DankChatApp/UI/Tabs/MentionsTabView.swift
    - Sources/DankChatApp/UI/Tabs/RepliesTabView.swift
    - Sources/DankChatApp/UI/Chat/ReplyThreadView.swift
  modified:
    - Sources/DankChatCore/Chat/ChatMessage.swift
    - Sources/DankChatCore/Chat/ChatMessageMapper.swift
    - Sources/DankChatApp/DankChatApp.swift
    - Sources/DankChatApp/UI/Chat/ChatMessageRow.swift

key-decisions:
  - "ReplyMetadata keyed on reply-parent-msg-id presence (nil when absent)"
  - "Classifier checks user ID first, then login, then displayName for reply detection"
  - "isMention falls back to defaultNick/defaultUser when identity is nil"
  - "SocialTabStore shares ChatSettings scrollback limits with main chat stores"

patterns-established:
  - "Social classification: stateless classifier + observable store pattern"
  - "Detail tab segments: enum-driven Picker switching between timeline views"

# Metrics
duration: 4min
completed: 2026-02-07
---

# Phase 5 Plan 02: Reply Metadata + Mentions/Replies Tabs Summary

**Reply tag parsing from IRC, social classifier using authenticated identity, and Mentions/Replies tab views with reply thread context**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-07T16:49:33Z
- **Completed:** 2026-02-07T16:53:40Z
- **Tasks:** 3
- **Files created:** 5
- **Files modified:** 4

## Accomplishments

- `ReplyMetadata` struct capturing parent message id, user id, login, display name, and body from IRC `reply-parent-*` tags
- `ChatMessageMapper` populates optional reply metadata only when `reply-parent-msg-id` tag is present
- `SocialMessageClassifier` with `isMention` (text contains login/displayName) and `isReply` (reply metadata targets current user by id/login/displayName)
- `SocialTabStore` as ObservableObject with separate `mentionsStore` and `repliesStore` backed by `ChatStore`
- Incoming events forwarded to SocialTabStore in channelDetail onChange handler
- `isMention` updated to prefer authenticated `UserIdentityStore.user` identity over static `defaultNick/defaultUser`
- `MentionsTabView` and `RepliesTabView` rendering ChatTimelineView with respective social stores
- Segmented `Picker` (Chat/Mentions/Replies) in channel detail for switching between timeline views
- `ReplyThreadView` showing parent message context and the reply, presented as sheet
- `ChatMessageRow` reply indicator with arrow icon and "Replying to [user]" label, tapping opens ReplyThreadView

## Task Commits

Each task was committed atomically:

1. **Task 1: Parse reply tags into chat message metadata** - `078b6f9` (feat)
2. **Task 2: Add social classifier and mention/reply stores** - `0cc161e` (feat)
3. **Task 3: Add Mentions/Replies tabs and reply thread UI** - `06d3b35` (feat)

## Files Created/Modified

- `Sources/DankChatCore/Chat/ChatMessage.swift` - Added ReplyMetadata struct and optional replyMetadata field
- `Sources/DankChatCore/Chat/ChatMessageMapper.swift` - Added parseReplyMetadata for reply-parent-* IRC tags
- `Sources/DankChatCore/Social/SocialMessageClassifier.swift` - Stateless classifier with isMention and isReply
- `Sources/DankChatCore/Social/SocialTabStore.swift` - Observable store with mentionsStore and repliesStore
- `Sources/DankChatApp/DankChatApp.swift` - Wired SocialTabStore, added DetailTab segmented control, updated isMention
- `Sources/DankChatApp/UI/Tabs/MentionsTabView.swift` - Mentions timeline with empty state
- `Sources/DankChatApp/UI/Tabs/RepliesTabView.swift` - Replies timeline with empty state
- `Sources/DankChatApp/UI/Chat/ReplyThreadView.swift` - Parent context + reply display in NavigationStack sheet
- `Sources/DankChatApp/UI/Chat/ChatMessageRow.swift` - Reply indicator button and ReplyThreadView sheet

## Decisions Made

- `ReplyMetadata` is only created when `reply-parent-msg-id` tag is present; all other reply fields are optional since IRC may omit them
- Classifier checks user ID first for reply detection (most reliable), falling back to login and display name comparisons
- `isMention` in ContentView prefers authenticated `HelixUser` identity from `UserIdentityStore`, but falls back to static `defaultNick`/`defaultUser` config values when not signed in, preserving backward compatibility
- SocialTabStore uses the same `ChatSettings` instance as the main chat, sharing scrollback limit configuration

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Swift toolchain not available in this environment; `swift build` verification skipped (known blocker from STATE.md)

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SocialTabStore is ready for additional social surfaces (whispers, moderation events)
- Reply metadata enables future features: reply-to-message composer, threaded conversation views
- Classifier pattern can be extended for additional classification (e.g., whisper detection)
- Build verification pending Swift toolchain availability

## Self-Check: PASSED

---
*Phase: 05-social-moderation*
*Completed: 2026-02-07*
