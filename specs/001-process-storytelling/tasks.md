# Tasks: Animated Process Storytelling

**Input**: Design documents from `/specs/001-process-storytelling/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)

---

## Phase 1: Setup

**Purpose**: Fix the scaffold so it works with the real ontology

- [ ] T001 Fix `proc` namespace in `src/Process/Parse.purs` from `cardano-for-regulators.github.io` to `lambdasistemi.github.io/cardano-for-regulators`
- [ ] T002 Add `cfr` namespace constant in `src/Process/Parse.purs` for `cfr:LifecycleState` parsing

**Checkpoint**: Namespace matches actual TTL files

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extended domain types and parser that all user stories depend on

- [ ] T003 Extend `src/Process/Types.purs`: replace `StepType` variants with `OnChain | OffChain` (remove `Query`), add `DatumChange`, `SignatureReq`, `LifecycleState` record types, add `narrative`, `fromState`, `toState`, `signatures`, `checks`, `datumChanges` fields to `Step`, add `lifecycleStates` to `ProcessDef`
- [ ] T004 Rewrite `src/Process/Parse.purs` `buildProcess`: match `proc:OnChainStep` / `proc:OffChainStep` types, sort by `proc:stepOrder`, extract `proc:narrative`, `proc:fromState`, `proc:toState`, `proc:requiresSig`, `proc:checks`, `proc:changes` with sub-entity resolution for DatumChange and SignatureReq
- [ ] T005 Update `src/Animator.purs` to compile with new `Step` / `StepType` fields (fix pattern matches on `Transaction`/`OffChain`/`Query` → `OnChain`/`OffChain`)

**Checkpoint**: `spago build` succeeds, parser can parse `gdpr-breach.ttl` into the extended model

---

## Phase 3: User Story 3 — Load a process from TTL data (Priority: P1)

**Goal**: User can provide TTL and see actor lanes + steps populate
**Independent Test**: Provide `gdpr-breach.ttl` URL, verify 2 actors (Controller, Chain implied) appear as lanes, 3 steps listed in order

- [ ] T006 [US3] Create `src/Process/Load.purs`: `loadFromUrl :: String -> Aff (Either String ProcessDef)` that fetches TTL via `XMLHttpRequest` and calls `parseTurtle`
- [ ] T007 [US3] Add URL parameter parsing in `src/Main.purs`: read `?ttl=<url>` from `window.location`, if present call `loadFromUrl` and set process in state
- [ ] T008 [US3] Add file input button to `src/Animator.purs` controls bar: `<input type="file" accept=".ttl">` that reads file content via FileReader FFI and calls `parseTurtle`
- [ ] T009 [US3] Add `LoadProcess (Either String ProcessDef)` action to `src/Animator.purs` that sets `state.process` or `state.error`
- [ ] T010 [US3] Render `state.error` as a visible error message below controls in `src/Animator.purs`
- [ ] T011 [US3] Update `dist/index.html` to add `<div id="animator">` mount target

**Checkpoint**: Open `index.html?ttl=<url-to-gdpr-breach.ttl>`, see actor lanes and steps appear

---

## Phase 4: User Story 2 — Step through a process manually (Priority: P1)

**Goal**: Forward/backward stepping with visual state transitions
**Independent Test**: Load any TTL, click Next/Back, verify step highlighting, actor lane highlighting, and step info panel update with each click

- [ ] T012 [US2] Create `src/Animator/Lane.purs`: extract lane rendering from `Animator.purs` into a dedicated component, add CSS transition on active/completed state changes (`transition: all 0.3s ease`)
- [ ] T013 [US2] Create `src/Animator/StepInfo.purs`: extract step detail panel, render `step.narrative` (instead of `description`), show step type badge, list datum changes as before→after pairs
- [ ] T014 [US2] Add CSS classes to `dist/index.html` for step transitions: `.step-entering` (fade in from right), `.step-leaving` (fade out to left)

**Checkpoint**: Manual stepping works with smooth transitions, narrative text visible

---

## Phase 5: User Story 1 — Watch breach notification unfold (Priority: P1)

**Goal**: Full animated narrative with arrows, chain state, deadline, badges
**Independent Test**: Load `gdpr-breach.ttl`, press Play, watch 3 steps animate with arrows, state box transforms, 72h deadline bar, signature badges, validator ticks

- [ ] T015 [US1] Create `src/Animator/Playback.purs`: Halogen subscription using `setInterval` (2.5s per step), emit `StepForward` action, pause/stop cleans up interval
- [ ] T016 [US1] Wire `TogglePlay` action in `src/Animator.purs` to start/stop the playback subscription from `Playback.purs`
- [ ] T017 [US1] Create `src/Animator/Arrow.purs`: render a `<div class="tx-arrow">` positioned between actor lane and chain lane, CSS `@keyframes arrow-fly` animates `translateX` + `opacity` over 0.6s, only shown for `OnChain` steps
- [ ] T018 [US1] Create `src/Animator/ChainState.purs`: render chain state box showing current `LifecycleState` label, on `OnChain` step transition animate datum field changes (before→after with CSS `transform: scaleY` morph)
- [ ] T019 [US1] Create `src/Animator/Deadline.purs`: render horizontal progress bar spanning steps between `fromState` and `toState`, fill proportionally based on current step position within the deadline range, show duration label (e.g., "72h")
- [ ] T020 [P] [US1] Add signature badges to `src/Animator/StepInfo.purs`: for each `SignatureReq` on the current step, render a `<span class="sig-badge">` with party label, fade in on step activation
- [ ] T021 [P] [US1] Add validator check ticks to `src/Animator/StepInfo.purs`: for each check URI on the current step, render a green tick `<span class="check-tick">` that appears sequentially (CSS `animation-delay`) after the step activates
- [ ] T022 [US1] Add CSS for arrows, chain state, deadline, badges, ticks to `dist/index.html`: keyframes for `arrow-fly`, `state-morph`, `badge-fade`, `tick-appear`, `deadline-fill`
- [ ] T023 [US1] Wire all sub-components into `src/Animator.purs` render: arrows between lanes, chain state box in chain lane header, deadline bar above lanes, badges/ticks in step info

**Checkpoint**: Full animated playthrough of `gdpr-breach.ttl` with all visual elements

---

## Phase 6: User Story 4 — Embedded in documentation (Priority: P2)

**Goal**: Animator works as iframe in mkdocs with auto-loading
**Independent Test**: Embed `<iframe src="animator/?ttl=<url>">` in an HTML page, verify process loads and plays

- [ ] T024 [US4] Update `src/Lib.purs`: mount into `document.getElementById("animator")` instead of `body`, read `?ttl=` param and auto-load
- [ ] T025 [US4] Add responsive CSS to `dist/index.html`: media queries for `min-width: 600px` to `1920px`, flex-wrap lanes on narrow viewports
- [ ] T026 [US4] Build and verify both `nix build .#default` (standalone) and `nix build .#lib` (embeddable) produce working bundles

