# Policy-as-code (OPA / Conftest)

These policies run against the JSON form of a Terraform plan **in every pull request**, before a human reviewer looks at it.

```bash
terraform plan -out tfplan
terraform show -json tfplan > plan.json
conftest test plan.json --policy ../../policies   # from a root module directory
```

| File | Rule IDs | Regulation |
|---|---|---|
| `residency.rego` | `RESIDENCY-EU`, `RESIDENCY-CA` | GDPR Art. 44–49, PIPEDA 4.1.3 accountability, OSFI B-10 |
| `security_baseline.rego` | `IAM-PUBLIC`, `IAM-BASIC-ROLE`, `GCS-UBLA`, `GCS-PAP`, `CMEK`, `LABELS` | GDPR Art. 32, PIPEDA 4.7, PCI DSS, DORA |
| `change_risk.rego` | `HIGH-RISK`, `MEDIUM-RISK` (warnings) | ITIL change management, DORA Art. 9 |

**Layers:** Org Policies stop non-compliant resources at the API, which is the *preventive* control. These Rego rules catch the same mistakes earlier, in the PR, as a *shift-left* control, and also cover things Org Policies can't express (mandatory labels, jurisdiction-aware residency, change-risk classification). Security Command Center finds anything that slipped through, which is the *detective* control.

The policies use OPA v1 syntax (`import rego.v1`) and need Conftest ≥ 0.50.
