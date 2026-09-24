# Memory Format

One file per memory: `memories/<NNNN>-<slug>.md`

- `NNNN` is a zero-padded, repository-wide sequence number shared by both
  events and states (e.g., `0001`, `0002`).
- The directory is flat.

## Frontmatter

```yaml
---
type: event | state
key: <state-key>          # states only
session: <YYYY-MM-DD>
tags: [tag1, tag2]
status: active | superseded   # states only
supersedes: <path>        # states only
superseded_by: <path>     # states only
---
```

### Required fields by sub-type

| Field | Event | State |
|---|---|---|
| `type` | ✓ | ✓ |
| `session` | ✓ | ✓ |
| `key` | — | ✓ |
| `status` | — | ✓ |
| `tags` | optional | optional |
| `supersedes` | — | optional (set when superseding) |
| `superseded_by` | — | optional (set when superseded) |

## Sub-types

### Event

A unique milestone in time. Cumulative: events are never superseded and
never deleted. They build the library of the past.

- `type: event`
- No `key`, `status`, `supersedes`, or `superseded_by` fields.

### State

A current truth about work: what is being worked on, what has been decided.
Supersedable: a new state with the same `key` replaces the previous one as
the current truth.

- `type: state`
- `key` is required (e.g., `decision:<topic>`, `work:<effort>`)
- `status` is required: `active` or `superseded`
- At most **one active state per key**

## Supersession mechanics

When a new state replaces the current truth:

1. Write the new file with `status: active` and `supersedes: <path>`
   pointing to the previous active state.
2. In the previous active state, flip `status: superseded` and set
   `superseded_by: <path>` pointing to the new file.
3. The chain is walkable in both directions.

## Sequence convention

Numbers are assigned sequentially and never reused. Both events and states
draw from the same counter.

## Read path

- **Index first.** `memories/index.md` is the read-first entry point: one
  line per entry — number, type, one-sentence summary, status.
- **On-demand lookup.** `/remember <question>` matches the question
  against the index and loads the matching entries. "Current truth" queries
  prefer active states; "what happened" queries prefer events.
