# Contributing to Study Collab

How to add a new feature to this project. Follow this every time.

## The rule

No code is written until an ADR is accepted on `main`. The agent that writes code is not the agent that approves it.

## Workflow

### 1. Architect writes an ADR

Trigger the `architect` agent with a prompt that locks the scope. Use this skeleton:

```
@agent-architect — Write ADR NNNN for <feature name>

## Constraints (locked, do not relitigate)
- <decision 1>
- <decision 2>

## What to do
1. Read CLAUDE.md and existing ADRs in docs/decisions/.
2. Copy docs/decisions/_template.md exactly.
3. Make and justify these sub-decisions: <list>
4. Present 2-3 options per sub-decision with Pro / Con / Reversal cost.

## What NOT to touch
- No code in lib/.
- Do not fill Team approval.
- Status stays Proposed.
```

The ADR lands at `docs/decisions/NNNN-<slug>.md`. NNNN is the next sequential number (check the last file).

### 2. Human reviews and accepts

Open the ADR. Verify:

- Each sub-decision has 2-3 options with Pro/Con/Reversal cost.
- The Decision section names exactly which option won and why.
- Consequences lists concrete file paths and analytics events.
- Reversal plan names files and downstream ADRs that change.
- No contradictions with prior ADRs.

If something is wrong, send a follow-up prompt to the architect with specific line numbers and required changes. Do not edit the ADR yourself.

When clean, fill the Team approval block:

```
Approved by: <your name>
Date: YYYY-MM-DD
Notes:
```

Change Status to `Accepted`.

### 3. Merge the ADR to main

ADRs live on `main` so every branch and every teammate sees them.

```bash
git checkout main
git pull origin main
git add docs/decisions/NNNN-<slug>.md
git commit -m "docs: ADR NNNN - <title>"
git push origin main
```

For larger changes that touch multiple files, open a PR instead of pushing directly.

### 4. Branch for implementation

```bash
git checkout main
git pull origin main
git checkout -b feat/<short-name>
git push -u origin feat/<short-name>
```

### 5. Flutter Engineer implements

Trigger the `flutter-engineer` agent. The prompt must:

- Reference the accepted ADR by number and path.
- List the exact files to create (copy from the ADR's Consequences).
- State what NOT to build (scope creep prevention).
- Specify the UI reference if one exists.

The agent implements domain, data, and presentation layers. No scope expansion beyond the ADR.

### 6. Review

The agent that wrote the code does not approve it. Trigger one of:

- `architect` — verify implementation matches the ADR.
- `qa-engineer` — test matrix, accessibility, performance.
- `security-reviewer` — auth flows, Firestore rules, secrets.

Reviewer leaves an audit report in `docs/audit/NNNN-<slug>.md` using `docs/audit/_template.md`.

### 7. Merge to main

Open a PR from `feat/<name>` to `main`. Title: `feat: <feature name>`. Squash and merge. Delete the branch.

```bash
git checkout main
git pull origin main
git branch -d feat/<name>
git fetch --prune
```

## Skip the ADR only when

The change touches a single file and has no architectural impact. Examples: typo fix, dependency version bump, CLAUDE.md edit. Everything else gets an ADR.

## Do not

- Write code before the ADR is `Accepted` on main.
- Approve your own work (writer ≠ approver).
- Edit a merged ADR. Write a new ADR that supersedes it.
- Edit files listed under "Do not edit" in CLAUDE.md.
- Commit directly to main without a PR for code changes.

## Quick reference

| Step | Branch | Agent | Output |
|---|---|---|---|
| 1 | any | architect | `docs/decisions/NNNN-<slug>.md` (Proposed) |
| 2 | any | human | ADR set to Accepted |
| 3 | main | human | ADR merged to main |
| 4 | new `feat/<name>` | human | branch created |
| 5 | `feat/<name>` | flutter-engineer | code in `lib/features/<name>/` |
| 6 | `feat/<name>` | architect / qa-engineer / security-reviewer | audit report |
| 7 | main | human | PR merged, branch deleted |
