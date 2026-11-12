# AGENTS.md: Quillpay platform

Tool-neutral instructions for every coding agent working in this repository (Claude Code imports this file from `CLAUDE.md`; OpenCode and OpenHands read it directly).

## Mission and context
- Quillpay runs **Project Sentinel**: real-time payment-fraud scoring for EU (GDPR) and Canadian (PIPEDA) customers.
- Two **jurisdiction cells**: `prod-eu` (europe-west3) and `prod-ca` (northamerica-northeast1). Personal data never crosses cells.
- Architecture reference: `docs/adr/`, plus the playbook chapters on Case 1 and Case 5.

## How we work: one intent, one session, one PR
1. Restate the intent and acceptance criteria. If the risk tier is 2 or higher, **stop and present a plan** before editing.
2. Work only on the session branch `session/<short-slug>`. Never commit to `main`.
3. Keep the diff to one outcome. If you discover unrelated work, write it down as a follow-up instead of doing it.
4. Write or update tests first where practical. Update the runbook or ADR if behaviour changes.
5. Before declaring done, run: `make test`, `make lint`, `make policy` (conftest), and `make plan ENV=staging` if `infra/` changed.
6. Fill in the PR template's **Session record** completely.

## Risk tiers (CI enforces these from the diff)
| Tier | Paths | You may |
|---|---|---|
| 0 | `docs/`, tests | Implement directly |
| 1 | `apps/`, `packages/` | Implement directly |
| 2 | `infra/`, `policies/`, `.claude/`, `AGENTS.md`, `CLAUDE.md`, `.mcp.json`, consent/DSR code, BigQuery schemas | **Plan first, wait for approval** |
| 3 | Anything touching production data or keys | **Do not act.** Hand back to a human |

## Hard rules (non-negotiable)
- **No production access.** Never run commands against `qp-prod-*` projects. Never run `terraform apply` or `terraform destroy`.
- **No real personal data.** Use the synthetic fixtures in `testdata/`. Never paste customer data into prompts, code, logs or tests.
- **No secrets.** Never read `.env*`, `*.tfvars` or `secrets/`. Use Secret Manager references in code.
- **Residency.** EU resources stay in EU regions; CA resources stay in `northamerica-northeast1/2`. Conftest will reject violations.
- **Crypto.** Never delete or disable KMS keys or key versions in code. Key destruction is a tier-3 human procedure (crypto-shredding).
- **Logging.** Never log personal data; use `packages/telemetry` scrubbers.

## Conventions
- Languages: TypeScript (services), Python (data jobs), Terraform ≥ 1.9 with `hashicorp/google ~> 8.11`.
- Commits: Conventional Commits. The squash commit title is the intent title.
- Every new resource carries labels: `jurisdiction`, `environment`, `data_classification`.
