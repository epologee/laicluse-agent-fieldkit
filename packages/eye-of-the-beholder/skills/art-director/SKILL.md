---
name: art-director
user-invocable: true
description: Define visual identity and design-system foundations before UI work for new products, brand refreshes, or first design systems.
effort: high
---

# Art Director

## The real problem

Claude starts a product or feature and picks visual properties by feel. A hue from the Tailwind default scale, a radius somewhere between 4 and 12 px, an ease curve borrowed from a previous repo. That feels productive, but there is no brand to calibrate those choices against. "Does this fit us?" is not answerable if "us" has never been defined.

The same applies to teams that do have a brand: if that brand lives in three people's heads and not on paper, every new developer invents a slightly different palette. After a year the product has visual wear through accumulated loose choices. At the code level that is called technical debt; at the brand level it has no name, but extracting it costs just as much.

**Art-director works upfront.** The output is not UI, but a set of artifacts that make future UI work more concrete and less reflex-driven. Brand brief, visual language, design-system architecture. After that the build-time discipline (whichever skill in the session governs feature-level visual implementation) can refer to those artifacts while building ("the brand hue is this one, not that one") instead of re-choosing per feature. And eye-of-the-beholder can verify afterward against an existing rhythm instead of a loose intuition.

## Positioning

Art-director sits between discovery and production. Three skills, three moments:

- **art-director**, define the standard. Upfront, once per project or per brand refresh. Delivers `brand.md`, `visual-language.md`, and a `design-system/` skeleton.
- **The build-time discipline** (whichever skill in the session governs feature-level visual implementation), use the standard while building. Per feature. Refers back to art-director's artifacts for concrete choices ("take the hue from `visual-language.md`", not "choose a warm accent color").
- **eye-of-the-beholder**, verify after every change. Diagnostic. Screenshot, observe, compare with intent. Refers to the build-time discipline for rules and to art-director for brand context.

The three are not interchangeable. A design system without a brand is a catalog without a voice. Brand without a design system is a poster without execution. A UI without eye-of-the-beholder is a statically correct image that breaks under movement or on a different screen. Each skill has its own moment.

## When

Art-director must NOT activate on every piece of design work. That was the mistake eye-of-the-beholder did not want to make, and that art-director does not want to make either. Active triage:

**Activate:**

- New product or product line that has no brand yet.
- Brand refresh of an existing product (replacing the old brand, not supplementing it).
- Laying the first design-system foundation: the very first tokens, the very first atomic components, the first governance model.
- User explicitly asks for "art direction", "brand work", "visual language", or "design system architecture".

**Do not activate:**

- Small UI tweak (spacing, color of a button, new view in an existing flow). That is the build-time discipline plus eye-of-the-beholder.
- Per-component visual review. That is eye-of-the-beholder.
- Anti-AI-slop check on a feature. That is the build-time discipline.
- Single-screen layout fix. That is eye-of-the-beholder.
- "Make the colors a bit nicer" without brand context. Route to the build-time discipline's color or styling sub-skill.

If the question is "build this screen", art-director is the wrong answer. If the question is "what is the visual identity of this product", it is the right one.

## Module 1: Brand identity discovery

Goal: establish who the product is before you draw. Five phases, derived from Alina Wheeler's five-phase model in *Designing Brand Identity* (Wiley, 6th edition). Full citation in `references.md`.

### 1.1 Conducting research

Before talking about visual material: learn the situation. Three directions.

- **Stakeholder interviews.** Who has a stake in how this product looks? Founders, users, investors, existing customers, team. Three to five short conversations (30-45 min). Do not ask about colors or fonts. Ask: what does the product fundamentally do, for whom, why now? What should the product never become? Which competitors cause irritation and why?
- **Competitive scan.** List direct competitors and adjacent categories. For each: name, visual register (minimal / maximalist, professional / casual, warm / cool), what works, what does not. The goal is not imitation but positioning. You want to know where you will stand relative to this landscape.
- **Audit of existing material.** If the product already exists: screenshots of every view, printouts where applicable, marketing assets. List inconsistencies. What are the five most common colors in the current product? Do they align with the intention or are they drift?

Output: a 1-2 page report per stakeholder group + 1 page competitive scan + 1 page audit findings.

### 1.2 Clarifying strategy

Strategy rolls out of research. Wheeler's brand brief distills to three artifacts.

- **Positioning.** In one sentence, not a paragraph. Formula: "For \[target audience\] \[product\] is the \[category\] that \[value\]." Not to paste on a homepage, but to test against internally.
- **Personality.** Choose THREE attributes + THREE anti-attributes. "Clear" is an attribute, "not clever" is an anti-attribute. Anti-attributes prevent attributes from becoming so broad they lose meaning. "Friendly" can fit a chatbot and a funeral home; "friendly but not cheerful" is sharper.
- **Promise.** What does this brand promise its user? Not a feature, but an outcome. Neumeier's *The Brand Gap* calls this the "onion": functional (what), emotional (how it feels), self-expressive (what it says about me when I use it).

