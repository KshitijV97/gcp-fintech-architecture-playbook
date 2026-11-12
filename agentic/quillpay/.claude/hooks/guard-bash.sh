#!/usr/bin/env bash
# PreToolUse guard for Bash commands. Defence in depth behind the permission
# rules: prefix deny rules don't catch `sh -c '...'` or absolute paths, so this
# hook inspects the full command string. Exit code 2 blocks the tool call and
# shows stderr to the agent.
set -euo pipefail

input="$(cat)"
# Command boundary: start of string, separators, whitespace, path slash,
# quotes, subshell "(" or backtick (catches sh -c "curl ...", $(wget ...)).
B="(^|[;&|[:space:]/\"'(\`])"
cmd="$(jq -r '.tool_input.command // ""' <<<"$input")"

block() {
  echo "BLOCKED by Quillpay guard: $1" >&2
  echo "If this is genuinely needed, stop and hand back to a human (tier 3)." >&2
  exit 2
}

# 1. Production is off-limits to agents.
grep -Eq 'qp-prod-[a-z0-9-]+' <<<"$cmd" && block "command references a production project"

# 2. No state-changing Terraform from agent sessions.
grep -Eq "${B}terraform[[:space:]]+(apply|destroy|import|state[[:space:]]+(rm|mv|push))" <<<"$cmd" \
  && block "terraform apply/destroy/import/state changes run only in CI"

# 3. Key destruction is a human, dual-controlled procedure (crypto-shredding).
grep -Eq 'kms[[:space:]]+keys[[:space:]]+versions[[:space:]]+(destroy|disable)' <<<"$cmd" \
  && block "KMS key version destruction is tier 3"

# 4. Secrets and credentials.
grep -Eq '(\.env(\.|$|[[:space:]])|\.tfvars|secrets/|application_default_credentials|gcloud[[:space:]]+auth[[:space:]]+print-access-token)' <<<"$cmd" \
  && block "access to secrets or credentials"

# 5. Data exfiltration paths (network fetch/push tools outside the allow-list).
grep -Eq "${B}(curl|wget|nc|ncat|scp|rsync)[[:space:]]" <<<"$cmd" \
  && block "direct network transfer tools are not allowed; use the approved MCP servers"

# 6. History rewriting on shared branches.
grep -Eq 'git[[:space:]]+push.*(--force|-f([[:space:]]|$))' <<<"$cmd" && block "force push"

exit 0
