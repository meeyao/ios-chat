# Phase 05: Social + Moderation - Research

**Researched:** 2026-02-07
**Domain:** Twitch chat social features and moderation (IRC + Helix + EventSub)
**Confidence:** MEDIUM

## Summary

Phase 05 relies on Twitch’s official chat stack: IRC for real-time chat transport, Helix APIs for moderation actions and room settings, and EventSub for whisper receipts (and optional moderation events). The IRC docs confirm reply metadata and message IDs are delivered via tags, and that IRC command support is limited, so moderation actions should use Helix endpoints for reliability and permissions.

Whispers must be sent via the Helix Send Whisper endpoint and received via EventSub. Whispering has strict rate limits, silent drops, and a verified phone requirement, so UX must handle “success without delivery” and permission gating. Room state (slow/followers/subscriber/emote/unique) should be driven by Helix Update Chat Settings and reconciled with IRC ROOMSTATE or EventSub updates to avoid stale UI. Followage and user profiles depend on Helix Get Users and Get Channel Followers with moderator:read:followers scope.

**Primary recommendation:** Implement moderation and room-state actions via Helix APIs, treat IRC/EventSub as the source of truth for state updates, and guard all UI actions by required scopes and phone verification rules.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Twitch IRC | N/A (service) | Real-time chat transport, message tags (reply IDs, ROOMSTATE, CLEARMSG/CLEARCHAT) | Official chat transport for chat clients; provides message IDs and room-state events | 
| Twitch Helix API | N/A (service) | Moderation actions, chat settings, user profile, followage, whispers send | Official API for moderation and chat settings; required for full feature parity | 
| Twitch EventSub (WebSocket/Webhook) | N/A (service) | Whisper received events; optional moderation/chat-settings events | Official event stream for whispers and moderation updates | 

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| GRDB.swift (SQLite + FTS) | Project decision | Persist mentions/whispers/replies tabs and search | If tabs need offline history, filters, or FTS | 

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Helix moderation endpoints | IRC chat commands (e.g., sending /timeout as text) | IRC docs state only /me is supported; Helix is reliable and permissioned | 
| Helix chat settings | IRC-only ROOMSTATE | ROOMSTATE reflects state but not a reliable action API | 

**Installation:**
```bash
# No packages; uses Twitch network APIs (IRC + Helix + EventSub)
```

## Architecture Patterns

### Recommended Project Structure
```
Chat/
├── IRC/                # IRC connection + parsing + tags
├── EventSub/           # Whisper received + moderation/chat settings events
├── Moderation/         # Helix moderation calls + permission checks
├── Social/             # Mentions/whispers/replies classification
└── Commands/           # Custom commands + suggestions
UI/
├── Tabs/               # Mentions, whispers, replies
└── UserPopup/          # Profile, followage, block actions
```

### Pattern 1: Reply threading from IRC tags
**What:** Use IRC message tags to link replies to parent messages and threads.
**When to use:** Building reply input and thread view for PRIVMSGs.
**Example:**
```text
# Source: https://dev.twitch.tv/docs/chat/irc/
@reply-parent-msg-id=885196de-cb67-427a-baa8-82f9b0fcd05f PRIVMSG #lovingt3s :absolutely!
```

### Pattern 2: Room-state controls via Helix, state sync via IRC/EventSub
**What:** Call Helix Update Chat Settings for actions; reconcile UI with ROOMSTATE or chat settings updates.
**When to use:** Toggling slow/followers/subscriber/emote/unique modes.
**Example:**
```text
# Source: https://dev.twitch.tv/docs/api/reference/#update-chat-settings
PATCH https://api.twitch.tv/helix/chat/settings
```

### Pattern 3: Moderation actions via Helix, feedback via IRC NOTICE/CLEARMSG/CLEARCHAT
**What:** Use Helix Ban/Unban/Delete endpoints; use IRC tags/messages for result feedback and timeline updates.
**When to use:** Timeout/ban/unban/delete from user popup or message actions.
**Example:**
```text
# Source: https://dev.twitch.tv/docs/chat/irc/
@msg-id=delete_message_success :tmi.twitch.tv NOTICE #bar :The message from foo is now deleted.
```

### Anti-Patterns to Avoid
- **IRC-only moderation commands:** IRC docs state only /me is supported; rely on Helix APIs for mod actions.
- **Assuming reply tags always exist:** Only replies include reply-parent tags; handle missing tags safely.
- **Trusting whisper send as delivered:** Send Whisper can return 204 even when silently dropped.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Ban/timeout/unban | Custom IRC command text | Helix Ban/Unban endpoints | Official permission checks + consistent behavior | 
| Delete message/clear chat | Local-only delete | Helix Delete Chat Messages + IRC CLEARMSG/CLEARCHAT | Ensures server-side deletion and cross-client parity | 
| Room state toggles | Custom flags | Helix Update Chat Settings | Corrects state at server and broadcasts updates | 
| Whisper transport | Custom messaging | Helix Send Whisper + EventSub Whisper Received | Official limits + delivery semantics | 
| Followage | Local timers | Helix Get Channel Followers | Source of truth for followed_at | 

