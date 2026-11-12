# Quillpay: Startup IaC Blueprint

Lean, opinionated, **compliant by default**. Narrative walkthrough: [docs/iac/06-startup-iac.md](../../docs/iac/06-startup-iac.md).

```text
startup/
├── bootstrap/            # run once: folders, guardrails, state bucket, GitHub OIDC
├── modules/platform/     # one jurisdiction cell: Cloud Run, Cloud SQL, Pub/Sub, BigQuery, GCS, KMS
│   └── privacy_tables.tf # consent ledger, disclosure log, breach register, DSR log
├── envs/
│   ├── staging/          # EU, synthetic data
│   ├── prod-eu/          # GDPR cell, europe-west3
│   └── prod-ca/          # PIPEDA cell, northamerica-northeast1 (Case 5)
├── policies/             # conftest guardrails
└── ci/                   # GitHub Actions workflow (copy into .github/workflows/)
```

## Quick start (sandbox org)

```bash
cd bootstrap && terraform init && terraform apply \
  -var org_id=... -var billing_account=... -var customer_id=... -var github_repo=owner/repo
```

Then set the GitHub repository variables `GCP_WIF_PROVIDER`, `GCP_TERRAFORM_SA`, `GCP_BILLING_ACCOUNT` and `GCP_FOLDER_{STAGING,PROD_EU,PROD_CA}` (from the bootstrap outputs), copy `ci/github-actions-terraform.yml` to `.github/workflows/`, and push. CI takes over from there. For local runs, pass the same values as `TF_VAR_*` environment variables.

> ⚠️ `lock_retention = true` in `prod-*` locks the breach-records bucket retention **irreversibly**. Set it to `false` in sandboxes.
