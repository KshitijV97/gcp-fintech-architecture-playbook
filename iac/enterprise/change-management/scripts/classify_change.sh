#!/bin/sh
# Classify a Terraform plan into an ITIL change type.
#
#   STANDARD  pre-approved, low risk: only creates/updates of non-sensitive types,
#             at most 20 resources. Can be applied in any standard window.
#   NORMAL    needs CAB: any delete/replace, any sensitive resource type, or a
#             large blast radius.
#
# Output: risk.env with CHANGE_TYPE and counts, used by servicenow_change.sh.
set -eu

PLAN_JSON="${1:?usage: classify_change.sh plan.json}"

SENSITIVE='["google_kms_crypto_key","google_kms_key_ring","google_access_context_manager_service_perimeter","google_org_policy_policy","google_logging_organization_sink","google_logging_project_bucket_config","google_organization_iam_audit_config","google_alloydb_cluster","google_spanner_instance","google_sql_database_instance"]'

DELETES=$(jq '[.resource_changes[] | select(.change.actions | index("delete"))] | length' "$PLAN_JSON")
CHANGES=$(jq '[.resource_changes[] | select(.change.actions != ["no-op"] and .change.actions != ["read"])] | length' "$PLAN_JSON")
SENSITIVE_HITS=$(jq --argjson s "$SENSITIVE" '[.resource_changes[] | select(.change.actions != ["no-op"]) | select(.type as $t | $s | index($t))] | length' "$PLAN_JSON")

if [ "$DELETES" -gt 0 ] || [ "$SENSITIVE_HITS" -gt 0 ] || [ "$CHANGES" -gt 20 ]; then
  CHANGE_TYPE=NORMAL
else
  CHANGE_TYPE=STANDARD
fi

cat > risk.env <<EOF
CHANGE_TYPE=$CHANGE_TYPE
RESOURCES_CHANGED=$CHANGES
RESOURCES_DELETED=$DELETES
SENSITIVE_CHANGES=$SENSITIVE_HITS
EOF

echo "Change classification: $CHANGE_TYPE (changed=$CHANGES deleted=$DELETES sensitive=$SENSITIVE_HITS)"
