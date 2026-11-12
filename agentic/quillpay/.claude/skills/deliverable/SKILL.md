---
name: deliverable
description: Start a Quillpay session. Restates the intent, classifies the risk tier, opens the session branch, and sets up the session record. Use at the start of every piece of work.
---

# Start a session deliverable

Intent: $ARGUMENTS

1. Restate the intent as **one outcome** with explicit acceptance criteria. If it contains more than one outcome, propose a split and stop.
2. Classify the **risk tier** using the table in `AGENTS.md`, based on the paths you expect to touch.
3. Create the branch: `git switch -c session/<short-slug>` (or a new worktree for parallel sessions).
4. If the tier is **2 or higher**: write a plan (files, tests, rollback, compliance impact) and **stop for approval**.
5. Otherwise: implement, then run `make test lint policy` (and `make plan ENV=staging` if `infra/` changed).
6. Run the `reviewer` subagent, and `compliance-checker` for tier 2.
7. Draft the PR body using the **Session record** section of `.github/pull_request_template.md`.
