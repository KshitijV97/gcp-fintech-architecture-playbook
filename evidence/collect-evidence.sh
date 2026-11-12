#!/usr/bin/env bash
# collect-evidence.sh: build a dated, hash-manifested evidence pack for auditors.
#
# Collects point-in-time configuration evidence for GDPR, PIPEDA, DORA and OSFI
# controls (see docs/10-evidence-register.md, column "Evidence ID").
# Read-only: it only runs describe/list/export commands.
#
# Usage:
#   ./collect-evidence.sh --org 123456789012 --projects "qp-prod-eu-app qp-prod-ca-app" \
#       --access-policy 987654321 [--out ./packs]
#
# Requires gcloud (authenticated with a read-only auditor role, e.g.
# roles/iam.securityReviewer + roles/cloudasset.viewer + roles/orgpolicy.policyViewer)
# and bq, jq, sha256sum (or shasum).
set -euo pipefail

ORG="" PROJECTS="" ACCESS_POLICY="" OUT="./packs"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --org) ORG="$2"; shift 2 ;;
    --projects) PROJECTS="$2"; shift 2 ;;
    --access-policy) ACCESS_POLICY="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "unknown arg $1"; exit 2 ;;
  esac
done
[[ -n "$ORG" && -n "$PROJECTS" ]] || { echo "need --org and --projects"; exit 2; }

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
PACK="$OUT/evidence-$STAMP"
mkdir -p "$PACK"
log() { echo "[$(date -u +%H:%M:%S)] $*"; }
run() { # run <evidence-id> <file> <command...>
  local id="$1" file="$2"; shift 2
  log "$id → $file"
  if ! "$@" > "$PACK/$file" 2> "$PACK/$file.err"; then
    echo "COLLECTION FAILED: see $file.err" >> "$PACK/$file"
  fi
  [[ -s "$PACK/$file.err" ]] || rm -f "$PACK/$file.err"
}

# --- EV-ORG: organisation guardrails (GDPR Art. 25/44, PIPEDA 4.7, 4.1.3) -------
run EV-ORG-01 org-policies.json gcloud org-policies list --organization="$ORG" --show-unset=false --format=json
for c in gcp.resourceLocations iam.disableServiceAccountKeyCreation compute.vmExternalIpAccess storage.publicAccessPrevention; do
  run EV-ORG-02 "org-policy-$c.json" gcloud org-policies describe "$c" --organization="$ORG" --effective --format=json
done
run EV-ORG-03 folders.json gcloud resource-manager folders list --organization="$ORG" --format=json
run EV-ORG-04 assured-workloads.json gcloud assured workloads list --organization="$ORG" --location=europe-west3 --format=json

# --- EV-PER: perimeters (GDPR Art. 32, PIPEDA 4.7) ------------------------------------
if [[ -n "$ACCESS_POLICY" ]]; then
  run EV-PER-01 vpc-sc-perimeters.json gcloud access-context-manager perimeters list --policy="$ACCESS_POLICY" --format=json
  run EV-PER-02 vpc-sc-dry-run.json gcloud access-context-manager perimeters dry-run list --policy="$ACCESS_POLICY" --format=json
fi

# --- EV-INV: inventory + residency of every resource (GDPR Art. 30/44, DORA Art. 8) --
run EV-INV-01 asset-inventory-locations.json gcloud asset search-all-resources \
  --scope="organizations/$ORG" --format="json(name,assetType,location,labels)"
run EV-INV-02 non-compliant-locations.json bash -c \
  "jq '[.[] | select(.location != null and (.location|test(\"^(europe-|eu$|global$|northamerica-northeast)\")|not))]' '$PACK/asset-inventory-locations.json'"

# --- EV-LOG: audit-trail integrity (GDPR Art. 33, PIPEDA s.10.3, DORA Art. 12) ---------
run EV-LOG-01 org-sinks.json gcloud logging sinks list --organization="$ORG" --format=json
run EV-LOG-02 org-audit-config.json gcloud organizations get-iam-policy "$ORG" --format="json(auditConfigs)"