Output artifact: `brand.md` with sections Strategy / Positioning / Personality / Anti-personality / Voice / Touchpoints / Governance. Template in `templates/brand.md`.

### 1.3 Designing identity

Only now comes visual material. Each primitive translates brand strategy into a visual choice.

- **Logo.** Wordmark, symbol, or combo. David Airey's *Logo Design Love* (see references) gives the decision framework: does it fit in a favicon? Can it go monochrome? Does it work on a t-shirt? Not every product needs a logo; sometimes a wordmark is enough.
- **Type.** See Module 2 for details. Here: choose a pairing that embodies brand attributes.
- **Color.** See Module 2. Here: choose a brand hue and secondary palette.
- **Voice.** How do micro-copy, error messages, CTAs sound? A brand that is "clear but not clever" does not write puns in error messages. A brand that is "warm and calm" does not use exclamation marks. Write 5-10 examples of product copy in the chosen voice: a success toast, a 404 page, an onboarding hint, an email subject line. Those examples become the calibration points.

### 1.4 Creating touchpoints

Per medium where the brand appears: how does the identity behave there? Web, mobile, print, social, email, events, product packaging. Not every product uses all of them. But for each one the product DOES use:

- What is the primary visual behavior? (E.g. on web: brand hue as accent on neutral background. In email: a logo-mark and neutral body.)
- What are the anti-patterns? (E.g. no color gradients on the logo, no photo filters on product screenshots.)
- Who manages this touchpoint? (Who may change it, who may only use it?)

### 1.5 Managing assets

Governance. Who may change what and when. Three questions:

- **Contribution model.** Can everyone on the team propose a new component? Add a new color token? Or does that go through a design review?
- **Versioning.** When is a change breaking vs additive? Nathan Curtis (see references) has written extensively about semver for design tokens: a token rename is breaking, a token addition is additive, a value tweak within perceptual tolerance is a patch.
- **Deprecation.** How does an old token or component expire? Silently removing it is a breaking change without warning. A deprecation window (6 months, 12 months) with console warnings on usage is the standard.

## Module 2: Visual language translation

Goal: from brand attributes to visual vocabulary. Five axes. Per axis: choose, document the principle, cite the source, record in `visual-language.md`.

### 2.1 Type-as-voice

Type is the voice of a brand on the page. A pairing consists of display (headings, hero) and body (running text, UI). Sometimes a third for mono (code, data).

- **Not "elegant = serif".** The reflex ("serif feels classic, sans-serif feels modern") is too crude. A modern didone like GT Super feels different from a classic Garamond, both serifs. A geometric sans like Futura feels colder than a humanist sans like Inter. Choose based on brand personality, not on the coarsest classification.
- **Document the why.** "We choose Inter because it is a neutral humanist sans that scales well between UI (12-14px) and display (48-72px) without character loss, and because the brand is 'clear but not clever', we want a type that does not impose its own voice too strongly." That is what distinguishes a type choice from a taste preference.
- **References.** Ellen Lupton's *Thinking with Type* (2nd ed.) is the canonical introduction. Jim Williams' *Type Matters!* provides the pragmatic micro-typography workbook. Matthew Butterick's practicaltypography.com is online and pay-what-you-want, especially strong for body type. Klim Foundry case studies show how a type designer works for specific brands. For full citations see `references.md`.

### 2.2 Color-as-mood

Color expresses mood. Small nuances carry far.

- **Choose in OKLCH, not HSL.** OKLCH is perceptually uniform: two colors with the same L value feel equally light, which is not true with HSL. The point here is that you choose a brand hue that is perceptually stable across light and dark; the canonical reference is the OKLCH spec and the W3C CSS Color 4 module.
- **Document a physical reference, not emotional labels.** "The brand hue is a deep blue-green inspired by old library spines (rough texture, lightly weathered)" is stronger than "a calm blue-green". The first gives a verifiable mental image to test against at a future choice. The second is an emotional label that means something slightly different to every next reviewer.
- **60-30-10 as a starting point.** A rule of thumb from interior design that also works for screen color: 60% neutral, 30% secondary, 10% brand accent. Not a law, but a first check on how much of your screen you want to give to the brand.
- **Secondary palette.** 2-4 colors that are supporting. One status green, one warning yellow, one danger red, optionally one extra accent. Choose them in relation to the brand hue, not independently.
- **References.** Josef Albers' *Interaction of Color* (Yale, 50th anniversary ed.) for how color changes in context. Sean Adams' *The Designer's Dictionary of Color* for per-color cultural context. Aarron Walter's *Designing for Emotion* for how color relates to brand personality. Full citations in `references.md`.

