# Data Model: Process Animator

## Entities

### ProcessDef

The top-level container parsed from a `proc:Process` entity in TTL.

| Field | Type | Source |
|-------|------|--------|
| id | String | RDF subject URI |
| label | String | `proc:processLabel` or `rdfs:label` |
| description | Maybe String | `rdfs:comment` |
| actors | Array Actor | All `proc:actor` references, deduplicated |
| steps | Array Step | All OnChainStep/OffChainStep, sorted by `proc:stepOrder` |
| deadlines | Array Deadline | All `proc:Deadline` entities |
| lifecycleStates | Array LifecycleState | All `cfr:LifecycleState` entities |

### Actor

A participant in the process. Rendered as a persistent lane.

| Field | Type | Source |
|-------|------|--------|
| id | String | RDF subject URI (e.g., `gdpr:DataController`) |
| label | String | `rdfs:label` |
| lane | Int | Assigned by order of appearance |

### Step

A single action in the process sequence.

| Field | Type | Source |
|-------|------|--------|
| id | String | RDF subject URI |
| label | String | `rdfs:label` |
| narrative | Maybe String | `proc:narrative` |
| actor | String | `proc:actor` URI |
| stepType | StepType | `proc:OnChainStep` or `proc:OffChainStep` RDF type |
| order | Int | `proc:stepOrder` |
| fromState | Maybe String | `proc:fromState` URI |
| toState | Maybe String | `proc:toState` URI |
| signatures | Array SignatureReq | `proc:requiresSig` refs |
| checks | Array String | `proc:checks` URIs |
| datumChanges | Array DatumChange | `proc:changes` refs |
| action | Maybe String | `proc:usesAction` URI |

### StepType (sum type)

| Variant | Meaning |
|---------|---------|
| OnChain | Transaction step — shows arrow to chain, datum changes, signatures |
| OffChain | Off-chain activity — shows activity within actor lane, no chain interaction |

Note: `Query` type removed — not present in the actual ontology.

### DatumChange

A datum field transformation on a transaction step.

| Field | Type | Source |
|-------|------|--------|
| label | String | `rdfs:label` |
| field | String | `proc:changesField` → `proc:fieldName` |
| beforeValue | String | `proc:beforeValue` |
| afterValue | String | `proc:afterValue` |

### SignatureReq

A signature requirement on a transaction step.

| Field | Type | Source |
|-------|------|--------|
| label | String | `rdfs:label` |
| party | String | `proc:sigParty` URI |
| sigType | String | `proc:sigType` (e.g., "actor") |

### Deadline

A time constraint between lifecycle states.

| Field | Type | Source |
|-------|------|--------|
| label | String | `rdfs:label` |
| fromState | String | `proc:deadlineFrom` URI |
| toState | String | `proc:deadlineTo` URI |
| duration | String | `proc:slotDuration` (e.g., "72h") |

### LifecycleState

A named state in the process lifecycle, rendered in the chain state box.

| Field | Type | Source |
|-------|------|--------|
| id | String | RDF subject URI |
| label | String | `rdfs:label` |
| description | Maybe String | `rdfs:comment` |

### AnimatorState (runtime)

| Field | Type | Purpose |
|-------|------|---------|
| process | Maybe ProcessDef | Currently loaded process |
| currentStep | Int | Active step index |
| playback | PlaybackState | Stopped / Playing / Paused |
| error | Maybe String | Parse or load error message |

### PlaybackState (sum type)

| Variant | Meaning |
|---------|---------|
| Stopped | Initial or reset state |
| Playing | Auto-advancing with timer |
| Paused | Timer paused, manual stepping available |
