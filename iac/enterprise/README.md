# Aldervane Bank: Enterprise IaC Blueprint

Compliance-first Terraform with change management, demand management and technical-debt governance built in. Narrative walkthrough: [docs/iac/05-enterprise-iac.md](../../docs/iac/05-enterprise-iac.md).

```text
enterprise/
├── landing-zone/            # Stage 1: folders, org policies, Assured Workloads (EU + CA),
│   ├── main.tf              #   audit logging, KMS projects, network hub
│   └── tech-debt.tf         #   every guardrail exception, with TD markers
├── modules/
│   ├── org-policies/        # preventive guardrails
│   ├── project-factory/     # mandatory labels incl. demand_id, budgets, contacts
│   ├── cmek/                # key rings and keys, crypto-shred delay
│   ├── audit-logging/       # locked log bucket + WORM archive + data-access logs
│   ├── vpc-sc-perimeter/    # dry-run → enforce
│   ├── shared-vpc/          # restricted VIP, no internet route
│   └── data-governance/     # Dataplex aspects, policy tags, masking, SDP discovery
├── workloads/sentinel/      # Case 2 on GKE + AlloyDB + Managed Kafka
│   └── envs/{dev,prod}/
├── policies/                # OPA/Conftest: residency, security baseline, change risk
├── change-management/       # Cloud Build plan/apply, ServiceNow gate, CODEOWNERS
├── demand-management/       # intake template, worked demands, service allow-list
└── TECH_DEBT.md             # register enforced by CI
```

Providers: `hashicorp/google` and `google-beta` `~> 8.11`, Terraform ≥ 1.9.
