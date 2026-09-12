# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, filtering comments by `jq` and also fetching labels.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v` — `gh` does this automatically when run inside a clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: `gh pr view <number> --comments` and `gh pr diff <number>` for the diff.
- **List external PRs for triage**: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments` then keep only `authorAssociation` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE` (drop `OWNER`/`MEMBER`/`COLLABORATOR`).
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either — resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (`gh api` on the sub-issues endpoint). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: GitHub's **native issue dependencies** — the canonical, UI-visible representation. Add an edge with `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric **database id** (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only — the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the map's sub-issues / task list), drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me` — the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.

## Sub-issues

**List a parent's sub-issues**

```bash
gh api repos/ahayehaye/copilot-agentic-engineering/issues/<parent>/sub_issues
```

**Create a sub-issue link**

The REST `POST /repos/{owner}/{repo}/issues/{issue_number}/sub_issues` endpoint requires the sub-issue's **database id**, not the issue number. Get the id first, then POST a JSON body with `sub_issue_id` as an integer.

```bash
# database id, not #number
SUB_ID=$(gh api repos/ahayehaye/copilot-agentic-engineering/issues/<sub-number> --jq .id)

jq -n --argjson id "$SUB_ID" '{sub_issue_id: $id}' > /tmp/sub-issue-payload.json
gh api -X POST repos/ahayehaye/copilot-agentic-engineering/issues/<parent>/sub_issues --input /tmp/sub-issue-payload.json
```

Use `replace_parent: true` in the JSON body to move a sub-issue to a new parent.

Where sub-issues are not available, the body-fallback mechanisms below apply.

## Slice discovery

Used by any workflow that needs a parent's vertical slices — `verify-ac` (parent mode), `/implement` (dependency graph), and the director's slice loop. Run **all three** mechanisms below and take the union, deduplicated, in number order — the strict-union rule is the consumer's; the priority order below is readability only. A 404 or empty result from any mechanism is fine — the other mechanisms still run.

1. **Sub-issues endpoint**: `gh api repos/ahayehaye/copilot-agentic-engineering/issues/<parent>/sub_issues`
2. **Body search — `## Parent` section**: a `## Parent` heading line, one or more whitespace lines, then a line that is exactly `#<parent>`:
   `gh issue list --state open --json number,title,body --jq '[.[] | select(.body | test("(?m)^## Parent\\s*\\n\\n+\\s*#<parent>\\s*$")) | .number]'`
3. **Body search — `Part of` line**: `gh issue list --state open --json number,title,body --jq '[.[] | select(.body | test("(?m)^(Part of #<parent>)\\s*$")) | .number]'`

The body searches keep their open-state filter.

## Body edit

Used to edit an issue body in place (e.g., checking AC boxes: `- [ ]` → `- [x]`).

Write the full new body to a file and PATCH it as a JSON file input:

```bash
jq -n --rawfile b new-body.md '{body: $b}' > body.json
gh api -X PATCH repos/ahayehaye/copilot-agentic-engineering/issues/<n> --input body.json
```

Never use the form-field body form (`gh api -X PATCH ... -f body=...`) — it mangles newlines.

## Ticket labels

The standard label taxonomy for this repo — exactly two labels, created idempotently (create only if missing; never create duplicates):

| Label | Description |
|-------|-------------|
| `spec` | Product Requirements Document, should be created by /to-spec |
| `vertical-slice` | Vertical slice (aka "tracer bullet"), should be created by /to-tickets |

```bash
gh label list --json name,description
gh label create spec --description "Product Requirements Document, should be created by /to-spec"
gh label create vertical-slice --description 'Vertical slice (aka "tracer bullet"), should be created by /to-tickets'
```

**Label application rule:** a spec published by `/to-spec` is created with the `spec` label; a slice published by `/to-tickets` is created with the `vertical-slice` label.

**Precedence:** the label application rule takes precedence over any skill instruction to apply a different default label (for example `ready-for-agent`); `spec` and `vertical-slice` are always applied as stated, and extra triage labels may be added on top.

Wayfinder labels live in the wayfinding section.
