---
name: ado-boards
description: 'Operate on Azure DevOps (ADO) work items end-to-end via the Azure CLI (az boards): list, show, update, comment, link, create, and delete ADO work items, plus curated raw-REST recipes for state discovery, work-item-type listing, and revisions. Load when the user asks about Azure DevOps / ADO work items (e.g. "summarize my open ADO items", "move ADO #N to done") or when another skill or workflow delegates Azure DevOps work-item operations to this skill by name. Do not load for generic "work item" or "Azure" requests that do not name Azure DevOps or ADO.'
version: 1.0.2
---

# ADO Boards

Operate on Azure DevOps work items through the Azure CLI. `az boards` lives in the `azure-devops` extension (Azure CLI >= 2.30.0), which auto-installs on first `az boards` use; the manual install is `az extension add --name azure-devops` (not `boards`). Cloud orgs only — the extension refuses Azure DevOps Server (on-prem).

## Preflight (check-only, once per session)

1. Read the config defaults once: `az devops configure -l`. Never run `az devops configure -d` or any other az configuration command unless the user explicitly asks — this skill never mutates az configuration.
2. Resolve the org URL `<org>` at runtime, in this order: the org in the repo's tracker doc (authoritative for the repo), the git remote via `--detect` (works only inside a clone whose remote points at `dev.azure.com`), the `organization` default from step 1, or ask the user. `<org>` is a placeholder — never hardcode an org URL.
3. If no default exists, pass `--org <org>` explicitly on every call.
4. On an auth error, name the fix: `az login` (Microsoft Entra, interactive), `az devops login` (stores a PAT), or the `AZURE_DEVOPS_EXT_PAT` environment variable for CI/headless sessions.

**Repo binding.** The repo's tracker doc may supply the org. The doc carries binding data only (org, default project, surface); all command knowledge stays in this skill.

## Repo onboarding

End-to-end checklist for onboarding a repo to ADO:

1. **Machine** — az CLI + `azure-devops` extension installed system-wide; the user authenticated via `az devops login` or the `AZURE_DEVOPS_EXT_PAT` environment variable.
2. **Repo** — the repo's tracker doc gains the ADO section below (binding data only).
3. **Optional glossary** — add ADO-specific glossary entries (e.g. "story") to the target repo's `CONTEXT.md` if the repo adopts them.
4. **Verify** — from a session in the repo, run one live read-only query (e.g. "my open items") and confirm the org resolves from the tracker doc without asking.

### ADO tracker-doc section template

"Surface" names which tracker holds the repo's work items — one tracker, or the split in a hybrid repo.

```markdown
## ADO

- Organization: https://dev.azure.com/<org>
- Default project: <Project>
- Surface: ADO (all work items)

Operations: delegate to the `ado-boards` skill by name; pass the organization above as `--org` on every call.
```

Hybrid variant (ADO for stories/tasks, GitHub for specs/slices/PRs) — state the split explicitly and name each workflow skill's surface:

```markdown
## ADO

- Organization: https://dev.azure.com/<org>
- Default project: <Project>
- Surface split: GitHub holds specs, vertical slices, and PRs; ADO holds stories and tasks.
  - /to-spec → GitHub
  - /to-tickets → GitHub
  - /implement → GitHub
  - /verify-ac → GitHub
  - ADO work items (stories/tasks) → `ado-boards` skill

Operations: delegate ADO work-item operations to the `ado-boards` skill by name; pass the organization above as `--org` on every call.
```

**Public-repo caveat.** A version-controlled org URL leaks the org and project names to anyone who can read the repo. Do not onboard a public repo to a private org that way; the az-config-default path (per-machine, not version-controlled) is the safer record there.

**Promotion signal.** A second repo onboarded with repetitive steps → consider a dedicated onboarding skill; the `wizard` skill is the shape if a step needs human hands.

## Intent to command

`--project` asymmetry: required on `work-item create` and `work-item delete` only; `show`, `update`, `relation *`, and `query --wiql` do not take `--project`.

| Intent | Command |
| --- | --- |
| my open items | `az boards query --org <org> --wiql "<my open items template below>" --output json` |
| show #N | `az boards work-item show --id N --org <org> --fields System.Id,System.Title,System.State,System.AssignedTo,System.Tags,System.Description --output json` |
| move #N to state X | run state discovery first, then `az boards work-item update --id N --state X --org <org>` |
| retitle / reassign #N | `az boards work-item update --id N --title "..." --assigned-to me --org <org>` |
| tag #N | read-modify-write: `az boards work-item update --id N --fields "System.Tags=<existing> <new>" --org <org>` |
| comment on #N | `az boards work-item update --id N --discussion "..." --org <org>` (disclose first — see Known limitations) |
| link #A under #B | `az boards work-item relation add --id A --relation-type parent --target-id B --org <org>` |
| create a work item | run type listing first, then `az boards work-item create --type Bug --title "..." --project <Project> --org <org>` |
| what changed in #N | the revisions recipe below |
| delete #N / remove a relation | guarded — see Guardrails |