for P in $PROJECTS; do
  D="projects/$P"; mkdir -p "$PACK/$D"

  # --- EV-KMS: keys, protection level, rotation (GDPR Art. 32, PIPEDA 4.7) ------------
  run EV-KMS-01 "$D/kms-keys.json" gcloud asset search-all-resources --scope="projects/$P" \
    --asset-types=cloudkms.googleapis.com/CryptoKey --format=json

  # --- EV-CMEK: services encrypted with CMEK --------------------------------------------
  run EV-CMEK-01 "$D/sql-instances.json" gcloud sql instances list --project="$P" \
    --format="json(name,region,diskEncryptionConfiguration,settings.ipConfiguration.ipv4Enabled,settings.backupConfiguration)"
  run EV-CMEK-02 "$D/pubsub-topics.json" gcloud pubsub topics list --project="$P" \
    --format="json(name,kmsKeyName,messageStoragePolicy)"
  run EV-CMEK-03 "$D/buckets.json" gcloud storage buckets list --project="$P" \
    --format="json(name,location,default_kms_key,retention_policy,public_access_prevention,uniform_bucket_level_access)"

  # --- EV-BRC: PIPEDA s.10.3 breach-record retention ≥ 24 months, locked -------------------
  run EV-BRC-01 "$D/breach-bucket-retention.json" bash -c \
    "jq '[.[] | select(.name|test(\"breach-records\")) | {name, retention_policy, ok: ((.retention_policy.retentionPeriod|tonumber) >= 63072000 and .retention_policy.isLocked == true)}]' '$PACK/$D/buckets.json'"

  # --- EV-REG: privacy registers (PIPEDA 4.3, 4.9, 4.10, s.10.3; GDPR Art. 7, 12, 15, 33(5)) --
  run EV-REG-01 "$D/dsr-sla.json" bq --project_id="$P" query --use_legacy_sql=false --format=json \
    "SELECT jurisdiction, request_type, COUNT(*) AS total,
            COUNTIF(status='COMPLETED' AND event_time <= COALESCE(extended_until, due_at)) AS on_time,
            COUNTIF(extended_until IS NOT NULL AND extension_notice_sent_at IS NULL) AS extensions_without_notice
     FROM privacy.dsr_log
     WHERE event_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
     GROUP BY 1,2"
  run EV-REG-02 "$D/breach-register-summary.json" bq --project_id="$P" query --use_legacy_sql=false --format=json \
    "SELECT jurisdiction, COUNT(*) AS breaches_recorded,
            COUNTIF(ARRAY_LENGTH(reported_to) > 0) AS reported,
            MIN(determined_at) AS oldest_record
     FROM privacy.breach_register GROUP BY 1"
  run EV-REG-03 "$D/consent-coverage.json" bq --project_id="$P" query --use_legacy_sql=false --format=json \
    "SELECT jurisdiction, purpose, action, consent_form, COUNT(DISTINCT customer_token) AS customers
     FROM privacy.consent_ledger GROUP BY 1,2,3,4"

  # --- EV-IAM: no basic roles / public principals (GDPR Art. 32, PIPEDA 4.7) ----------------
  run EV-IAM-01 "$D/iam-policy.json" gcloud projects get-iam-policy "$P" --format=json
  run EV-IAM-02 "$D/iam-findings.json" bash -c \
    "jq '[.bindings[] | select(.role|test(\"roles/(owner|editor)\")) , (.bindings[] | select(.members[]|test(\"allUsers|allAuthenticatedUsers\")))]' '$PACK/$D/iam-policy.json'"
done

# --- Manifest: tamper evidence ------------------------------------------------------
log "Writing SHA-256 manifest"
( cd "$PACK" && find . -type f ! -name MANIFEST.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > MANIFEST.sha256 )
cat > "$PACK/README.txt" <<EOF
Evidence pack generated $STAMP (UTC)
Organization: $ORG
Projects: $PROJECTS
Collector: $(gcloud config get-value account 2>/dev/null || echo unknown)
Mapping of evidence IDs to controls: docs/10-evidence-register.md
Integrity: verify with 'shasum -a 256 -c MANIFEST.sha256'.
Store this pack in the locked audit archive bucket (WORM).
EOF
log "Done: $PACK"
