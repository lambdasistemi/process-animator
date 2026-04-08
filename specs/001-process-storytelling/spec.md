# Feature Specification: Animated Process Storytelling from RDF State Machines

**Feature Branch**: `001-process-storytelling`
**Created**: 2026-04-08
**Status**: Draft
**Input**: User description: "Animated process storytelling from RDF state machines"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Watch a breach notification process unfold (Priority: P1)

A presenter loads the GDPR breach notification process (`gdpr-breach.ttl`)
and watches the 3-step story play out as an animation. The Controller
discovers a breach (visual cue on Controller lane), creates a commitment
(arrow animates from Controller to Chain, state box transforms), and
submits notification within the 72-hour deadline (clock counts down, green
checkmark appears).

**Why this priority**: This is the core value — demonstrating how a regulated
process unfolds on Cardano in a way a non-technical audience can follow.

**Independent Test**: Load `gdpr-breach.ttl`, press Play, observe the 3 steps
animate in sequence with correct actors, arrows, state changes, and deadline.

**Acceptance Scenarios**:

1. **Given** the animator has loaded `gdpr-breach.ttl`, **When** the user presses Play, **Then** each of the 3 steps animates in sequence with visible transitions between them
2. **Given** step 1 is active, **When** the transition to step 2 occurs, **Then** an arrow animates from the Controller lane to the Chain lane, and the Chain state box visually transforms
3. **Given** the process has a 72-hour deadline, **When** the animation reaches the deadline-bounded steps, **Then** a countdown timer or progress bar is visible and ticking

---

### User Story 2 - Step through a process manually (Priority: P1)

A user navigates the process step by step using forward/backward controls,
pausing at each step to examine the current state: which actor is active,
what the chain datum looks like, whether a deadline is running.

**Why this priority**: Interactive stepping is essential for presentations and
detailed examination. Tied with auto-play as core interaction.

**Independent Test**: Load any process TTL, use step forward/backward buttons,
verify each step shows the correct actor highlighted, step description,
and state.

**Acceptance Scenarios**:

1. **Given** the animator is at step N, **When** the user clicks Next, **Then** the view transitions to step N+1 with the appropriate actor and action highlighted
2. **Given** the animator is at step N (N > 0), **When** the user clicks Back, **Then** the view transitions to step N-1, rewinding the visual state
3. **Given** the animator is at the last step, **When** the user clicks Next, **Then** nothing happens (button disabled)
4. **Given** the animator is at the first step, **When** the user clicks Back, **Then** nothing happens (button disabled)

---

### User Story 3 - Load a process from TTL data (Priority: P1)

A user provides a TTL file (via file input, URL parameter, or embedded data)
and the animator parses it into a visual process narrative. The user sees
actor lanes appear, steps populate, and the process is ready to play.

**Why this priority**: Without loading, nothing works. This is the entry
point for all other stories.

**Independent Test**: Provide a valid TTL string, verify actors appear as
lanes, steps are listed in order, and the Play button becomes active.

**Acceptance Scenarios**:

1. **Given** a valid process TTL, **When** the animator loads it, **Then** actor lanes appear with correct labels and steps are shown in order
2. **Given** an invalid or empty TTL, **When** the animator attempts to load it, **Then** an error message is displayed
3. **Given** a TTL with 2 actors, **When** loaded, **Then** exactly 2 lanes are rendered

---

### User Story 4 - View the process embedded in documentation (Priority: P2)

A documentation reader visits an mkdocs page containing an embedded
process animator iframe. The process loads automatically and is ready
to play without any user setup.

**Why this priority**: Embedding is the primary distribution mechanism but
depends on the core animator working first.

**Independent Test**: Embed the lib bundle in an iframe with a TTL URL
parameter, verify the process loads and is interactive.

**Acceptance Scenarios**:

1. **Given** an iframe pointing to the animator with a `?ttl=` URL parameter, **When** the page loads, **Then** the process is loaded and ready to play
2. **Given** the iframe is embedded in mkdocs, **When** the user interacts with play/step controls, **Then** the animation works identically to the standalone version

---

### User Story 5 - Watch multiple processes for comparison (Priority: P3)

A user loads different process definitions (breach notification, rights
request, consent management) to compare their structure — number of steps,
deadlines, actors involved.

**Why this priority**: Nice-to-have for comparative analysis, but the core
experience is single-process storytelling.

**Independent Test**: Load `gdpr-breach.ttl`, reset, load `gdpr-rights.ttl`,
verify the animator correctly rebuilds with different actors/steps.

**Acceptance Scenarios**:

1. **Given** a process is already loaded, **When** the user loads a different TTL, **Then** the previous process is replaced and the new one renders correctly

---

### Edge Cases

- What happens when a TTL contains no `proc:Process` entity? → Show an error: "No process found in the provided data"
- What happens when a process has zero steps? → Show the actor lanes but disable playback controls
- What happens when a deadline references a step that doesn't exist? → Ignore the deadline gracefully (no crash)
- What happens when actors overlap (same actor initiates and receives)? → Show the arrow looping within the same lane

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST parse process ontology TTL files using the `proc:` namespace and extract Process, Actor, Step, and Deadline entities
- **FR-002**: System MUST render actors as persistent vertical lanes in the viewport
- **FR-003**: System MUST render each process step as a visual event in the appropriate actor lane
- **FR-004**: System MUST animate transitions between steps, showing arrows from initiating actor to target actor (e.g., Controller → Chain for transactions)
- **FR-005**: System MUST visually transform the Chain state box when a transaction step occurs, indicating the datum has changed
- **FR-006**: System MUST display a countdown timer or progress bar for deadline-bounded steps, showing the duration (e.g., 72 hours)
- **FR-007**: System MUST provide playback controls: Play (auto-advance), Pause, Step Forward, Step Backward, Reset
- **FR-008**: System MUST distinguish step types visually — Transaction steps show arrows to Chain, OffChain steps show activity within an actor's lane, Query steps show read operations
- **FR-009**: System MUST support loading TTL data via URL parameter for iframe embedding
- **FR-010**: System MUST display validator checks as green ticks when a transaction step completes
- **FR-011**: System MUST show signature badges indicating which actor signed a transaction

### Key Entities

- **Process**: A named regulated workflow with a sequence of steps, actors, and optional deadlines. Identified by `proc:Process` type.
- **Actor**: A participant in the process (Controller, Chain, SA). Rendered as a persistent lane. Identified by `proc:Actor` type.
- **Step**: A single action in the process — a transaction, off-chain activity, or query. Has an initiating actor and optional target. Identified by `proc:Step` type.
- **Deadline**: A time constraint between two steps. Has a duration in ISO 8601 format. Identified by `proc:Deadline` type.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A viewer can understand the sequence and actors of a 3-step breach notification process after watching the animation once, without external explanation
- **SC-002**: The animator correctly renders all 3 processes from the cardano-for-regulators ontology (breach, rights, consent) without code changes
- **SC-003**: Step forward/backward navigation completes in under 300ms with visible transition
- **SC-004**: The bundled output loads in under 3 seconds in a modern browser, including WASM initialization
- **SC-005**: The animator renders correctly when embedded as an iframe in an mkdocs page at widths from 600px to 1920px

## Assumptions

- The process ontology from cardano-for-regulators is stable and follows the `proc:` namespace conventions described in issue #1
- Processes are sequential (no branching or parallel steps) — the animator renders a linear story
- The audience is semi-technical (regulators, auditors, policy makers) — visual clarity matters more than information density
- Dark theme (matching graph-browser) is the only required theme
- Auto-play timing is fixed (e.g., 2-3 seconds per step) — no user-configurable speed in v1
