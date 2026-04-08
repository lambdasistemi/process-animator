# Implementation Plan: Animated Process Storytelling

**Branch**: `001-process-storytelling` | **Date**: 2026-04-08 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-process-storytelling/spec.md`

## Summary

Extend the existing scaffold (PR #2) to deliver a fully animated process storyteller
that loads TTL from the cardano-for-regulators ontology and renders step-by-step
narratives with transaction arrows, chain state transformations, deadline countdowns,
and signature/validator badges. The core parsing must be fixed to match the actual
ontology structure (subtypes, `proc:stepOrder`, `proc:narrative`, datum changes).

## Technical Context

**Language/Version**: PureScript 0.15.x + Halogen 7
**Primary Dependencies**: Halogen, Oxigraph WASM, esbuild
**Storage**: N/A (client-only, data from TTL)
**Testing**: Manual browser testing (pure functions testable via `spago test` later)
**Target Platform**: Browser (WASM), embeddable iframe
**Project Type**: Web application (SPA)
**Performance Goals**: < 3s initial load including WASM, < 300ms step transitions
**Constraints**: Self-contained bundle, dark theme, 600px–1920px responsive
**Scale/Scope**: 3 processes (breach, rights, consent), 2–5 actors, 2–5 steps each

## Constitution Check

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Narrative First | PASS | All visual design serves the storytelling experience |
| II. Data-Driven from RDF | NEEDS FIX | Parser namespace mismatch, missing subtypes/stepOrder/narrative |
| III. Embeddable | PASS | Lib bundle exists, needs mount-target + URL param loading |
| IV. Shared Patterns | PASS | Already using mkSpagoDerivation + esbuild + Oxigraph FFI |
| V. Pure Core | PASS | Parse + state machine logic stays pure, effects at edges |
| VI. Small Increments | PASS | Plan is phased by user story priority |

## Project Structure

### Documentation

```text
specs/001-process-storytelling/
├── plan.md              # This file
├── research.md          # Ontology analysis
├── data-model.md        # Extended domain model
├── spec.md              # Feature specification
└── checklists/          # Quality checklists
```

### Source Code

```text
src/
├── Main.purs                  # Standalone entry point
├── Lib.purs                   # Iframe-embeddable entry (mount by element ID)
├── Animator.purs              # Top-level Halogen component (controls + routing)
├── Animator/
│   ├── Lane.purs              # Single actor lane rendering
│   ├── Arrow.purs             # Transaction arrow animations (CSS)
│   ├── ChainState.purs        # Chain state box with datum field visualization
│   ├── Deadline.purs          # Countdown timer / progress bar
│   ├── StepInfo.purs          # Step detail panel (narrative, badges)
│   └── Playback.purs          # Auto-play timer subscription
├── Process/
│   ├── Types.purs             # Domain types (extended with DatumChange, etc.)
│   ├── Parse.purs             # TTL → ProcessDef (fixed for real ontology)
│   └── Load.purs              # TTL loading (fetch URL, file input, URL param)
├── FFI/
│   ├── Oxigraph.js            # Existing
│   └── Oxigraph.purs          # Existing
├── bootstrap.js               # Existing
dist/
└── index.html                 # Existing (add #animator mount target)
```

**Structure Decision**: Flat `src/Animator/` subdirectory for component modules.
No deep nesting. Each visual concern gets one module.

## Design Decisions

### D1: Fix parser to match actual ontology

The current parser uses wrong namespace and looks for `proc:Step` type.
The actual ontology uses:
- Namespace: `https://lambdasistemi.github.io/cardano-for-regulators/ontology/process#`
- Step subtypes: `proc:OnChainStep`, `proc:OffChainStep` (no `proc:Step` supertype)
- Ordering: `proc:stepOrder` integer property (not array position)
- Description: `proc:narrative` (not `rdfs:comment`)
- Additional predicates: `proc:fromState`, `proc:toState`, `proc:checks`,
  `proc:requiresSig`, `proc:changes`, `proc:usesAction`

### D2: CSS animations, not Canvas

Arrows and transitions use CSS animations/transitions. Keeps the pure-Halogen
approach, avoids Canvas FFI complexity. Sufficient for the linear step-by-step
narrative. CSS `@keyframes` for arrow flight, state box morphing, badge fades.

### D3: TTL loading strategy

Three loading paths, priority order:
1. URL parameter `?ttl=<url>` — fetch and parse (primary for iframe embedding)
2. Inline `<script type="text/turtle">` — for self-contained demos
3. File input button — for ad-hoc exploration

### D4: Lib.purs mounts by element ID

`Lib.purs` mounts into `#animator` (or configurable via data attribute),
not `body`. `Main.purs` keeps mounting to `body` for standalone use.

### D5: Deadline as visual progress bar

Deadline renders as a horizontal progress bar spanning the relevant steps,
with elapsed/remaining indication. Not a real-time clock (process time is
simulated via step transitions).

## Phases

### Phase 1: Fix parser + TTL loading (US3 — P1)

Fix namespace, support OnChainStep/OffChainStep, sort by stepOrder,
extract narrative/signatures/checks/datumChanges. Add fetch-based loading
with URL parameter support.

### Phase 2: Core animation (US1, US2 — P1)

Transaction arrows (CSS animated divs between lanes), chain state box
showing datum field changes, step highlighting with transitions, auto-play
timer subscription.

### Phase 3: Deadline + badges (US1 — P1)

Deadline progress bar spanning from/to states, signature badges on
transaction steps, validator check ticks.

### Phase 4: Embedding (US4 — P2)

Lib.purs element-ID mounting, URL parameter auto-load, responsive
width handling.

### Phase 5: Multi-process (US5 — P3)

Process switcher or reload support. Low priority.
