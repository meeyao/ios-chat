# Phase 02: Core Chat Pipeline - Research

**Researched:** 2026-02-05
**Domain:** IRC parsing + Twitch IRC + iOS chat timeline
**Confidence:** MEDIUM

## Summary

This phase centers on implementing an IRC-based chat pipeline that can connect, authenticate, negotiate Twitch IRC capabilities, parse IRCv3 message tags, and render a single channel chat timeline with accurate timestamps and link handling. Primary sources include IRC RFCs, IRCv3 message-tag and server-time specs, and Twitch IRC documentation for concrete message formats, tags, and operational constraints (ordering, duplicates, keepalive). Apple Foundation docs for URL detection and ISO 8601 parsing were not accessible without JavaScript, so those recommendations are included with lower confidence and should be verified during planning.

The standard approach is to parse raw CRLF-delimited IRC lines into a structured IRC message (tags, prefix, command, params), then map to domain-specific models (chat message, system notice, state updates). Ordering should be stabilized using server-provided timestamps when available (IRCv3 `time` tag or Twitch `tmi-sent-ts` tag), and deduplication should be based on message IDs where present. Chat rendering should use a streaming list optimized for large volumes and update in order without blocking the UI thread.

**Primary recommendation:** Implement a strict IRC line parser with IRCv3 tag unescaping, use Twitch IRC `CAP REQ` for tags/commands/membership, and normalize timestamps using `server-time` or `tmi-sent-ts` for ordering and latency measurement.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| URLSessionWebSocketTask (Foundation) | iOS 16+ | WebSocket IRC transport | Apple-native WebSocket client; required by prior decision | 
| IRC RFC 2812 message format | RFC 2812 (2000) | Base IRC message grammar | Defines canonical IRC line framing and parameters | 
| IRCv3 message-tags | Spec (IRCv3 WG) | Tag parsing/escaping | Defines tag key/value format and escaping rules | 
| IRCv3 server-time | Spec (IRCv3 WG) | Timestamp tag format | Defines ISO 8601 `time` tag for event time | 
| Twitch IRC | Current docs | Twitch-specific IRC commands/tags | Required for Twitch chat parity with DankChat |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ISO8601DateFormatter (Foundation) | iOS 16+ | Parse `server-time` timestamps | When `time` tag is present (IRCv3) |
| NSDataDetector (Foundation) | iOS 16+ | URL detection in message text | Link parsing for timeline rendering |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| URLSessionWebSocketTask | Starscream/SwiftNIO | Adds deps; conflicts with “native URLSession” decision |
| IRCv3 `server-time` | Local receipt time | Loses ordering accuracy across network jitter |

**Installation:**
```bash
# No new packages; uses Foundation + existing dependencies
```

## Architecture Patterns

### Recommended Project Structure
```
Sources/
├── Chat/               # Chat domain models + reducers
├── IRC/                # IRC parser, tags, and wire protocol
├── Networking/         # WebSocket connection + supervisor
├── UI/                 # SwiftUI/UIView bridges for timeline
└── Storage/            # GRDB adapters for scrollback
```

### Pattern 1: Streaming Parser → Domain Mapper
**What:** Parse raw IRC lines into structured `IRCMessage`, then map to `ChatEvent`/`ChatMessage`/`SystemMessage`.
**When to use:** All inbound WebSocket frames (single or multiple CRLF-delimited lines).
**Example:**
```text
// Source: https://www.rfc-editor.org/rfc/rfc2812
message = [ ":" prefix SPACE ] command [ params ] CRLF
```

### Pattern 2: Tag-Aware Parsing with Unescaping
**What:** If a line begins with `@`, parse `key=value` pairs, unescape per IRCv3 rules, and treat tag names as case-sensitive.
**When to use:** Any Twitch IRC message when `twitch.tv/tags` is negotiated.
**Example:**
```text
// Source: https://ircv3.net/specs/extensions/message-tags.html
@aaa=bbb;ccc;example.com/ddd=eee :nick!user@host PRIVMSG #chan :Hello
```

### Pattern 3: Timestamp Normalization
**What:** Use the `time` tag (IRCv3 server-time) when present; on Twitch, use `tmi-sent-ts` (UNIX ms) when present; fallback to receipt time.
**When to use:** Ordering, latency calculations, and timeline display timestamps.
**Example:**
```text
// Source: https://ircv3.net/specs/extensions/server-time
@time=2011-10-19T16:40:51.620Z :Angel!angel@example.org PRIVMSG Wiz :Hello
```

