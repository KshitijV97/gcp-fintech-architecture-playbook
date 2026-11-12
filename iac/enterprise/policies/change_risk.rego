# Change-risk signals: these are WARNINGS, not denials. The pipeline turns them
# into a risk class (see change-management/scripts/classify_change.sh) that
# decides whether a change can go as a pre-approved Standard change or needs CAB.
package main

import rego.v1

sensitive_types := {
	"google_kms_crypto_key",
	"google_kms_key_ring",
	"google_access_context_manager_service_perimeter",
	"google_org_policy_policy",
	"google_logging_organization_sink",
	"google_logging_project_bucket_config",
	"google_organization_iam_audit_config",
	"google_alloydb_cluster",
	"google_spanner_instance",
	"google_sql_database_instance",
}

warn contains msg if {
	some rc in input.resource_changes
	"delete" in rc.change.actions
	msg := sprintf("[HIGH-RISK] %s will be DESTROYED or REPLACED. Normal change + CAB required.", [rc.address])
}

warn contains msg if {
	some rc in changed
	rc.type in sensitive_types
	msg := sprintf("[MEDIUM-RISK] %s touches a security-sensitive resource type (%s).", [rc.address, rc.type])
}
