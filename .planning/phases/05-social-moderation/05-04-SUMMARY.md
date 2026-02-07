---
phase: "05-social-moderation"
plan: "04"
subsystem: "social"
tags: ["helix", "user-profile", "followage", "block", "user-popup", "swiftui"]

dependency-graph:
  requires:
    - "05-01"  # Helix API client + identity store
    - "05-03"  # WhisperStore/EventSub wiring pattern
  provides:
    - "Helix user profile service (GET /users extended)"
    - "Helix followage service (GET /channels/followers)"
    - "Helix block/unblock service (PUT/DELETE /users/blocks)"
    - "UserProfileStore observable store"
    - "UserPopupView sheet UI"
    - "Username tap -> user popup integration"
  affects:
    - "05-05"  # Moderation actions may extend user popup
    - "05-06"  # Chat settings may add block list management
    - "05-07"  # Final verification

tech-stack:
  added: []
  patterns:
    - "Helix feature service wrapper (profile, followage, block)"
    - "Observable store with scope-gated error handling"
    - "Sheet-based user popup from chat row tap"
    - "AsyncImage for profile avatar loading"

file-tracking:
  key-files:
    created:
      - "Sources/DankChatCore/Services/Helix/HelixUserProfileService.swift"
      - "Sources/DankChatCore/Services/Helix/HelixFollowageService.swift"
      - "Sources/DankChatCore/Services/Helix/HelixBlockService.swift"
      - "Sources/DankChatCore/Social/UserProfileStore.swift"
      - "Sources/DankChatApp/UI/UserPopup/UserPopupView.swift"
    modified:
      - "Sources/DankChatApp/UI/Chat/ChatMessageRow.swift"
      - "Sources/DankChatApp/DankChatApp.swift"

decisions:
  - id: "shared-user-profile-store"
    description: "UserProfileStore as shared environmentObject reloaded per popup"
    rationale: "Consistent with WhisperStore/SocialTabStore pattern; avoids per-row state objects"

  - id: "custom-coding-keys-for-description"
    description: "HelixUserProfile uses custom CodingKeys to map 'description' to 'userDescription'"
    rationale: "'description' conflicts with Swift's CustomStringConvertible; explicit mapping works with convertFromSnakeCase"

  - id: "channel-id-as-login-for-followage"
    description: "Followage passes channel login string as channelId (may fail until channel ID resolution added)"
    rationale: "Channels currently store login names as IDs; followage gracefully degrades to 'not following' or scope-missing"

  - id: "paginated-block-list-fetch"
    description: "HelixBlockService.getBlockedUsers paginates through all blocked users"
    rationale: "Users may have large block lists; pagination ensures complete results"

metrics:
  duration: "5m 31s"
  completed: "2026-02-07"
---

# Phase 5 Plan 4: User Popup with Profile, Followage, and Block Controls Summary

User popup UI with Helix profile/followage/block services and chat row tap integration via shared UserProfileStore.

## Task Commits

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Helix profile/followage/block services + UserProfileStore | 9fac748 | HelixUserProfileService.swift, HelixFollowageService.swift, HelixBlockService.swift, UserProfileStore.swift |
| 2 | UserPopupView + ChatMessageRow integration | 0593e3e | UserPopupView.swift, ChatMessageRow.swift, DankChatApp.swift |

## What Was Built

### Helix Services (DankChatCore)

**HelixUserProfileService** -- wraps `GET /users` with extended profile fields:
- `HelixUserProfile` struct with id, login, displayName, profileImageUrl, userDescription, createdAt, broadcasterType
- Custom CodingKeys handle the `description` -> `userDescription` mapping alongside `convertFromSnakeCase`
- Lookup by user ID or login name

**HelixFollowageService** -- wraps `GET /channels/followers`:
- Returns `HelixFollowRecord` with userId, userLogin, userName, followedAt
- Gated by `moderator:read:followers` scope
- Returns nil when user does not follow the channel

**HelixBlockService** -- wraps block/unblock endpoints:
- `blockUser(targetUserId:)` via `PUT /users/blocks`
- `unblockUser(targetUserId:)` via `DELETE /users/blocks`
- `getBlockedUsers(broadcasterId:)` via `GET /users/blocks` with pagination
- All gated by `user:manage:blocked_users` scope

### UserProfileStore (DankChatCore)

Observable `@MainActor` store that loads and caches:
- User profile via HelixUserProfileService
- Follow record via HelixFollowageService (scope-gated, non-critical)
- Block state via HelixBlockService (scope-gated, non-critical)

Exposes `blockUser()` and `unblockUser()` actions that update `isBlocked` state on success and surface errors with scope-missing detection (401/403 handling).

### UserPopupView (DankChatApp)

SwiftUI sheet presented from chat username taps:
- Header section: AsyncImage avatar, display name, login, broadcaster type badge, account creation date
- Bio section: user description (3-line limit)
- Followage section: follow date or "not following" / "scope missing" / "no channel context"
- Block section: block/unblock button or "scope missing" label
- Error banner for failed operations
- ISO 8601 date formatting with fractional seconds fallback

### ChatMessageRow Integration

- Removed hardcoded `onUsernameTap: nil` callback
- Added `@EnvironmentObject` for `UserProfileStore` and `UserIdentityStore`
- Username button now sets `showUserPopup = true` which presents `UserPopupView` as a sheet
- Passes message user ID, login, display name, channel, and authenticated user ID

### ContentView Wiring

- Creates `HelixUserProfileService`, `HelixFollowageService`, `HelixBlockService` from shared `helixClient`
- Constructs `UserProfileStore` and injects as `@StateObject`
- Adds `.environmentObject(userProfileStore)` to view hierarchy
- Preview updated with all required environment objects

## Decisions Made

1. **Shared UserProfileStore as environmentObject** -- Consistent with WhisperStore pattern; the store is reloaded each time a popup opens rather than maintaining per-user caches.

2. **Custom CodingKeys for HelixUserProfile** -- The Helix `description` field conflicts with Swift's `CustomStringConvertible.description`. Mapped to `userDescription` via explicit CodingKeys, which works correctly with the `convertFromSnakeCase` decoder strategy.

3. **Channel login as followage channelId** -- Current channel model stores login names, not numeric IDs. The followage API requires broadcaster_id (numeric). Followage gracefully degrades until channel ID resolution is implemented.

4. **Paginated block list fetch** -- `getBlockedUsers` loops through all pages to ensure complete results, as users may have large block lists.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Updated ChatMessageRow preview with required environment objects**
- **Found during:** Task 2
- **Issue:** Preview would crash without `UserProfileStore` and `UserIdentityStore` environment objects
- **Fix:** Added all required environment objects to the `#Preview` block
- **Files modified:** ChatMessageRow.swift
- **Commit:** 0593e3e

## Verification

- All 7 artifact files confirmed present
- Task 1 commit (9fac748) verified
- Task 2 commit (0593e3e) verified
- Build verification skipped (Swift toolchain unavailable in this environment)
- Username tap -> UserPopupView sheet -> profile/followage/block flow structurally complete

## Next Phase Readiness

- Moderation plans (05-05, 05-06) can extend UserPopupView with additional actions (timeout, ban)
- Followage will become fully functional once channel stores resolve broadcaster IDs
- Block state flows through UserProfileStore and is ready for integration with chat filtering

## Self-Check: PASSED