### 2.3 Form-as-attitude

Geometry expresses attitude. Corner radius, border weight, surface depth, shadow language.

- **Corner radius as a spectrum.** 0 px is brutalist / industrial / serious. 2-4 px is geometric / businesslike. 8-16 px is soft / friendly. Full pill (`9999px`) is playful / friendly / tech-consumer. Choose a value that matches the personality and document it as a rule: "Our corner radius is 8 px because we want to feel soft and approachable without seeming childish."
- **Border weight.** 1 px is default-web. 2-3 px feels weightier, sometimes brutalist. No border (surface delta only) is calmer.
- **Surface depth.** How many levels does your interface have? Background, canvas, panel, dialog, popover = 5 levels. Each with its own luminance. See eye-of-the-beholder for the 1.07x delta rule to perceptually separate those levels.
- **Shadow language.** No shadows (flat), soft shadows (soft material), hard shadows (neubrutalism). Choose a style and keep it consistent. Two shadow styles in one interface is always a bug.

### 2.4 Motion-as-tempo

Time is the fourth design dimension. How fast something moves communicates temperament.

- **Duration as brand expression.** Brand "unhurried, careful" = longer durations (250-400 ms) with expo-out curves (eases that start fast and end softly). Brand "snappy, efficient" = shorter durations (120-180 ms) with standard ease-out. Brand "playful" = micro-bounce easing on state changes.
- **Ease vocabulary.** Define 3-5 named eases: `--ease-entrance`, `--ease-exit`, `--ease-gentle`, `--ease-snappy`. The normative details on which eases to use when belong to the build-time motion discipline in the session.
- **References.** See the design-motion-principles documentation (Emil Kowalski, Jakub Krehel, Jhey Tompkins) for per-designer motion vocabularies. Walter's *Designing for Emotion* for how motion relates to personality.

### 2.5 Photography and illustration tone

If the product has visual content: which registers may that content take?

- **Photography.** Editorial / product / documentary / stock. With / without people. Color / monochrome. Documenting "we use editorial-style product photography on neutral backgrounds, never stock photos of people in offices" is specific enough to reject a PR on.
- **Illustration.** Geometric / organic / hand-drawn / flat. Mono-line / color. If you use illustrations, are they decorative or narrative?
- **Mix-and-match prohibition.** The combination of photography and illustration in a product is risky; many brands choose one register. If both: define where each is used and why.

## Module 3: Design system architecture

Goal: from loose tokens and components to a system that scales without having to rethink at every new developer. Five elements.

### 3.1 Token taxonomy in three layers (Curtis model)

Nathan Curtis's three-layer model is the standard for token design. See his Eightshapes essays on medium.com/eightshapes-llc for the full explanation.

```
primitive:  --blue-500: oklch(0.62 0.18 260);
semantic:   --color-accent: var(--blue-500);
component:  --button-bg: var(--color-accent);
```

- **Primitive tokens** are the physical color palette, physical spacing scale, physical font scale. They are meaningless ("blue-500" says nothing about what it is in your product). They exist so that a semantic layer has something to point to.
- **Semantic tokens** give role. `--color-accent`, `--color-danger`, `--color-text-primary`, `--color-surface-1`. Application code talks ONLY to this layer. When the brand hue changes, you update one alias: `--color-accent: var(--red-500)` instead of `var(--blue-500)`. All components follow automatically.
- **Component tokens** are a third, optional layer for components with their own variation needs. `--button-primary-bg: var(--color-accent)` lets the button define its own token without polluting the semantic layer.

Two anti-patterns. First: application code that refers directly to primitives (`background: var(--blue-500)` in a `.button` selector). That bypasses the semantic layer and makes brand changes expensive. Second: semantic names that are actually disguised primitives (`--color-blue-primary` is not a semantic name, `--color-accent` is).

### 3.2 Component taxonomy (Frost atomic)

Brad Frost's *Atomic Design* (Macmillan, 2016, free online at atomicdesign.bradfrost.com) gives the five-layer structure:

- **Atoms.** The smallest meaningful unit: button, input, label, icon, badge.
- **Molecules.** Atoms combined into small functional units: search-field (input + button + icon), form-row (label + input + help text).
- **Organisms.** Molecules together in recognizable sections: page-header (logo + nav + search), card-grid, comment-thread.
- **Templates.** Layout structures without content: "a two-column settings page."
- **Pages.** Templates with real content.

Not every component falls cleanly into one layer. Uncertainty is OK. What matters: that there IS a layer. A design system without a taxonomy has 80 components in a flat list that nobody can find.

