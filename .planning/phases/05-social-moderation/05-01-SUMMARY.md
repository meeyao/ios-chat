---
phase: 05-social-moderation
plan: 01
subsystem: api
tags: [helix, twitch-api, oauth, identity, urlsession]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: "AuthManager, OAuthConfiguration, token management"
provides:
  - "HelixAPIClient: reusable Helix HTTP client with token injection"
  - "HelixRequest: request descriptor for method/path/query/body"
  - "HelixError: structured error type for Helix failures"
  - "HelixScope: OAuth scope constants for social and moderation features"
  - "HelixUsersService: GET /users endpoint wrapper"
  - "HelixUser: public user identity model"
  - "UserIdentityStore: observable cached identity for signed-in user"
  - "Expanded default OAuth scopes covering Phase 5 features"
affects:
  - 05-social-moderation (all subsequent plans use HelixAPIClient and UserIdentityStore)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "HelixAPIClient wraps URLSession with Client-Id and Bearer injection"
    - "Feature services (HelixUsersService) wrap HelixAPIClient with typed helpers"
    - "UserIdentityStore caches identity and reacts to auth state changes"

key-files:
  created:
    - Sources/DankChatCore/Services/Helix/HelixAPIClient.swift
    - Sources/DankChatCore/Services/Helix/HelixRequest.swift
    - Sources/DankChatCore/Services/Helix/HelixError.swift
    - Sources/DankChatCore/Services/Helix/HelixScope.swift
    - Sources/DankChatCore/Services/Helix/HelixUsersService.swift
    - Sources/DankChatCore/Social/UserIdentityStore.swift
  modified:
    - Sources/DankChatApp/AppConfiguration.swift
    - Sources/DankChatApp/DankChatApp.swift

key-decisions:
  - "Relaxed Sendable on HelixAPIClient to match existing TwitchEmoteProvider closure pattern"
  - "Used convertFromSnakeCase key decoding strategy for all Helix JSON responses"
  - "Default scopes set via HelixScope.defaultScopes constant instead of inline array"

patterns-established:
  - "HelixAPIClient pattern: feature services wrap client.execute() with typed request/response"
  - "UserIdentityStore pattern: refresh on sign-in, clear on sign-out, available via environmentObject"

# Metrics
duration: 4min
completed: 2026-02-07
---

# Phase 5 Plan 01: Helix API Client + User Identity Foundation Summary

**Reusable Helix API client with token injection, GET /users service, observable identity store, and expanded OAuth scopes for moderation/social features**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-07T16:41:59Z
- **Completed:** 2026-02-07T16:45:49Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Helix API client that injects Client-Id and Bearer token on every request, supporting GET/POST/PATCH/DELETE with typed Decodable responses
- HelixUsersService wrapping GET /users for current user lookup and batch user queries by login or ID
- UserIdentityStore as an ObservableObject caching the signed-in user's id/login/display_name, wired into ContentView with automatic refresh on auth state changes
- Default OAuth scopes expanded from 2 (chat:read, chat:edit) to 9, covering moderation, followers, whispers, and blocked users

## Task Commits

Each task was committed atomically:

1. **Task 1: Add a Helix API client foundation** - `466299e` (feat)
2. **Task 2: Add user identity store and update OAuth scopes** - `2b14758` (feat)

## Files Created/Modified
- `Sources/DankChatCore/Services/Helix/HelixAPIClient.swift` - Reusable Helix HTTP client with Client-Id and Bearer injection
- `Sources/DankChatCore/Services/Helix/HelixRequest.swift` - Request descriptor (method, path, query, body, required scopes)
- `Sources/DankChatCore/Services/Helix/HelixError.swift` - Structured error type for HTTP and decoding failures
- `Sources/DankChatCore/Services/Helix/HelixScope.swift` - OAuth scope string constants with default scope list
- `Sources/DankChatCore/Services/Helix/HelixUsersService.swift` - GET /users endpoint wrapper with HelixUser model
- `Sources/DankChatCore/Social/UserIdentityStore.swift` - Observable identity cache with refresh/clear lifecycle
- `Sources/DankChatApp/AppConfiguration.swift` - Default scopes updated to HelixScope.defaultScopes
- `Sources/DankChatApp/DankChatApp.swift` - HelixAPIClient and UserIdentityStore wired into ContentView

## Decisions Made
- Relaxed `Sendable` conformance on `HelixAPIClient` and `HelixUsersService` to match the existing `TwitchEmoteProvider` pattern, which captures `[weak authManager]` in a non-Sendable closure
- Used `convertFromSnakeCase` key decoding strategy in `HelixAPIClient` so Helix response fields like `display_name` map to Swift `displayName` automatically
- Centralized default scope list in `HelixScope.defaultScopes` and referenced it from `AppConfiguration` rather than duplicating strings

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Relaxed @Sendable constraint on HelixAPIClient**
- **Found during:** Task 2 (wiring into ContentView)
- **Issue:** `HelixAPIClient` was declared `Sendable` with `@Sendable` token provider, but the existing `tokenProvider` closure in `ContentView.init` captures `[weak authManager]` non-Sendably (matching `TwitchEmoteProvider` pattern)
- **Fix:** Removed `Sendable` conformance from `HelixAPIClient` and `HelixUsersService`, dropped `@Sendable` from token provider closure type
- **Files modified:** `HelixAPIClient.swift`, `HelixUsersService.swift`
- **Verification:** Structural consistency with existing `TwitchEmoteProvider` pattern confirmed
- **Committed in:** `2b14758` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for consistency with existing codebase patterns. No scope creep.

## Issues Encountered
- Swift toolchain not available in this environment; `swift build` verification skipped (known blocker from STATE.md)

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- HelixAPIClient and UserIdentityStore are ready for all Phase 5 feature services (mentions, whispers, moderation, followage, block/unblock)
- Feature services can create typed wrappers around `HelixAPIClient.execute()` following the `HelixUsersService` pattern
- Build verification pending Swift toolchain availability

## Self-Check: PASSED

---
*Phase: 05-social-moderation*
*Completed: 2026-02-07*
