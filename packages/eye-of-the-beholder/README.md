# eye-of-the-beholder

Visual layout review. Observation before explanation: screenshot first, describe what you see, then diagnose. Design-TDD for CSS.

Catches cramped text, missing margins, disproportionate spacing, broken WCAG contrast, ad-hoc token use, snapping transitions, out-of-sync animations, and content that disappears before its container does.

This plugin ships three sister skills:

- **`/eye-of-the-beholder`** (default): diagnostic, per-change visual review.
- **`/art-director`**: upstream identity work. Captures brand, visual language, and design-system architecture BEFORE CSS exists. Not for small UI tweaks; for new products, brand refreshes, or first-time design-system foundation.
- **`/visual-inspection`**: reference matching. Forces a screenshot-plus-measurement loop when a new element must match an existing visual reference on named axes such as padding, radius, font, color, size, or alignment.

## Installation

```bash
claude plugins install eye-of-the-beholder@laicluse-agent-fieldkit
codex plugin add eye-of-the-beholder@laicluse-agent-fieldkit
```

## Skills

### `/eye-of-the-beholder`

Reviews the current visual state. Captures a screenshot, lists concrete observations, then maps each observation to a diagnosis: token, spacing scale, contrast ratio, animation timing, or another visible cause.

### `/art-director`

Produces `brand.md` + `visual-language.md` + `design-system/` skeleton from stakeholder interviews, competitive scan, and brand strategy. Three modules: brand identity discovery, visual language translation across type / color / form / motion / photography, and design-system architecture with token layers and component taxonomy. Artefacts become the standard that the session's build-time discipline applies per feature and eye-of-the-beholder verifies per change.

### `/visual-inspection`

Compares a reference element and the result side by side. The user names the axis; the skill records the reference value, result value, match verdict, and screenshot evidence. It is stricter than an open visual review: every named axis stays open until it matches or the user accepts the deviation.

## Auto-trigger

`/eye-of-the-beholder` activates DURING and AFTER layout CSS, color token, contrast, or animation work. Also activates when the user shares a screenshot or screen recording with spacing, contrast, color-token, or timing concerns.

`/art-director` activates only on explicit brand / art-direction / design-system-architecture requests, or at the start of a new product or brand refresh. Strict triage: it does NOT auto-fire on per-component or per-view design work.

`/visual-inspection` activates when a user points at a reference element and asks for the result to match it on one or more visual axes. It is not for general "make it better" review; that remains eye-of-the-beholder.

## Why observation first

Skipping straight to diagnosis is how AI reviews end up validating their own assumptions. The eye-of-the-beholder skill insists on at least three concrete observations before any cause is named, so the diagnosis has to fit what is actually on screen.

The art-director skill works one level up: brand attributes and visual-language decisions captured upfront are the reference against which observations get their meaning. "Feels off" is unverifiable until there is a documented standard to feel off from. Visual-inspection works one level tighter: a named reference turns the visual question into a measurement loop.
