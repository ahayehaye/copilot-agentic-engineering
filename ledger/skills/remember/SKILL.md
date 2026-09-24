---
name: remember
description: "Record and recall workspace memory. Write mode: 'record/note/remember X' appends one dated, typed entry (event or state) to memories/ and updates the index. Read mode: a question gets an index-first lookup, answered from matching entries with a grep fallback and an honest not-found. Bare invocation shows the index. Use when the user wants to record a decision or work state, or asks 'what did I decide about X'."
version: 1.0.0
---

# Remember

Workspace memory: what is being worked on and what has been decided.
Entries live in `memories/` (format contract: `memories/README.md`); the
index is `memories/index.md`.

## Modes

### Write mode

Trigger: the user says "record", "note", "remember", or similar, with the
content to store.

1. Classify: **event** (a unique milestone — what happened) or **state**
   (a current truth — a decision, an active work item).
2. Assign the next sequence number: highest existing `NNNN` prefix in
   `memories/` plus one, zero-padded to four digits.
3. Write `memories/<NNNN>-<slug>.md` with the frontmatter per
   `memories/README.md`: `type`, `session` (today's date), `tags`; for
   states also `key` and `status: active`. No persona keying, no autonomy
   machinery — only type, date, key, status, and tags.
4. If this state supersedes a previous active state with the same `key`,
   set `supersedes:` on the new entry and flip the old entry to
   `status: superseded` with `superseded_by:`.
5. Update `memories/index.md`: add one line under `## Events` or
   `## Current States` — number, type, one-sentence summary, status.

Writes are user-initiated only. No autonomous writes, no end-of-session
sweeps.

### Read mode

Trigger: the user asks a question about prior work or decisions.

1. Read `memories/index.md` first.
2. Match the question against index lines (summary, tags, keys).
3. Load the matching entry files and answer from them.
4. Fallback: grep `memories/` for relevant terms if the index does not match.
5. Honest not-found: if nothing matches, say so — and offer to record the
   answer as a new entry.

### Bare invocation

Show the index (`memories/index.md`).
