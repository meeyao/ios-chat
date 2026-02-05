# DankChat/Chatterino iOS Port

## What This Is

An iOS Twitch chat client that combines the best of DankChat (mobile) and Chatterino (desktop) into a single, polished experience for iPhone and iPad. Users sign in with their Twitch account, join multiple channels in a tabbed layout, and use familiar QoL features like third-party emotes and highlights.

## Core Value

Users can reliably chat in multiple Twitch channels on iOS with the same core experience they already have on Android/desktop.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Twitch login and real-time chat
- [ ] Multi-channel tabs
- [ ] Emote rendering for 7TV/BTTV/FFZ
- [ ] Badges and user colors
- [ ] Search and highlights

### Out of Scope

- Video streaming playback — this is a chat-first client
- Full moderation suite — defer until core chat parity lands

## Context

- Targeting feature parity for core chat behaviors found in DankChat and Chatterino
- Hybrid UX approach: pick the best interaction patterns from both apps
- Initial release is internal only, with an eye toward community release later

## Constraints

- **Platform**: iOS 16+ on iPhone and iPad — target a universal app
- **Authentication**: Must support Twitch account login for chat
- **Third-party emotes**: 7TV/BTTV/FFZ support required for parity

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Hybrid UX (DankChat + Chatterino) | Best-in-class experience across mobile and desktop patterns | — Pending |
| Core parity MVP scope | Focus on essential chat features first | — Pending |
| iOS 16+ universal app | Modern APIs with iPhone + iPad coverage | — Pending |

---
*Last updated: 2026-02-05 after initialization*
