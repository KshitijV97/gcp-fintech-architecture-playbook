# Data residency guardrails, evaluated against `terraform show -json tfplan`.
#
#   GDPR Art. 44-49  -> EU-jurisdiction resources stay in EU locations
#   PIPEDA Principle 4.1.3 / OSFI B-10 -> CA-jurisdiction resources stay in Canadian
#   regions (a business choice for Aldervane Canada; PIPEDA itself allows transfers
#   with accountability. See docs/case-studies/05-canada-pipeda.md)
#
# This is a SECOND line of defence. Org Policies (gcp.resourceLocations) are the
# first. Shift-left: fail in the PR, not at apply time.
package main

import rego.v1

location_attrs := ["location", "region"]

changed contains rc if {
	some rc in input.resource_changes
	some action in rc.change.actions
	action in {"create", "update"}
}

is_eu(loc) if startswith(lower(loc), "europe-")

is_eu(loc) if lower(loc) in {"eu", "europe", "global"}

is_ca(loc) if startswith(lower(loc), "northamerica-northeast")

is_ca(loc) if lower(loc) == "global"

jurisdiction(rc) := j if {
	j := rc.change.after.labels.jurisdiction
} else := j if {
	j := rc.change.after.resource_labels.jurisdiction
} else := "eu"

deny contains msg if {
	some rc in changed
	jurisdiction(rc) == "eu"
	some attr in location_attrs
	loc := rc.change.after[attr]
	is_string(loc)
	not is_eu(loc)
	msg := sprintf("[RESIDENCY-EU] %s: %s '%s' is outside the EU (GDPR Art. 44).", [rc.address, attr, loc])
}

deny contains msg if {
	some rc in changed
	jurisdiction(rc) == "ca"
	some attr in location_attrs
	loc := rc.change.after[attr]
	is_string(loc)
	not is_ca(loc)
	msg := sprintf("[RESIDENCY-CA] %s: %s '%s' is outside Canada (Aldervane Canada data-residency standard).", [rc.address, attr, loc])
}
