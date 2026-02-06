# Phase 4: Emotes + Badges Ecosystem - Context

**Gathered:** 2026-02-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver emote and badge rendering parity with DankChat for chat messages, including Twitch/BTTV/FFZ/7TV emotes (with caching), animated GIF control, emote menu (tabs + recents), emote suggestions, badge rendering + visibility toggles, and 7TV live updates.

</domain>

<decisions>
## Implementation Decisions

### Emote Rendering In Chat
- Emote size should be DankChat-like (larger than text).
- Emotes should align like characters (baseline-ish rather than vertically centered).
- By default, collapse a single space between adjacent emotes: `emote + space + emote`.
- Even with space-collapsing enabled, long emote chains may wrap between emotes (avoid unbroken runs).
- Provider collision precedence (same emote code): `Twitch > 7TV > BTTV > FFZ`.
- Line height vs scaling for tall emotes: follow DankChat behavior (research/verify against DankChat).

### Emote Menu + Recents UX
- Emote menu opens via an emote button in the composer; the button is always visible.
- Emote menu presentation is a bottom sheet: opens half-height and supports drag to full height.
- Tabs exist and are ordered: `Recents, Twitch, 7TV, BTTV, FFZ, Emoji`.
- Default tab on open: `Recents`.
- Search field is always visible in the emote menu (supports large provider sets like 7TV).
- Recents are captured from both sent emotes and tapped emotes from the menu.
- Recents list limit: ~20 items.

### Emote Suggestions
- Suggestions trigger for both `:`-prefixed input and normal word-prefix typing.
- Matching uses prefix + fuzzy matching.
- Suggestions include emotes from all enabled providers (mixed results).
- Accept via tap.
- Selecting a suggestion does not send the message; message sends only on Return/Enter.
- Selecting a suggestion replaces the current token and inserts a trailing space.
- Suggestions auto-dismiss on whitespace.
- Visible suggestions count: 3-5.

### Badges: Display + Visibility Toggles
- All badges render before the username.
- Ordering: Twitch badges first, then third-party badges (7TV/FFZ/BTTV/etc).
- Badge visibility is global (applies across all channels).
- Badge customization is fine-grained across providers and badge categories ("full customization per platform badge selections").
- Default visibility: all badges enabled/visible.
- Unknown/new badge types default to visible.
- Interactions:
  - Tap badge: show badge name.
  - Tap username: open user card.

### Caching + 7TV Live Updates
- Cache storage: disk + memory.
- 7TV live updates should use 7TV's live-update mechanism to pull changes.
- When providers are down, use last-known cache (graceful degradation).
- When emote sets update, apply changes to new messages only (do not re-render existing history).
- BTTV/FFZ refresh cadence: refresh on channel join + periodic refresh.
- Outage UX: show a non-blocking banner/toast when a provider is down (while still rendering from cache).

### OpenCode's Discretion
- Exact visuals of the bottom sheet, tab styling, search UI, and toast/banner presentation.
- Exact periodic refresh interval for BTTV/FFZ (as long as it's periodic and reasonable).
- Exact copy/text for outage banner/toast and badge-name tooltip.

</decisions>

<specifics>
## Specific Ideas

- Emote-emote space collapsing should be Chatterino-like (removing the space between adjacent emotes).
- Badge tap shows badge name; username tap opens user card.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-emotes-badges-ecosystem*
*Context gathered: 2026-02-06*
