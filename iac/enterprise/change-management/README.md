# Change Management: Infrastructure as Code, the ITIL Way

Aldervane's ITIL process predates the cloud. Instead of bypassing it, the pipeline **automates the evidence the CAB already asks for**: what changes, risk, rollback, test results, approvals.

## Change types

| Type | Criteria (computed by `scripts/classify_change.sh`) | Approval | Window |
|---|---|---|---|
| **Standard** | Only creates/updates, no sensitive resource types, ≤ 20 resources | Pre-approved model; 2 peer reviewers in the PR | Any standard window |
| **Normal** | Any delete/replace, any sensitive type (KMS, perimeters, org policies, log sinks, databases), or > 20 resources | CAB (weekly) | Planned window, e.g. Saturday 01:00–05:00 UTC |
| **Emergency** | Production incident (Sev-1/2) | ECAB (on-call manager + security), retrospective CAB within 5 days | Immediate |

## End-to-end flow

```mermaid
sequenceDiagram
    autonumber
    actor Eng as Engineer
    participant Git as Git (PR)
    participant CB as Cloud Build (private pool)
    participant OPA as Conftest
    participant SN as ServiceNow
    participant CAB as CAB
    participant GCP as Google Cloud

    Eng->>Git: Open PR (links demand ID)
    Git->>CB: plan pipeline
    CB->>CB: fmt, validate, tech-debt register check
    CB->>CB: terraform plan, store plan by commit SHA
    CB->>OPA: conftest test plan.json
    OPA-->>CB: deny = 0, warn = n
    CB->>CB: classify risk → STANDARD / NORMAL
    CB->>SN: create change request (plan summary, risk, SHA)
    Git->>Git: CODEOWNERS review (separation of duties)
    alt NORMAL
        SN->>CAB: added to CAB agenda
        CAB-->>SN: approve + schedule window
    else STANDARD
        SN-->>SN: auto-approved (standard model)
    end
    Eng->>Git: merge
    Git->>CB: apply pipeline
    CB->>SN: verify approved + in window + SHA matches
    CB->>GCP: terraform apply <reviewed plan>
    CB->>SN: close with apply log (evidence)
```

## Why apply the *stored* plan?

Auditors ask: *"How do you know what was applied is what was approved?"* The apply pipeline downloads the plan file stored under the **approved commit SHA** and runs `terraform apply tfplan`. Terraform refuses to apply a stale plan if the state has changed since, so the plan that gets applied is exactly the plan that was approved.

## Drift detection

A nightly scheduled build runs `terraform plan -detailed-exitcode` on every root module. Exit code `2` (drift) opens an **incident** in ServiceNow. Unauthorised ClickOps changes count as security events, and the Cloud Audit Logs entry shows who made them.

## Rollback

- **Code rollback:** revert the PR, which goes through the same pipeline (usually a Standard change).
- **Data-bearing resources** (KMS keys, databases, log buckets) are protected by `prevent_destroy`, `deletion_protection` and `deletion_policy = "PREVENT"`. Rollback never destroys data.

## Files

| File | Purpose |
|---|---|
| `cloudbuild-plan.yaml` | PR pipeline |
| `cloudbuild-apply.yaml` | Merge pipeline with change gate |
| `scripts/classify_change.sh` | Plan → Standard/Normal |
| `scripts/servicenow_change.sh` | Draft / verify / close change requests |
| `scripts/check_tech_debt.sh` | Enforces the tech-debt register |
| `CODEOWNERS.example` | Separation of duties |
