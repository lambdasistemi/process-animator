# Process Animator Constitution

## Core Principles

### I. Narrative First
The animator tells a story, not shows a graph. Every design decision serves
the narrative experience: actors, transactions, deadlines, and state
transitions must be legible to a non-technical audience watching a process
unfold step by step.

### II. Data-Driven from RDF
All process definitions come from the cardano-for-regulators TTL ontology.
The animator never hardcodes process structure — it parses `proc:` triples
and builds the visual from them. New processes should work without code changes.

### III. Embeddable
The output must be embeddable in mkdocs via iframe. The lib bundle must be
self-contained (no external runtime dependencies). Dark theme, responsive.

### IV. Shared Patterns from graph-browser
Reuse the same Nix build structure (mkSpagoDerivation + esbuild), Oxigraph
FFI, and deployment patterns from graph-browser. Diverge only where the
rendering model requires it (lanes + animations vs nodes + edges).

### V. Pure Core
Process parsing and state machine logic must be pure PureScript. Side effects
(DOM manipulation, WASM FFI, animation timing) live at the edges. The core
model is testable without a browser.

### VI. Small Increments
Each PR delivers a working increment. The app should be serveable and
demonstrable at every merge point, even if incomplete.

## Domain Constraints

- Process ontology namespace: `https://cardano-for-regulators.github.io/ontology/process#`
- Actors: Controller, Chain, Supervisory Authority (SA) — but the animator
  must support arbitrary actors from the ontology
- Step types: Transaction (on-chain), OffChain, Query
- Deadlines: ISO 8601 durations (PT72H, P1M, etc.)

## Development Workflow

- PureScript + Halogen, Nix flake, justfile
- Format with purs-tidy, check in CI
- Build gate pattern in CI (shared nix store on self-hosted runner)
- release-please for versioning
- PRs for all changes, linear history on main

## Governance

This constitution governs all planning and implementation decisions.
Amendments require explicit discussion and rationale.

**Version**: 1.0.0 | **Ratified**: 2026-04-08
