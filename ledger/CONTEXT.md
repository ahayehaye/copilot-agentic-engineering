# Context

A local ticketing + research + memory workspace for software and systems work.
Work content here is unversioned by any remote; the local git repository is
the backstop.

## Glossary

| Term | Definition |
|------|------------|
| **Ticket** | A unit of work tracked in this workspace. A **parent ticket** is a `NNNNN-<slug>/` directory under a namespace; its body is `spec.md`. A **slice** is a child ticket, filed as `slice-NN-<slug>.md` in the parent directory. Number spaces are per-namespace; numbers are never reused. |
| **Slice** | A single unit of implementation work under a parent ticket, sized to fit in one fresh context window. |
| **Namespace** | A top-level partition of the ticket tree under `tickets/` (e.g. `engineering`, `research`). Each namespace has its own `INDEX.md` and its own number space. A new namespace is a new directory + INDEX; it is user content, invisible to the ledger manager. |
| **Semantic Ticket** | A local ticket that concentrates an effort spanning external systems. Its spec carries a `Refs:` line with namespaced external IDs (e.g. `ado:12345`, `gh:owner/repo#678`). The external tracker is the source of truth for status; the local INDEX status is the local working view. |
| **`Refs:`** | The line in a spec (and optionally a slice) that links a local ticket to the external tracker(s) that are the source of truth for status. Namespaced external IDs — `ado:12345`, `gh:owner/repo#678`; the namespace prefix is required (a bare number is ambiguous across trackers); multiple lines allowed. A mismatch between the external status and the local INDEX status is reported, not reconciled; `verify-ac` does not check external status. |
| **Memory** | A dated, typed entry under `memories/` — an **event** (a unique milestone) or a **state** (a current truth, supersedable). The index (`memories/index.md`) is the read-first entry point. Managed by the `remember` skill. |
| **Research Entry** | A cited, sourced, dated, living entry in the `research/` library. The `research` ticket namespace (ticket-driven investigations) and the `research/` library (knowledge deliverables) are distinct partitions. |
