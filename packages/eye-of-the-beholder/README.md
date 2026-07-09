# eye-of-the-beholder

Visual layout review. Observation before explanation: screenshot first, describe what you see, then diagnose. Design-TDD for CSS.

Catches cramped text, missing margins, disproportionate spacing, broken WCAG contrast, ad-hoc token use, snapping transitions, out-of-sync animations, layout that jumps between states, and content that disappears before its container does. It also helps translate a user who has taste but no design vocabulary into a direction, and reads uploaded screenshots as feedback rather than as literal designs.

This plugin ships five sister skills:

- **`/eye-of-the-beholder`** (default): diagnostic, per-change visual review.
- **`/taste-test`**: direction elicitation for someone who has taste but cannot describe it. Shows divergent options and reads the reaction instead of asking for a spec, then records the result in a growing `visual-language.md`.
- **`/fat-marker-sketch`**: reads an uploaded screenshot or image as low-fidelity feedback (a fat-marker sketch), not a literal design to reproduce. The default reading for any image shared as a design cue.
- **`/art-director`**: upstream identity work. Captures brand, visual language, and design-system architecture BEFORE CSS exists. Not for small UI tweaks; for new products, brand refreshes, or first-time design-system foundation.
- **`/visual-inspection`**: reference matching. Forces a screenshot-plus-measurement loop when a new element must match an existing visual reference on named axes such as padding, radius, font, color, size, or alignment.

## Installation

```bash
claude plugins install eye-of-the-beholder@laicluse-agent-fieldkit
codex plugin add eye-of-the-beholder@laicluse-agent-fieldkit
```

## Skills

### `/eye-of-the-beholder`

Reviews the current visual state. Captures a screenshot, lists concrete observations, then maps each observation to a diagnosis: token, spacing scale, contrast ratio, animation timing, layout shift, or another visible cause. Includes a complaint-to-axis table that turns a gut-word ("too busy", "it jumps", "looks cheap") into the axis to scan, a layout-stability axis for unwanted motion between states, a one-meaning-per-channel rule for visual semantics, and a convergence guard that routes to `/taste-test` or a first-principles reset when the same complaint survives two rounds.

### `/taste-test`

Elicits a visual direction from a user who knows what they like when they see it but cannot describe it. Renders 3 to 5 genuinely divergent options side by side, offers reaction-card word-axes to point at instead of asking for a specification, harvests current genre exemplars for transferable moves (not copied pixels), and actively avoids the documented AI-slop tells. Records each decision in a growing `visual-language.md` so the direction is not re-litigated every session. Sits between `/art-director` (heavy, once) and `/eye-of-the-beholder` (diagnostic, per change).

### `/fat-marker-sketch`

Reads an uploaded screenshot or image as a fat-marker sketch: low-fidelity feedback pointing at intent, not a design to reproduce. Extracts the complaint, target, direction, content, and topology; ignores the annotation layer (arrow colors, callout bubbles, CleanShot or Preview chrome, hand-drawn boxes). Writes an interpretation readback before the first edit and pins the single axis when a real reference is being borrowed. Routes to `/visual-inspection` when the user states match-intent.

### `/art-director`

Produces `brand.md` + `visual-language.md` + `design-system/` skeleton from stakeholder interviews, competitive scan, and brand strategy. Three modules: brand identity discovery, visual language translation across type / color / form / motion / photography, and design-system architecture with token layers and component taxonomy. Artefacts become the standard that the session's build-time discipline applies per feature and eye-of-the-beholder verifies per change.

### `/visual-inspection`

Compares a reference element and the result side by side. The user names the axis; the skill records the reference value, result value, match verdict, and screenshot evidence. It is stricter than an open visual review: every named axis stays open until it matches or the user accepts the deviation.

## Auto-trigger

`/eye-of-the-beholder` activates DURING and AFTER layout CSS, color token, contrast, layout-stability, or animation work, to scan the rendered result. Also activates when a gut-word complaint ("too busy", "it jumps", "looks cheap", "off") needs translating into an axis to scan.

`/fat-marker-sketch` activates when the user shares an image (screenshot, mockup, capture) as a design cue, and especially when annotation markup (arrows, callouts, numbered circles, highlighter, CleanShot or Preview markup) is present. It governs how the incoming image is read as intent; after the resulting change is rendered, `/eye-of-the-beholder` scans the render.

`/taste-test` activates when the user reacts with a gut-word and no specification, when a new screen has no established direction and they cannot describe one, or when two rounds of pixel iteration have not converged. It is not for "make it match this reference" (that is visual-inspection) or full brand work (that is art-director).

`/art-director` activates only on explicit brand / art-direction / design-system-architecture requests, or at the start of a new product or brand refresh. Strict triage: it does NOT auto-fire on per-component or per-view design work.

`/visual-inspection` activates when a user points at a reference element and asks for the result to match it on one or more visual axes, with match-intent stated. It is not for general "make it better" review (that remains eye-of-the-beholder) or for reading an uploaded image as feedback (that is fat-marker-sketch).

## Why observation first

Skipping straight to diagnosis is how AI reviews end up validating their own assumptions. The eye-of-the-beholder skill insists on at least three concrete observations before any cause is named, so the diagnosis has to fit what is actually on screen.

The art-director skill works one level up: brand attributes and visual-language decisions captured upfront are the reference against which observations get their meaning. "Feels off" is unverifiable until there is a documented standard to feel off from. Taste-test is the lighter, per-direction way to produce that standard when the user cannot describe it: it shows options, reads the reaction, and records the result. Visual-inspection works one level tighter: a named reference turns the visual question into a measurement loop. Fat-marker-sketch guards the input side, so an uploaded image is read as intent rather than copied as a design.
