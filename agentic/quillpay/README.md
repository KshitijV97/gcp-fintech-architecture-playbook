# Quillpay agent platform: reference configuration

Reference files for the agentic SDLC described in [docs/engineering/12-agentic-sdlc.md](../../docs/engineering/12-agentic-sdlc.md) and the platform in [docs/engineering/13-agent-platform.md](../../docs/engineering/13-agent-platform.md). In the real Quillpay monorepo, these files sit at the **repository root**.

```text
agentic/quillpay/
├── AGENTS.md                      # tool-neutral rules (Claude Code, OpenCode, OpenHands)
├── CLAUDE.md                      # imports @AGENTS.md + Claude-specific notes
├── .mcp.json                      # approved MCP servers
├── .claude/
│   ├── settings.json              # Vertex AI (eu), permissions, hooks
│   ├── hooks/guard-bash.sh        # PreToolUse guard (exit 2 = block)
│   ├── hooks/audit-log.sh         # PostToolUse audit trail
│   ├── agents/                    # reviewer, compliance-checker, test-writer
│   └── skills/deliverable/        # /deliverable <intent>
├── github/claude-pr-review.yml    # copy to .github/workflows/
├── opencode/opencode.jsonc        # self-hosted GLM provider + permissions
├── openhands/README.md            # Agent Canvas against GLM
└── self-hosted-llm/glm-vllm.yaml  # vLLM on GKE (internal only)
```

Formats checked against the official Claude Code, OpenCode and OpenHands documentation in November 2026. Confirm model IDs, vLLM versions and parsers on the model card before deploying.
