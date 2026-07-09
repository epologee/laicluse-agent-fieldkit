---
name: fat-marker-sketch
user-invocable: true
description: Read an uploaded screenshot or image as low-fidelity feedback, a fat-marker sketch, not a literal design to reproduce. Use when the user shares a PNG, screenshot, mockup, or capture as a design cue, and especially when annotation markup (arrows, callouts, numbered circles, highlighter strokes, boxes, CleanShot or Preview markup) is present.
---

# Fat marker sketch

## The real problem

The user uploads a PNG to show what they mean. The reflex is to treat those pixels as a specification: the arrow color becomes a UI color, the callout bubble becomes a component, the CleanShot toolbar styling bleeds into the product, the rough box the user drew around a region becomes a literal bordered container. The image was a gesture, and it got read as a blueprint.

Almost every image a non-designer uploads is a *fat marker sketch*: a low-fidelity pointer at intent, drawn with whatever tool was at hand, carrying a complaint and a direction but not a design. Reading it literally is the single most common way image-driven design work goes wrong. This skill exists to make the low-fidelity reading the default and the literal reading the exception that has to be earned.

The name comes from Shape Up (Basecamp): a fat marker sketch is drawn with a pen so thick that detail is impossible on purpose. The low fidelity is a feature. It keeps the conversation on structure and intent, and it stops fine detail in the sketch from anchoring the people who read it afterward. When a user hands you a screenshot with a red arrow and a scribbled note, they are handing you a fat marker sketch even if the underlying pixels happen to be crisp.

## Default classification

**An uploaded image is a fat marker sketch unless the user earns the exception.** Start there, every time, before you look at a single pixel as reference.

The exception (treat the image as a literal visual reference to match) is earned only when the user names it explicitly:

- Match-intent words: "pixel-perfect", "match this exactly", "precies zo", "exact zo", "identiek", "1:1", "make it look like this".
- The user names a real product element, brand asset, or Figma frame as the thing to reproduce ("our actual dashboard", "the Figma hero frame", "the real app").
- The user says the annotation itself is the design ("use these exact colors", "this is the mockup, build it").

Absent one of those, the image is feedback. This holds even when the pixels are sharp, even when the layout looks deliberate, even when the user clearly spent time on it. Effort in the sketch is not permission to copy it. When the image contains both product UI and annotation markup, split them: product pixels can be evidence, annotation pixels are commentary.

If match-intent is present, this is not the skill. Hand off to visual-inspection, which runs the screenshot-plus-measurement loop against the named axes.

## What to extract, what to ignore

A fat marker sketch carries five things worth extracting. It also carries a layer of noise that has to be actively discarded.

**Extract (the signal):**

1. **Complaint.** What feels wrong right now? The upload almost always means "this bothers me", not "build this". Name the pain.
2. **Target area.** Where is the user pointing? The arrow, the circle, the crop boundary say *where*, even when their styling says nothing about *how*.
3. **Direction.** Which way should it move? Bigger, calmer, tighter, warmer, more prominent, gone. A direction is a vector, not a destination.
4. **Content.** Any real words, values, labels, or data in the sketch that must survive into the result.
5. **Topology.** What goes near what, in what order, at what rough level of the hierarchy. This is the structural signal Shape Up says a sketch is *for*: which elements exist and roughly where they sit relative to each other, not their pixel positions.

**Ignore (the annotation layer):**

- Arrow color, weight, and style. A red arrow does not mean "add red".
- Callout bubbles, speech balloons, numbered stickers, and their fills, borders, and shadows.
- Highlighter strokes and their color. A yellow highlight marks *attention*, not a yellow background.
- Hand-drawn boxes and their stroke. A scribbled rectangle marks a region, not a bordered container.
- Screenshot-tool chrome: CleanShot toolbars, Preview markup styling, macOS window frames, drop shadows the tool added, the tool's own fonts and casing.
- The compositional accidents of the capture: crop tightness, where the user happened to stop the screenshot, the aspect ratio of the grab.

The test for each mark: does this pixel tell me *what the user wants*, or *what tool the user drew with*? The first is signal. The second is noise, and copying it is the failure this skill prevents.