### 3.3 Component contract

For each component: what does it promise? Document that per component.

- **API.** Which props / slots / parameters? Types and defaults.
- **States.** Hover, focus-visible, active, disabled, loading, error. Each explicit.
- **Variants.** Primary / secondary / destructive / ghost. Each with a brand rationale: why does this variant exist and when do you use it?
- **Slots.** Can the component accept children? Which? With what constraints?
- **A11y requirements.** Role, keyboard support, screen-reader names, contrast-ratio minimums. The canonical contrast ratios are WCAG 2.1 SC 1.4.3 (4.5:1 normal text, 3:1 large text and UI components); AAA tightens to 7:1 and 4.5:1.
- **Do / don't.** Two short lists with usage examples. Not describing all combinations, just preventing the most common mistakes.

Template: `templates/design-system/components/_example.md`.

### 3.4 Governance

Who may change what and when. Already touched in Module 1.5. Here specifically for the design system.

- **Contribution model.** Proposing a new component: via a PR with a design rationale and an a11y checklist. Changing an existing component: via a PR with an impact assessment (which other components use this?).
- **Review criterion.** One design owner reads every design-system PR. Not technical reviewers only. Code is not the only review domain.
- **Semver for tokens and components.** Renaming a token = major. Adding a new token = minor. Adjusting a token value (brand hue shifts 5 degrees in OKLCH) = patch, unless the shift is visible enough to feel breaking. Then it is major.
- **Deprecation window.** Minimum 2 minor releases or 6 calendar months between "marked deprecated" and "removed". Console warnings or linter warnings on usage of deprecated tokens.

### 3.5 Living docs

A design system that only lives in code is discoverable by nobody. Living documentation:

- **Showcase route.** A `/design-system/` route in the product itself, or a separate Storybook / Histoire instance. Per component: an example, a state matrix (every state visible), and the do/don't from the component contract.
- **Token reference.** A page that makes all semantic tokens visible in light + dark. Not just color values, also spacing scale, type scale, radius values.
- **Governance page.** The contribution rules from 3.4, accessible to everyone considering a PR.

References: Yesenia Perez-Cruz's *Expressive Design Systems* for how to keep a system expressive rather than sterile. DesignBetter's *Design Systems Handbook* (free at designbetter.co/design-systems-handbook) for team organization. Adam Wathan and Steve Schoger's *Refactoring UI* (self-published) for concrete tactical rules. Full citations in `references.md`.

Public reference systems to study how others solve it:

- **Polaris** (Shopify): polaris.shopify.com
- **Carbon** (IBM): carbondesignsystem.com
- **Primer** (GitHub): primer.style
- **Material 3** (Google): m3.material.io
- **IBM Design Language**: ibm.com/design/language
- **Atlassian Design System**: atlassian.design

Not to copy, but to study patterns and taxonomies.

## Division of labor across the three moments

The chain has three moments in the project lifecycle:

- **art-director** (once, upstream). Delivers `brand.md`, `visual-language.md`, and `design-system/` skeleton. After this step "our brand" exists in writing.
- **Build-time discipline** (per feature, while building). Whichever skill in the session governs feature-level visual implementation applies the standard. Refers back to art-director's artifacts for concrete choices ("from `visual-language.md`: hue is `oklch(0.62 0.18 260)`"). The normative rules (contrast ratios, transform/opacity-only, spacing scale) come from that skill or from canonical specs (WCAG, OKLCH, framework docs).
- **eye-of-the-beholder** (per change, afterward). Verifies visually. Screenshot, observe, compare with intent. Refers to the build-time discipline for rules and to art-director for brand context. Applies observation questions that neither of the other two moments asks ("can you read secondary text without squinting?").

What is NOT art-director's territory: implementation CSS (build-time and eye-of-the-beholder), per-component visual review (eye-of-the-beholder), anti-AI-slop checklists (build-time), single-screen layout fixes (eye-of-the-beholder).

## Output artifacts

Three files, one directory. Templates live in `templates/`.

- `brand.md`: strategy, personality, anti-personality, voice, touchpoints, governance.
- `visual-language.md`: per-axis decision log (type, color, form, motion, photo/illo) with principle + chosen value + rationale + reference.
- `design-system/tokens.md`: 3-layer Curtis model (primitive, semantic, component) with concrete values in OKLCH and other units.
- `design-system/components/<name>.md`: per component contract. Template in `_example.md`.
- `design-system/governance.md`: contribution, review, semver, deprecation.

Use the templates from `templates/` as a starting point. Iterations are normal; a brand document from round 1 is almost never the document from round 3.

## References

See `references.md` for the full list of canonical works with ISBN, URL, and a one-line summary per source.