There is no `work-item list` — listing is always WIQL. `--assigned-to` accepts a display name, email, alias, GUID, or the literal `me`. `--relation-type` accepts friendly names (`parent`, `child`, `relates`, `duplicate`), matched case-insensitively.

## Raw-REST recipes (the only REST calls this skill makes)

Run via `az devops invoke`; the agent never constructs any other REST call. Verify exact resource spelling on first use — the spellings below are pattern-derived and the server's error message is the arbiter.

1. **State discovery** — required before any `--state` update (state names are process-dependent and no CLI command lists them):

   ```bash
   az devops invoke --area wit --resource "workitemtypes/<Type>/states" \
     --route-parameters project=<Project> --api-version 7.1 --org <org> --output json
   ```

   Match the user's word ("done", "closed") against the returned state names. On a `RuleValidationException`, surface the server's allowed-state hint verbatim and retry once.
2. **Work-item-type listing** — required before `create`:

   ```bash
   az devops invoke --area wit --resource "workitemtypes" \
     --route-parameters project=<Project> --api-version 7.1 --org <org> --output json
   ```
3. **Revisions listing** — for "what changed in #N", with `$top`/`$skip` pagination:

   ```bash
   az devops invoke --area wit --resource "workitems/<id>/revisions" \
     --route-parameters project=<Project> --api-version 7.1 \
     --query-parameters "\$top=20" "\$skip=0" --org <org> --output json
   ```

## WIQL

Ready-made templates (substitute `<...>`; the `SELECT` clause determines which fields come back):

| Template | WIQL |
| --- | --- |
| my open items | `SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.AssignedTo] = @Me AND [System.State] NOT IN ('Closed', 'Removed') ORDER BY [System.Id]` |
| open items in a project | `SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.TeamProject] = '<Project>' AND [System.State] NOT IN ('Closed', 'Removed') ORDER BY [System.Id]` |
| items by tag | `SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.Tags] CONTAINS '<tag>' ORDER BY [System.Id]` |
| children of a parent | `SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.ParentId] = <id> ORDER BY [System.Id]` |

Constraints: flat queries only (no nested subqueries); hard cap of 1000 work items (fetched in batches of 200 IDs per REST call, no pagination flags); 32,000-character query limit; available macros: `@Me`, `@project`, `@today`, `@StartOf*`.

## Output discipline

- Always `--output json` for agent consumption.
- Trim payloads: `show --fields` for a single item; a narrow `SELECT` clause for queries (the only size control on queries).
- Field names contain dots — double-quote them in JMESPath (jmespath 1.x, as bundled with current Azure CLI; backtick quoting was removed) and single-quote the whole `--query` value in the shell: `--query 'fields."System.Title"'`.
- `System.Description` and `System.History` come back as HTML, not markdown — strip tags before display.

## Guardrails

- `work-item delete` and `relation remove`: state the target (id and title) and get explicit user confirmation before passing `--yes` — the CLI's own prompt hangs in headless sessions. The commands: `az boards work-item delete --id N --project <Project> --org <org> --yes` (`--project` is required here) and `az boards work-item relation remove --id N --relation-type <type> --target-id M --org <org> --yes`.
- `--destroy` is off-limits: it is permanent. Without it, deletions go to the recycle bin and are recoverable.
- Tag changes are read-modify-write: `--fields` applies JSON Patch `add` operations, i.e. replace, not append — `--fields "System.Tags=newtag"` overwrites the whole tag string. Read the current `System.Tags` first and write back the full string.

## Known limitations

- `--discussion` writes to `System.History` as a JSON patch — it is not a real comment thread: no author attribution, no comment ID, no way to list or reply. Disclose this to the user before every comment. Real comment threads via the REST comments/threads API are the documented v1.1 extension point.
- No labels: `System.Tags` (a single space-separated string) is the closest, with the replace semantics above.
- No CLI commands for `work-item list`, `export`, `comments`, `attachments`, `revisions`, `fields`, or `types` — the three recipes above are the only REST path.
- No full-text search without WIQL; no "close" verb — state names are process-dependent (see state discovery).
- Query results are capped at 1000 items with no pagination.