**Key insight:** Twitch’s chat features are permissioned and audited; custom client-side behavior will drift or fail without Helix/EventSub.

## Common Pitfalls

### Pitfall 1: Missing scopes for moderation actions
**What goes wrong:** Mod buttons fail or appear enabled but return 401/403.
**Why it happens:** Helix endpoints require specific scopes (e.g., moderator:manage:banned_users, moderator:manage:chat_messages, moderator:manage:chat_settings).
**How to avoid:** Gate UI actions on granted scopes, and surface error states from Helix responses.
**Warning signs:** 401/403 responses, NOTICE messages with failure msg-id.

### Pitfall 2: Reply/mention parsing without tags
**What goes wrong:** Replies render as regular messages or thread links break.
**Why it happens:** IRC reply tags only appear when tags capability is enabled and message is a reply.
**How to avoid:** Require `twitch.tv/tags` capability; treat tags as optional.
**Warning signs:** Missing `id` or `reply-parent-msg-id` in PRIVMSG tags.

### Pitfall 3: Whisper delivery uncertainty
**What goes wrong:** UI shows “sent” but message never arrives.
**Why it happens:** Whisper API may silently drop messages; users may block whispers or lack verified phone.
**How to avoid:** Message UI should note “sent (delivery not guaranteed)” and handle 400/401/403 responses.
**Warning signs:** Frequent 204 responses with no corresponding EventSub receipt or user reply.

### Pitfall 4: Room state drift
**What goes wrong:** UI toggles out of sync with actual room settings.
**Why it happens:** Actions update local state but not reconciled with ROOMSTATE or Helix Get Chat Settings.
**How to avoid:** Treat ROOMSTATE / Get Chat Settings as authoritative; reconcile after action.
**Warning signs:** Mismatched slow/follower/subscriber indicators.

## Code Examples

Verified patterns from official sources:

### Replying to a message via IRC tag
```text
# Source: https://dev.twitch.tv/docs/chat/irc/
@reply-parent-msg-id=b34ccfc7-4977-403a-8a94-33c6bac34fb8 PRIVMSG #ronni :Good idea!
```

### ROOMSTATE tags after join/state change
```text
# Source: https://dev.twitch.tv/docs/chat/irc/
@emote-only=0;followers-only=-1;r9k=0;room-id=12345678;slow=0;subs-only=0 :tmi.twitch.tv ROOMSTATE #bar
```

### Send Whisper (Helix)
```text
# Source: https://dev.twitch.tv/docs/api/reference/#send-whisper
POST https://api.twitch.tv/helix/whispers
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| IRC-only clients | EventSub + Helix + IRC | Docs emphasize EventSub/Helix (2024+) | Full moderation/whisper support and richer metadata | 

**Deprecated/outdated:**
- IRC command usage beyond `/me`: IRC docs state only /me is supported; rely on Helix for moderation actions.

## Open Questions

1. **Supibot command suggestions API**
   - What we know: Parity checklist requires Supibot suggestions.
   - What's unclear: Endpoint, auth, and response format used in DankChat.
   - Recommendation: Inspect DankChat source or Supinic/Supibot docs before planning tasks.

2. **Followage availability without moderator scope**
   - What we know: Get Channel Followers requires moderator:read:followers to return followed_at.
   - What's unclear: UX expectations when the user is not a moderator/broadcaster.
   - Recommendation: Plan for “unknown followage” state unless scope is granted.

## Sources

### Primary (HIGH confidence)
- https://dev.twitch.tv/docs/chat/irc/ - IRC concepts, tags, replies, ROOMSTATE, NOTICE
- https://dev.twitch.tv/docs/chat/moderation/ - Moderation workflows and endpoints
- https://dev.twitch.tv/docs/api/reference/#ban-user - Ban/timeout API
- https://dev.twitch.tv/docs/api/reference/#delete-chat-messages - Delete message/clear chat API
- https://dev.twitch.tv/docs/api/reference/#get-chat-settings - Chat settings read
- https://dev.twitch.tv/docs/api/reference/#update-chat-settings - Chat settings update
- https://dev.twitch.tv/docs/api/reference/#send-whisper - Whisper send API
- https://dev.twitch.tv/docs/chat/whispers/ - Whisper receive via EventSub and limitations
- https://dev.twitch.tv/docs/api/reference/#get-users - User profile data
- https://dev.twitch.tv/docs/api/reference/#block-user - Block user
- https://dev.twitch.tv/docs/api/reference/#unblock-user - Unblock user
- https://dev.twitch.tv/docs/api/reference/#get-channel-followers - Followage data

### Secondary (MEDIUM confidence)
- https://dev.twitch.tv/docs/chat/send-receive-messages/ - Reply-parent message ID in send chat message

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - direct Twitch official docs.
- Architecture: MEDIUM - derived from official capabilities and project constraints.
- Pitfalls: MEDIUM - based on official docs + common integration issues.

**Research date:** 2026-02-07
**Valid until:** 2026-03-09