**Checkpoint**: Iframe embedding works, responsive at 600px–1920px

---

## Phase 7: User Story 5 — Multiple processes (Priority: P3)

**Goal**: Load different TTL files without page reload
**Independent Test**: Load `gdpr-breach.ttl`, reset, load `gdpr-rights.ttl`, verify lanes/steps rebuild

- [ ] T027 [US5] Add `ReloadProcess` action to `src/Animator.purs`: reset state fully (process, step, playback), allow new load via file input or URL change

**Checkpoint**: Can switch between breach, rights, consent processes

---

## Phase 8: Polish

**Purpose**: Formatting, CI, cleanup

- [ ] T028 Run `purs-tidy format-in-place src/**/*.purs` and verify `just format-check` passes
- [ ] T029 Run `just ci` (install, format-check, build, bundle) — verify clean pass
- [ ] T030 Add `dist/index.js` to `.gitignore`

---

## Dependencies

```text
Phase 1 (Setup) → Phase 2 (Foundation) → Phase 3 (US3: Loading)
                                        → Phase 4 (US2: Stepping) [after Phase 3]
                                        → Phase 5 (US1: Animation) [after Phase 4]
                                        → Phase 6 (US4: Embedding) [after Phase 5]
                                        → Phase 7 (US5: Multi)     [after Phase 3]
                                        → Phase 8 (Polish)         [after all]
```

## Parallel Opportunities

- T020 + T021 (badges and ticks are independent components)
- Phase 7 only depends on Phase 3 (loading), not on animation phases

## Implementation Strategy

**MVP**: Phases 1–5 (T001–T023) — full animated storytelling for `gdpr-breach.ttl`
**V1**: + Phase 6 (embedding) + Phase 8 (polish)
**V1.1**: + Phase 7 (multi-process)
