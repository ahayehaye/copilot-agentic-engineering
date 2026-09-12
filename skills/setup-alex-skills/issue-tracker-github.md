## Sub-issues

**List a parent's sub-issues**

```bash
gh api repos/<owner>/<repo>/issues/<parent>/sub_issues
```

**Create a sub-issue link**

The REST `POST /repos/{owner}/{repo}/issues/{issue_number}/sub_issues` endpoint requires the sub-issue's **database id**, not the issue number. Get the id first, then POST a JSON body with `sub_issue_id` as an integer.

```bash
# database id, not #number
SUB_ID=$(gh api repos/<owner>/<repo>/issues/<sub-number> --jq .id)

jq -n --argjson id "$SUB_ID" '{sub_issue_id: $id}' > /tmp/sub-issue-payload.json
gh api -X POST repos/<owner>/<repo>/issues/<parent>/sub_issues --input /tmp/sub-issue-payload.json
```

Use `replace_parent: true` in the JSON body to move a sub-issue to a new parent.

Where sub-issues are not available, the body-fallback mechanisms below apply.

## Slice discovery

Used by any workflow that needs a parent's vertical slices — `verify-ac` (parent mode), `/implement` (dependency graph), and the director's slice loop. Run **all three** mechanisms below and take the union, deduplicated, in number order — the strict-union rule is the consumer's; the priority order below is readability only. A 404 or empty result from any mechanism is fine — the other mechanisms still run.

1. **Sub-issues endpoint**: `gh api repos/<owner>/<repo>/issues/<parent>/sub_issues`
2. **Body search — `## Parent` section**: a `## Parent` heading line, one or more whitespace lines, then a line that is exactly `#<parent>`:
   `gh issue list --state open --json number,title,body --jq '[.[] | select(.body | test("(?m)^## Parent\\s*\\n\\n+\\s*#<parent>\\s*$")) | .number]'`
3. **Body search — `Part of` line**: `gh issue list --state open --json number,title,body --jq '[.[] | select(.body | test("(?m)^(Part of #<parent>)\\s*$")) | .number]'`

The body searches keep their open-state filter.

## Body edit

Used to edit an issue body in place (e.g., checking AC boxes: `- [ ]` → `- [x]`).

Write the full new body to a file and PATCH it as a JSON file input:

```bash
jq -n --rawfile b new-body.md '{body: $b}' > body.json
gh api -X PATCH repos/<owner>/<repo>/issues/<n> --input body.json
```

Never use the form-field body form (`gh api -X PATCH ... -f body=...`) — it mangles newlines.

## Ticket labels

The standard label taxonomy for this repo — exactly two labels, created idempotently (create only if missing; never create duplicates):

```bash
gh label list --json name,description
gh label create spec --description "Product Requirements Document, should be created by /to-spec"
gh label create vertical-slice --description 'Vertical slice (aka "tracer bullet"), should be created by /to-tickets'
```

**Label application rule:** a spec published by `/to-spec` is created with the `spec` label; a slice published by `/to-tickets` is created with the `vertical-slice` label.

**Precedence:** the label application rule takes precedence over any skill instruction to apply a different default label (for example `ready-for-agent`); `spec` and `vertical-slice` are always applied as stated, and extra triage labels may be added on top.

Wayfinder labels live in the wayfinding section.