### Anti-Patterns to Avoid
- **Parsing by naive string splits:** Breaks on trailing parameter rules and tag escaping; use RFC/IRCv3 grammar instead.
- **Assuming message ordering from Twitch:** Twitch IRC does not guarantee order and may send duplicates; use IDs/timestamps.
- **Ignoring multi-message frames:** Twitch can send multiple CRLF-delimited messages in a single WebSocket payload.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ISO 8601 timestamp parsing | Custom parser | ISO8601DateFormatter | Handles edge cases like leap seconds | 
| URL detection in text | Regex-only URL parsing | NSDataDetector | Handles URL variants reliably |

**Key insight:** Parsing IRC lines and tags must be custom per spec, but timestamps and URLs should use system formatters/detectors to avoid subtle bugs.

## Common Pitfalls

### Pitfall 1: Incorrect IRC line framing
**What goes wrong:** Treating WebSocket message boundaries as IRC line boundaries.
**Why it happens:** IRC frames are CRLF-delimited and can be batched in one WebSocket message.
**How to avoid:** Buffer incoming text and split on CRLF; handle partial lines.
**Warning signs:** Random parsing errors or missing messages under load.

### Pitfall 2: Tag unescaping errors
**What goes wrong:** Mis-parsing `\:` `\s` `\\` `\r` `\n` or leaving invalid escapes.
**Why it happens:** Ignoring IRCv3 escape rules.
**How to avoid:** Implement the exact escape mapping and drop invalid escapes as specified.
**Warning signs:** Incorrect display names, badges, or system messages.

### Pitfall 3: Timestamp inconsistencies
**What goes wrong:** Mixed use of local receipt time and server timestamps causing reordering.
**Why it happens:** Not normalizing `time` or `tmi-sent-ts`.
**How to avoid:** Normalize to a single timeline clock per message source; fallback only when tags are absent.
**Warning signs:** Messages appearing out of order or with jittery timestamps.

### Pitfall 4: Duplicate or missing messages
**What goes wrong:** Duplicates shown or messages dropped.
**Why it happens:** Twitch IRC may resend messages and does not guarantee order; IDs are not used.
**How to avoid:** Deduplicate on `id` tag when available, otherwise on `(timestamp, user, text)` heuristics.
**Warning signs:** Double entries or missing chat lines during spikes.

## Code Examples

Verified patterns from official sources:

### Twitch IRC Capability Negotiation
```text
// Source: https://dev.twitch.tv/docs/chat/irc/
CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands
```

### Twitch IRC Keepalive
```text
// Source: https://dev.twitch.tv/docs/chat/irc/
PING :tmi.twitch.tv
PONG :tmi.twitch.tv
```

### IRC Message Format (RFC 2812)
```text
// Source: https://www.rfc-editor.org/rfc/rfc2812
message = [ ":" prefix SPACE ] command [ params ] CRLF
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| RFC1459-only parsing | IRCv3 message tags + server-time | IRCv3 era | Required for metadata (badges, timestamps, IDs) |
| Local receipt timestamps | Server-provided timestamps | IRCv3 `server-time`, Twitch `tmi-sent-ts` | Better ordering and latency tracking |

**Deprecated/outdated:**
- Non-SSL Twitch IRC WebSocket endpoints are decommissioned; use `wss://irc-ws.chat.twitch.tv:443`.

## Open Questions

1. **Apple Foundation URL detection and ISO 8601 parsing specifics**
   - What we know: NSDataDetector and ISO8601DateFormatter are the standard Foundation APIs.
   - What's unclear: Exact configuration needed for Twitch/IRC data (fractional seconds, leap seconds).
   - Recommendation: Verify with Apple docs or small spike tests in Phase 2 planning.

## Sources

### Primary (HIGH confidence)
- https://www.rfc-editor.org/rfc/rfc2812 - IRC message framing, command/params grammar
- https://www.rfc-editor.org/rfc/rfc1459 - Baseline IRC framing and semantics
- https://ircv3.net/specs/extensions/message-tags.html - Tag format, escaping, capabilities
- https://ircv3.net/specs/extensions/server-time - `time` tag ISO 8601 format
- https://dev.twitch.tv/docs/chat/irc/ - Twitch IRC endpoints, CAP REQ, tags, keepalive, ordering notes

### Secondary (MEDIUM confidence)
- https://dev.twitch.tv/docs/chat/send-receive-messages/ - Message send/receive conventions (API context)

### Tertiary (LOW confidence)
- https://developer.apple.com/documentation/foundation/nsdatadetector - Link detection (JS-gated)
- https://developer.apple.com/documentation/foundation/iso8601dateformatter - ISO 8601 parsing (JS-gated)
- https://developer.apple.com/documentation/foundation/urlsessionwebsockettask - WebSocket API (JS-gated)

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM - Apple docs inaccessible without JS; IRC/Twitch sources solid
- Architecture: HIGH - Directly derived from IRC/Twitch specs and message formats
- Pitfalls: HIGH - Explicitly documented in Twitch IRC docs and IRCv3 specs

**Research date:** 2026-02-05
**Valid until:** 2026-03-07
