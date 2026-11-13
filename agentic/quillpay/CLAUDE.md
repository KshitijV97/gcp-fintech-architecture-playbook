@AGENTS.md

## Claude Code specifics
- Models run on **Vertex AI in the `eu` multi-region** (see `.claude/settings.json`). Set `ANTHROPIC_VERTEX_PROJECT_ID` in your personal `.claude/settings.local.json`.
- Start every session with the `/deliverable` skill: it restates the intent, classifies the tier and opens the session branch.
- Use subagents: `test-writer` for test scaffolding, `reviewer` for a self-review before opening the PR, and `compliance-checker` for any tier-2 change.
- Prefer working in a git worktree per session so parallel sessions never collide.