## The interpretation readback (before the first edit)

Before writing a single line of code or CSS off an uploaded image, state your reading back. This is cheap insurance against building the wrong thing for a full round. It is the agent-side version of the question a good designer asks: "so what I am hearing is..."

Write three short lists:

```
From this sketch I read:
- Complaint: <what feels wrong>
- Target: <where you are pointing>
- Direction: <which way to move it>
- Content to keep: <real words/values, or "none">

I am ignoring (annotation, not design):
- <e.g. the red arrow and its color>
- <e.g. the CleanShot callout bubble styling>

I am going to:
- <the change, in product terms, in the existing design language>
```

Then act. You do not wait for approval on the readback in an autonomous flow; you write it, act, and render. But the readback is on record, so when the result is wrong the miss is visible and localized (wrong complaint? wrong target? or right reading, wrong execution?) instead of a silent full-round loss.

## The reference-scope check

The second classic failure with an uploaded reference is scope: the user says "borrow the grid from this" and the result copies the grid *and* the colors *and* the type *and* the spacing, or copies everything *except* the grid. When a user points at an existing design and asks you to take *something* from it, pin the one axis before you build.

Ask (of the request, not the user): which single axis is being borrowed? Grid, color, type, spacing, radius, density, motion, tone. Then state the borrow and the non-borrow explicitly:

```
Borrowing from the reference: <the one axis, e.g. the 8-column grid rhythm>
NOT borrowing: <everything else: its colors, its type, its density>
```

Copying more than the named axis is scope creep dressed as thoroughness. Copying less (taking the easy axes and missing the one the user actually pointed at) is the more common and more frustrating miss. The named axis is the deliverable; the rest of the reference is context.

## Relationship to the other skills

- **eye-of-the-beholder** is the open diagnostic scan of a rendered result. Fat-marker-sketch runs earlier: it governs how an *incoming* image is read as intent. After you translate the sketch into a change and render it, eye-of-the-beholder scans the render.
- **visual-inspection** is the opposite case: the image *is* a match reference, on named axes, with match-intent stated. Fat-marker-sketch is the default; visual-inspection is the earned exception. When you find match-intent, route there.
- **taste-test** is for when the user has no image at all and cannot describe the direction: it elicits direction by showing divergent options. Fat-marker-sketch is for when they *did* upload something. They compose: a fat marker sketch often points at a complaint that a taste-test round then explores.

## Common blind spots

| What the agent does | What goes wrong |
|--------------------|-----------------|
| Treats the uploaded PNG as a spec | It is a fat marker sketch. Extract intent; do not reproduce pixels. |
| Copies the annotation color into the UI | A red arrow means "look here", not "add red". Annotation color is never product color. |
| Reproduces the CleanShot / Preview markup styling | Screenshot-tool chrome is the tool's voice, not the user's design. Strip it entirely. |
| Builds the scribbled box as a bordered container | A hand-drawn box marks a region. Grouping is usually whitespace, not a border. |
| Assumes crisp pixels mean "match exactly" | Fidelity of the capture is not match-intent. Only stated match-intent earns literal reading. |
| Borrows every axis from a reference | Pin the one axis the user named. Copying the rest is scope creep. |
| Takes the easy axes, misses the named one | "Borrow the grid" and returning everything-but-the-grid is the most common reference miss. |
| Skips the readback and builds straight off the image | A wrong reading then costs a full round. The three-list readback localizes the miss up front. |
| Waits for the user to re-explain in words | The user uploaded an image *because* words were failing them. Extract from the sketch; do not push the burden back. |

## Output

```
Reading this upload as a fat marker sketch (no match-intent stated).

From this sketch I read:
- Complaint: the header feels cramped against the top edge
- Target: the title area (your arrow)
- Direction: more breathing room above it
- Content to keep: the "Q3 Results" wording

I am ignoring (annotation, not design):
- the red arrow and its color
- the yellow highlighter stroke over the title
- the CleanShot number badge

I am going to:
- add top spacing above the title using the existing spacing scale,
  in the product's own type and color, then render and scan it.
```
