# Phase 4: Emotes + Badges Ecosystem - Research

**Researched:** 2026-02-06
**Domain:** iOS text layout + emote/badge providers + image pipeline
**Confidence:** MEDIUM

## Summary

This research focused on how to render inline emotes and badges with correct wrapping and baseline alignment, and how to build the provider data pipeline for Twitch/BTTV/FFZ/7TV with caching and live updates. The established approach on iOS is to use TextKit 2 with attributed strings and attachments for inline media, then wrap that in SwiftUI via a UIKit text view. For images, SDWebImage is the standard stack for async loading, memory+disk cache, and animated image support, with SDWebImageWebPCoder registering WebP decoding where needed.

Provider APIs are a mix of official docs (Twitch Helix) and public JSON endpoints (BTTV/FFZ/7TV). Twitch requires app or user tokens for emotes and badges and provides a templated CDN URL that should be used for rendering. FFZ and BTTV endpoints return global sets directly; 7TV’s global set shows a `host.url` plus `files` list to build URLs. 7TV live updates could not be verified from official docs in this environment and remains an open question to validate.

**Primary recommendation:** Use TextKit 2 with `NSTextAttachment` in a UIKit-backed chat renderer, SDWebImage + SDWebImageWebPCoder for image loading/animation, and a provider registry that normalizes Twitch/BTTV/FFZ/7TV into a single emote/badge model with GRDB-backed caching.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| UIKit TextKit 2 (`NSTextContentStorage`, `NSTextLayoutManager`) | iOS 15+ | Inline text layout with attachments | Apple’s modern text layout system for custom text rendering. | 
| `NSTextAttachment` + `NSAttributedString` | iOS 7+ | Inline image attachments | Official attachment mechanism for attributed strings. |
| SDWebImage | 5.21.x (latest listed: 5.21.5) | Async image loading + memory/disk cache | Provides async downloader, memory+disk cache, animated image pipeline. |
| SDWebImageWebPCoder | 0.15.x (latest listed: 0.15.0) | WebP decode/encode | Adds WebP support and registration via coder manager. |
| URLSession | iOS 16+ | Provider API calls | Locked in stack constraints. |
| GRDB | Project standard | Cache provider metadata | Locked in stack constraints. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI (`UIViewRepresentable`) | iOS 16+ | Host UIKit chat renderer | Use SwiftUI for outer layout while keeping TextKit 2 rendering. |
| `UICollectionView` + diffable data source | iOS 13+ | Emote menu virtualization | Use for 1000+ emotes with smooth scrolling and reuse. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| TextKit 2 | TextKit 1 (`NSLayoutManager` + `NSTextStorage`) | Older API, fewer modern layout features. |
| UIKit text view | Pure SwiftUI `Text` + `AttributedString` | SwiftUI text is not ideal for animated attachments. |

**Installation:**
```bash
# SwiftPM
https://github.com/SDWebImage/SDWebImage.git
https://github.com/SDWebImage/SDWebImageWebPCoder.git
```

## Architecture Patterns

### Recommended Project Structure
```
Sources/
├── Chat/                 # chat rendering + message models
├── Emotes/               # provider clients + normalization
├── Badges/               # badge models + rendering
├── ImagePipeline/        # SDWebImage configuration
├── Cache/                # GRDB caches + persistence
└── UI/                   # emote menu + suggestions + settings
```

### Pattern 1: TextKit 2 inline emote rendering
**What:** Build an `NSAttributedString` containing `NSTextAttachment` for emotes; render via a TextKit-backed `UITextView`/custom view wrapped in SwiftUI.
**When to use:** All chat message rows that need inline emotes, baseline alignment, and wrapping control.
**Example:**
```swift
// Source: https://developer.apple.com/documentation/uikit/display-text-with-a-custom-layout
let textContainer = NSTextContainer(size: .zero)
textContainer.widthTracksTextView = true

let layoutManager = NSLayoutManager()
layoutManager.addTextContainer(textContainer)
textStorage.addLayoutManager(layoutManager)

textView = UITextView(frame: .zero, textContainer: textContainer)
```

### Pattern 2: SDWebImage animated image pipeline
**What:** Use `SDAnimatedImageView`/`SDAnimatedImage` for animated emotes and SDWebImage’s cache.
**When to use:** Any emote or badge that may be animated (GIF/WebP/APNG).
**Example:**
```swift
// Source: https://github.com/SDWebImage/SDWebImage
let imageView = SDAnimatedImageView()
let animatedImage = SDAnimatedImage(named: "image.gif")
imageView.image = animatedImage
```

### Pattern 3: Register WebP coder at launch
**What:** Register WebP coder with SDWebImage’s coder manager.
**When to use:** 7TV/BTTV/FFZ provide WebP assets.
**Example:**
```swift
// Source: https://github.com/SDWebImage/SDWebImageWebPCoder
let WebPCoder = SDImageWebPCoder.shared
SDImageCodersManager.shared.addCoder(WebPCoder)
```

### Anti-Patterns to Avoid
- **Rendering emotes as separate views per token:** breaks baseline alignment and adds layout overhead; use attachments in a single text layout run.
- **Using Twitch `images` URLs directly:** Twitch docs instruct using the `template` URL instead of the `images` object.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image cache + decoding | Custom disk cache | SDWebImage cache | Handles memory/disk eviction and background decoding. |
| Animated GIF/WebP decoding | Custom decoder | SDWebImage animated image pipeline + WebPCoder | Covers animated frames and formats. |
| Text layout + wrapping | Manual line-breaking | TextKit 2 + attachments | Correct baseline alignment and wrapping rules. |

