#!/usr/bin/env bash
# Every "TECH-DEBT TD-xxx" marker in Terraform must have a row in TECH_DEBT.md,
# and that row's expiry date must not have passed.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/iac/enterprise"
REGISTER="$ROOT/TECH_DEBT.md"
TODAY=$(date -u +%Y-%m-%d)
FAIL=0

for id in $(grep -rhoE 'TECH-DEBT TD-[0-9]{3}' "$ROOT" --include='*.tf' | awk '{print $2}' | sort -u); do
  row=$(grep -E "^\| ${id} \|" "$REGISTER" || true)
  if [[ -z "$row" ]]; then
    echo "❌ $id is referenced in code but missing from TECH_DEBT.md"; FAIL=1; continue
  fi
  expiry=$(awk -F'|' '{gsub(/ /,"",$8); print $8}' <<<"$row")
  if [[ "$expiry" < "$TODAY" ]]; then
    echo "❌ $id expired on $expiry: remediate or get a CAB-approved extension"; FAIL=1
  else
    echo "✅ $id registered, expires $expiry"
  fi
done

exit $FAIL
