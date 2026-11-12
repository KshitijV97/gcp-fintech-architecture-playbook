# 06 · IaC for the Startup: Quillpay

> ⚖️ **Disclaimer:** educational material only. This is **not legal, regulatory, compliance or financial advice**. Regulations are paraphrased and simplified; organisations, people and incidents are fictional. Consult qualified counsel before you rely on any of it. [Full disclaimer](../../README.md#disclaimer)

> **Story hook:** Daniel (Quillpay's CTO) has a rule: *"Compliance work we do once, in code, is an investment. Compliance work we do every quarter by hand is a tax."* Quillpay has no CAB and no ARB, just 60 engineers, GitHub, and a Series B due-diligence checklist that includes SOC 2 Type II, ISO 27001, GDPR and, now that it's expanding, PIPEDA.

Code: [`iac/startup/`](../../iac/startup/)

## 1. Principles

1. **Paved road, not gates.** One module (`platform`) produces a compliant jurisdiction cell. Engineers get compliance by using it.
2. **Keyless from day one.** GitHub → Workload Identity Federation → a short-lived token. There are no JSON keys to leak.
3. **Guardrails at the org, checks in the PR.** Seven org policies + one Rego file cover most of the risk.
4. **Cells, not conditionals.** EU and Canada are two instances of the same module with different parameters.
5. **Evidence by default.** Privacy registers are created with the platform, not added later.

## 2. Layout and flow

```mermaid
flowchart LR
    subgraph Once["Run once: founder laptop"]
        BOOT["bootstrap/<br/>folders, org policies,<br/>state bucket, WIF"]
    end
    subgraph Repo["GitHub repo"]
        MOD["modules/platform"]
        STG["envs/staging"]
        EU["envs/prod-eu"]
        CA["envs/prod-ca"]
        POL["policies/guardrails.rego"]
    end
    subgraph CI["GitHub Actions"]
        PLAN["PR: plan × 3 envs<br/>+ conftest"]
        APPLY["main: apply staging →<br/>approval → prod-eu → prod-ca"]
    end
    BOOT -->|"outputs: WIF provider, SA"| CI
    MOD --> STG & EU & CA
    Repo --> PLAN --> APPLY
```

## 3. What one `platform` cell contains

```mermaid
flowchart TB
    subgraph Cell["module platform: one jurisdiction cell"]
        subgraph KMSP["qp-ENV-JUR-kms project"]
            KEY["key-data<br/>HSM in prod, 90-day rotation"]
        end
        subgraph APP["qp-ENV-JUR-app project"]
            RUN["Cloud Run: scoring<br/>internal LB ingress, CMEK"]
            SQL[("Cloud SQL Postgres 16<br/>private IP, HA, PITR, IAM auth")]
            PS["Pub/Sub ×3<br/>in-region storage policy"]
            BQA[("BigQuery analytics<br/>13-month expiry")]
            BQP[("BigQuery privacy<br/>consent · disclosure · breach · DSR")]
            ARC[("GCS archive<br/>object retention / legal hold")]
            BRC[("GCS breach-records<br/>locked ≥ 24 months")]
            AR["Artifact Registry"]
            SM["Secret Manager<br/>in-region replica"]
        end
    end
    KEY -.-> RUN & SQL & PS & BQA & BQP & ARC & BRC & AR & SM
    RUN --> SQL
    RUN --> PS
```

## 4. Growth path: compliance that scales with the company

```mermaid
timeline
    title Quillpay compliance and architecture roadmap
    Seed : One project per env : Cloud Run + Cloud SQL : 7 org policies : Keyless CI
    Series A : platform module : CMEK everywhere : Privacy registers : SOC 2 Type I
    Series B : EU + CA cells : Assured Workloads : Dataplex + SDP : SOC 2 Type II, ISO 27001
    Series C : Spanner for ledger : VPC-SC enforced : EKM for enterprise clients : DORA third-party register
    Scale-up : Adopt enterprise patterns selectively : CAB-lite for sensitive changes : Multi-cloud exit test
```

### Cloud SQL → Spanner (when?)

| Signal | Threshold |
|---|---|
| Write throughput on the ledger | > ~5–10k writes/s sustained |
| Availability target | 99.99%+ with RPO = 0 across regions |
| Operational pain | Manual sharding discussions start |

Migration: Spanner's **PostgreSQL dialect** keeps most SQL and drivers. Database Migration Service or Datastream + Dataflow handle the backfill, followed by a dual-write cutover.

## 5. Mapping startup controls to certifications

| Startup control | SOC 2 | ISO 27001:2022 Annex A | GDPR | PIPEDA |
|---|---|---|---|---|
| Keyless CI (WIF) | CC6.1 | 5.17, 8.5 | 32 | 4.7 |
| GitHub environment approvals | CC8.1 | 8.32 | 32 | 4.7 |
| Org policies: residency | CC6.1 | 5.34 | 44 | 4.1.3 |
| CMEK + HSM | CC6.1, CC6.7 | 8.24 | 32 | 4.7 |
| Privacy registers | P-series | 5.34 | 7, 12, 15, 33(5) | 4.3, 4.9, 4.10, s.10.3 |
| Budgets + alerts | (A1) | 5.9 | n/a | n/a |
| Locked breach records | CC7.4 | 5.25–5.27 | 33(5) | s.10.3 |

## 6. What Quillpay deliberately does *not* do (yet)

| Enterprise feature | Why not yet | Trigger to adopt |
|---|---|---|
| CAB + ServiceNow | Two-reviewer PRs + environment approvals give SOC 2-grade change evidence | First bank or enterprise client that contractually requires ITIL change records |
| Shared VPC hub | One VPC per cell is simpler | > 5 workloads per cell |
| Demand management | The founders *are* the portfolio board | > 150 engineers or multiple business lines |
| `gcp.restrictServiceUsage` allow-list | Slows experimentation | First regulator inspection |
| VPC-SC enforced | Adds friction to dev tooling | Series C / handling card data (PCI DSS) |

➡️ Next: [08 · Data Governance](../08-data-governance.md)