**Key insight:** Image decoding and text layout are error-prone and performance-critical; use SDWebImage and TextKit 2 to avoid stutters and layout bugs.

## Common Pitfalls

### Pitfall 1: Using Twitch `images` URLs
**What goes wrong:** Animations and theme variants are lost and image URLs may be wrong.
**Why it happens:** Twitch docs provide `images` but instruct to use `template` instead.
**How to avoid:** Always build URLs from `template` with format/scale/theme values.
**Warning signs:** Emotes appear only as static PNG or wrong theme.

### Pitfall 2: Missing Helix auth requirements
**What goes wrong:** Twitch emote/badge fetches return 401s.
**Why it happens:** Helix endpoints require app or user tokens + Client-ID.
**How to avoid:** Use app access tokens for emotes/badges and attach Client-ID.
**Warning signs:** 401s from `helix/chat/emotes` or `helix/chat/badges`.

### Pitfall 3: Re-rendering chat history on emote updates
**What goes wrong:** UI stalls and scroll jumps.
**Why it happens:** Applying updates to all prior messages is expensive.
**How to avoid:** Apply emote set changes to new messages only (per phase decision).
**Warning signs:** Large CPU spikes during emote updates.

### Pitfall 4: Unbounded cache growth
**What goes wrong:** Disk usage balloons and slow cache lookup.
**Why it happens:** No eviction policy for emote assets or metadata.
**How to avoid:** Configure SDWebImage cache limits + GRDB cleanup jobs.
**Warning signs:** Cache size grows without limit.

## Code Examples

Verified patterns from official sources:

### Create a TextKit-backed `UITextView`
```swift
// Source: https://developer.apple.com/documentation/uikit/display-text-with-a-custom-layout
let textContainer = NSTextContainer(size: .zero)
textContainer.widthTracksTextView = true

let layoutManager = NSLayoutManager()
layoutManager.addTextContainer(textContainer)
textStorage.addLayoutManager(layoutManager)

textView = UITextView(frame: .zero, textContainer: textContainer)
```

### Register WebP coder
```swift
// Source: https://github.com/SDWebImage/SDWebImageWebPCoder
let WebPCoder = SDImageWebPCoder.shared
SDImageCodersManager.shared.addCoder(WebPCoder)
```

### Animated image view setup
```swift
// Source: https://github.com/SDWebImage/SDWebImage
let imageView = SDAnimatedImageView()
let animatedImage = SDAnimatedImage(named: "image.gif")
imageView.image = animatedImage
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| TextKit 1 (`NSLayoutManager` + `NSTextStorage`) | TextKit 2 (`NSTextContentStorage`, `NSTextLayoutManager`) | iOS 15+ | Better custom layout pipeline for attachments. |
| Static PNG emotes | Animated emotes (GIF/WebP/APNG) | SDWebImage 5.x | Requires animated image pipeline and coder registration. |

**Deprecated/outdated:**
- TextKit 1-only custom layout for inline media (use TextKit 2 on iOS 16+).

## Open Questions

1. **7TV live updates transport and payloads**
   - What we know: 7TV provides emote sets via REST (`/v3/emote-sets/global`) with host/file metadata.
   - What's unclear: Official event API endpoint, subscription model, and payload schema for live updates.
   - Recommendation: Validate 7TV event API (WebSocket) and reconnection/backoff guidelines before implementation.

2. **BTTV/FFZ official API docs**
   - What we know: Public JSON endpoints for global sets respond as expected.
   - What's unclear: Official rate limits, caching headers, and channel endpoint patterns.
   - Recommendation: Confirm provider docs or community references for rate limits and refresh cadence.

## Sources

### Primary (HIGH confidence)
- https://developer.apple.com/tutorials/data/documentation/uikit/nstextattachment.json - `NSTextAttachment` and attachment usage
- https://developer.apple.com/tutorials/data/documentation/uikit/nstextcontentstorage.json - TextKit 2 content storage
- https://developer.apple.com/documentation/uikit/display-text-with-a-custom-layout - TextKit sample code
- https://dev.twitch.tv/docs/api/reference/#get-global-emotes - Helix global emotes endpoint and template URL guidance
- https://dev.twitch.tv/docs/api/reference/#get-channel-emotes - Helix channel emotes endpoint
- https://dev.twitch.tv/docs/api/reference/#get-global-chat-badges - Helix global badges endpoint
- https://dev.twitch.tv/docs/api/reference/#get-channel-chat-badges - Helix channel badges endpoint
- https://github.com/SDWebImage/SDWebImage - SDWebImage features and animated image pipeline
- https://github.com/SDWebImage/SDWebImageWebPCoder - WebP coder registration and usage

### Secondary (MEDIUM confidence)
- https://api.betterttv.net/3/cached/emotes/global - BTTV global emote response shape
- https://cdn.betterttv.net/emote/54fa8f1401e468494b85b537/1x - BTTV CDN URL pattern (verified by image response)
- https://api.frankerfacez.com/v1/set/global - FFZ global emote response shape and CDN URLs
- https://7tv.io/v3/emote-sets/global - 7TV global emote set response with host/files

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Apple docs + SDWebImage repos are authoritative.
- Architecture: MEDIUM - TextKit patterns are clear; 7TV live updates unverified.
- Pitfalls: MEDIUM - Twitch docs clear; third-party provider limits not verified.

**Research date:** 2026-02-06
**Valid until:** 2026-03-08
