# Research: Process Animator Ontology Analysis

## Ontology namespace

**Decision**: Use `https://lambdasistemi.github.io/cardano-for-regulators/ontology/process#`
**Rationale**: This is the actual namespace in the TTL files. The scaffold used a different
URL (`cardano-for-regulators.github.io`) which doesn't match.

## Step type hierarchy

**Decision**: Match on `proc:OnChainStep` and `proc:OffChainStep` (not `proc:Step`)
**Rationale**: The ontology doesn't define a `proc:Step` supertype. Each step is typed
directly as OnChainStep or OffChainStep. There is no Query type in the current ontology
files — all queries are implicit (SA reads the trie after the process completes).
**Alternatives considered**: Adding `proc:Step` as a supertype in the ontology — rejected
because the animator should consume the ontology as-is.

## Step ordering

**Decision**: Sort by `proc:stepOrder` integer property
**Rationale**: The ontology explicitly assigns `proc:stepOrder 1`, `proc:stepOrder 2`, etc.
The current parser uses array position after Map grouping which is non-deterministic.

## Step descriptions

**Decision**: Use `proc:narrative` as the primary description, fall back to `rdfs:comment`
**Rationale**: The ontology provides rich `proc:narrative` text for each step describing
what happens and why. `rdfs:comment` is used on the Process entity itself.

## Datum changes

**Decision**: Extract `proc:changes` → DatumChange entities with field, before, after values
**Rationale**: The ontology models datum transformations explicitly. These drive the chain
state box visualization — showing what fields change on each transaction step.

## Deadline structure

**Decision**: Parse `proc:deadlineFrom` / `proc:deadlineTo` (lifecycle states, not step IDs)
and `proc:slotDuration` (human-readable like "72h")
**Rationale**: The current parser looks for `proc:fromStep` / `proc:toStep` which don't
exist in the actual ontology. Deadlines reference lifecycle states.

## Signature requirements

**Decision**: Extract `proc:requiresSig` → SignatureReq with party and type
**Rationale**: Needed for signature badges on transaction steps.

## Validator checks

**Decision**: Extract `proc:checks` as a list of check references per step
**Rationale**: Needed for green tick visualization. The check entities themselves
have labels that can be displayed.

## Lifecycle states

**Decision**: Extract `cfr:LifecycleState` entities for chain state box visualization
**Rationale**: `proc:fromState` / `proc:toState` on each step reference these.
They provide the labels for what the chain state box shows before/after a transaction.

## CSS animation approach

**Decision**: CSS transitions + keyframes for all visual animations
**Rationale**: Halogen manages DOM; CSS handles motion. No Canvas or external
animation library needed. Arrows are absolutely-positioned divs that animate
via CSS `transform` + `opacity`. Step transitions use `transition: all 0.3s ease`.
**Alternatives considered**: Canvas (rejected — breaks Halogen's virtual DOM model),
Web Animations API (viable but CSS is simpler for this use case).

## Loading mechanism

**Decision**: `fetch` via Aff for URL-based loading, FileReader API for file input
**Rationale**: Aff already available via halogen-aff. URL parameter parsing is
trivial via Web.HTML.Location. FileReader needs minimal FFI.
