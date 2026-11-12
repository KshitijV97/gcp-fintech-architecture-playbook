# Evidence Automation

`collect-evidence.sh` produces a dated, SHA-256-manifested **evidence pack** for GDPR, PIPEDA, DORA and OSFI audits. It's read-only and runs with an auditor service account.

```bash
./collect-evidence.sh --org 123456789012 \
  --projects "qp-prod-eu-app qp-prod-ca-app" \
  --access-policy 987654321 --out ./packs
```

Output:

```text
packs/evidence-20261112T090000Z/
├── README.txt
├── MANIFEST.sha256
├── org-policies.json                 EV-ORG-01
├── org-policy-gcp.resourceLocations.json  EV-ORG-02
├── assured-workloads.json            EV-ORG-04
├── vpc-sc-perimeters.json            EV-PER-01
├── asset-inventory-locations.json    EV-INV-01
├── non-compliant-locations.json      EV-INV-02  (should be [])
├── org-sinks.json                    EV-LOG-01
└── projects/qp-prod-ca-app/
    ├── kms-keys.json                 EV-KMS-01
    ├── buckets.json                  EV-CMEK-03
    ├── breach-bucket-retention.json  EV-BRC-01  (ok: true → PIPEDA s.10.3)
    ├── dsr-sla.json                  EV-REG-01
    ├── breach-register-summary.json  EV-REG-02
    ├── consent-coverage.json         EV-REG-03
    └── iam-findings.json             EV-IAM-02  (should be [])
```

Mapping of evidence IDs to controls: [docs/10-evidence-register.md](../docs/10-evidence-register.md).

`packs/` is git-ignored. Evidence belongs in the locked audit archive bucket, not in Git.
