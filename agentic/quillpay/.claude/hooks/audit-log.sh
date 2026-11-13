#!/usr/bin/env bash
# PostToolUse audit trail: one JSON line per tool call, for SOC 2 / ISO 27001
# evidence that agent sessions stayed within policy. Writes locally (git-ignored)
# and, when QP_AUDIT_LOG_PROJECT is set, forwards to Cloud Logging, where the
# org-level sink routes it to the locked audit bucket.
set -euo pipefail

input="$(cat)"
dir="${CLAUDE_PROJECT_DIR:-.}/.claude/audit"
mkdir -p "$dir"

entry="$(jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg user "$(git config user.email 2>/dev/null || echo unknown)" '{
  ts: $ts,
  user: $user,
  session_id: .session_id,
  tool: .tool_name,
  command: (.tool_input.command // null),
  file: (.tool_input.file_path // null)
}' <<<"$input")"

echo "$entry" >> "$dir/$(date -u +%Y-%m-%d).jsonl"

if [[ -n "${QP_AUDIT_LOG_PROJECT:-}" ]]; then
  gcloud logging write agent-sessions "$entry" --payload-type=json \
    --project="$QP_AUDIT_LOG_PROJECT" --severity=INFO >/dev/null 2>&1 || true
fi

exit 0
