#!/usr/bin/env bash
# Illustrative ServiceNow integration for infrastructure changes.
#
#   draft  <sha> <pr>  create or update a change_request with the plan summary
#   verify <sha>       gate: approved, in window, matches this commit
#   close  <sha>       move to Review with the apply log attached
#
# Requires: SNOW_INSTANCE (e.g. aldervane.service-now.com), SNOW_TOKEN.
# Uses the standard Table API (/api/now/table/change_request). Field names such
# as u_commit_sha are custom fields; adapt them to your instance.
set -euo pipefail

ACTION="${1:?action}"
SHA="${2:?commit sha}"
SNOW_INSTANCE="${SNOW_INSTANCE:-aldervane.service-now.com}"
API="https://${SNOW_INSTANCE}/api/now/table/change_request"
AUTH=(-H "Authorization: Bearer ${SNOW_TOKEN}" -H "Content-Type: application/json" -H "Accept: application/json")

find_change() {
  curl -fsS "${AUTH[@]}" "${API}?sysparm_query=u_commit_sha=${SHA}&sysparm_limit=1" | jq -r '.result[0] // empty'
}

case "$ACTION" in
  draft)
    PR="${3:-unknown}"
    # shellcheck disable=SC1091
    source risk.env
    if [[ "$CHANGE_TYPE" == "STANDARD" ]]; then TYPE="standard"; else TYPE="normal"; fi
    BODY=$(jq -n --arg sha "$SHA" --arg pr "$PR" --arg type "$TYPE" \
      --arg desc "Terraform change from PR #${PR}. changed=${RESOURCES_CHANGED} deleted=${RESOURCES_DELETED} sensitive=${SENSITIVE_CHANGES}" \
      '{type:$type, short_description:("IaC: PR #" + $pr), description:$desc, u_commit_sha:$sha, category:"Cloud Infrastructure"}')
    curl -fsS "${AUTH[@]}" -X POST "$API" -d "$BODY" | jq -r '.result.number'
    ;;

  verify)
    CHG=$(find_change)
    [[ -n "$CHG" ]] || { echo "No change request references commit $SHA"; exit 1; }
    STATE=$(jq -r '.state' <<<"$CHG")
    TYPE=$(jq -r '.type' <<<"$CHG")
    START=$(jq -r '.start_date' <<<"$CHG")
    END=$(jq -r '.end_date' <<<"$CHG")
    NOW=$(date -u +"%Y-%m-%d %H:%M:%S")

    # ServiceNow numeric states: -2 Scheduled, -1 Implement (OOTB values)
    if [[ "$STATE" != "-2" && "$STATE" != "-1" ]]; then
      echo "Change $(jq -r .number <<<"$CHG") is not approved/scheduled (state=$STATE)"; exit 1
    fi
    if [[ "$TYPE" != "standard" && ( "$NOW" < "$START" || "$NOW" > "$END" ) ]]; then
      echo "Outside the approved change window ($START to $END UTC)"; exit 1
    fi
    echo "Change gate passed: $(jq -r .number <<<"$CHG")"
    ;;

  close)
    CHG=$(find_change)
    SYS_ID=$(jq -r '.sys_id' <<<"$CHG")
    curl -fsS "${AUTH[@]}" -X PATCH "${API}/${SYS_ID}" \
      -d "$(jq -n --arg notes "$(tail -c 30000 /workspace/apply.log)" '{state:"0", close_code:"successful", close_notes:$notes}')" >/dev/null
    echo "Change moved to Review"
    ;;

  *)
    echo "unknown action: $ACTION"; exit 2
    ;;
esac
