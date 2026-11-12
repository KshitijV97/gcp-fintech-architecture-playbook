# Case 3 · Least Managed: "Google Is Our Data Centre"

> ⚖️ **Disclaimer:** educational material only. This is **not legal, regulatory, compliance or financial advice**. Regulations are paraphrased and simplified; organisations, people and incidents are fictional. Consult qualified counsel before you rely on any of it. [Full disclaimer](../../README.md#disclaimer)

> 🏦 **Protagonist: Aldervane Bank's Market Infrastructure division**, which runs payments clearing for 30 smaller banks. Their contracts with those client banks require **dedicated hardware isolation**, specific **certified software versions**, and **full control of the cryptographic stack**. Their national competent authority also demands detailed evidence about every layer of the platform.
>
> This case is deliberately extreme. It shows **what you take on** when you choose IaaS, and why most organisations shouldn't, but some must.

---

## 1. The story

Lukas, the division's chief architect, has a 120-page requirements document. Three lines drive everything:

- **REQ-ISO-04:** "Compute hosting client-bank data shall not share physical hosts with other tenants."
- **REQ-CRY-11:** "Encryption keys used for client data shall be generated and held in key management systems operated by the Division."
- **REQ-OPS-02:** "All software components shall be version-pinned and patched under the Division's change process."

Lukas's team concludes: *"We use Google Cloud as a programmable, global, highly secure data centre. Compute Engine, sole-tenant nodes, VPC, Cloud HSM as a root of trust, and nothing that hides the operating system from us."*

## 2. Architecture

```mermaid
flowchart LR
    subgraph CLIENTS["Client banks"]
        CB["30 client banks<br/>ISO 20022 messages"]
    end

    subgraph GCP["Google Cloud · europe-west3 · 3 zones"]
        direction LR
        subgraph PERIM["VPC-SC perimeter + Shared VPC"]
            direction LR
            subgraph EDGE["Edge tier: MIG"]
                ARMOR["Cloud Armor"]
                NLB["External passthrough<br/>Network LB"]
                ENVOY["Envoy proxies<br/>mTLS termination"]
            end
            subgraph APP["App tier: sole-tenant node group"]
                SCORE["scoring-svc<br/>Java on Rocky Linux<br/>regional MIG"]
                TRITON["NVIDIA Triton<br/>GPU VMs"]
            end
            subgraph DATA["Data tier: sole-tenant"]
                KAFKA["Apache Kafka 3.x<br/>KRaft, 6 brokers<br/>across 3 zones"]
                FLINK["Apache Flink<br/>JobManager HA +<br/>TaskManagers"]
                PG[("PostgreSQL 16<br/>Patroni + etcd<br/>3 nodes, sync replication")]
                REDIS[("Redis Sentinel<br/>3 nodes")]
                CH[("ClickHouse cluster<br/>analytics")]
            end
            subgraph SEC["Security tier"]
                VAULT["HashiCorp Vault<br/>Enterprise, Raft storage"]
                HSM["Cloud HSM<br/>Vault auto-unseal"]
                OS["OpenSearch + Wazuh<br/>SIEM"]
                BASTION["IAP TCP forwarding<br/>no bastion IPs"]
            end
            subgraph OPS["Ops tier"]
                AIRFLOW["Airflow on VMs"]
                MLFLOW["MLflow"]
                PROM["Prometheus +<br/>Grafana"]
                BACKUP[("Backup and DR vault<br/>+ pgBackRest to GCS")]
            end
        end
    end

    CB --> ARMOR --> NLB --> ENVOY --> SCORE
    SCORE <--> REDIS
    SCORE <--> TRITON
    SCORE --> PG
    SCORE --> KAFKA
    KAFKA --> FLINK --> REDIS
    FLINK --> CH
    AIRFLOW --> MLFLOW --> TRITON
    VAULT -->|"transit encryption,<br/>per-subject DEKs"| SCORE & FLINK
    HSM -.->|"root of trust"| VAULT
    PG --> BACKUP
```

### What "least managed" means in practice

```mermaid
flowchart TB
    subgraph G["Google still provides"]
        G1["Physical security, hardware, hypervisor"]
        G2["Sole-tenant hosts"]
        G3["VPC, load balancers, Cloud Armor"]
        G4["Cloud HSM: Vault's root of trust"]
        G5["Persistent Disk replication"]
        G6["Org Policies, VPC-SC, IAM, audit logs"]
    end
    subgraph L["Lukas's team owns"]
        L1["OS hardening: CIS Level 2 images built with Packer"]
        L2["Monthly patching for 200+ VMs"]
        L3["Kafka, Flink, Postgres, Redis, ClickHouse:<br/>install, upgrade, tune, HA, DR"]
        L4["Vault cluster operations"]
        L5["Monitoring stack, SIEM, log shipping"]
        L6["Backups, restore tests, DR failover"]
        L7["Capacity planning for every tier"]
    end
```

> 💡 Even "unmanaged" on GCP isn't truly unmanaged. **Org Policies, VPC-SC, IAM, Cloud Audit Logs and Cloud HSM** stay in place because they're free or cheap, and no self-built alternative is better.

## 3. Request flow

```mermaid
sequenceDiagram
    autonumber
    participant CB as Client Bank
    participant Env as Envoy (MIG)
    participant Svc as scoring-svc VM
    participant V as Vault
    participant R as Redis Sentinel
    participant T as Triton
    participant PG as Patroni leader
    participant K as Kafka

    CB->>Env: ISO 20022 pacs.008 (mTLS, client cert)
    Env->>Svc: HTTP/2 + JWT
    Svc->>V: transit/decrypt (cached DEK, 5-min TTL)
    V-->>Svc: plaintext customer token
    Svc->>R: GET features
    R-->>Svc: features
    Svc->>T: gRPC infer
    T-->>Svc: score
    Svc->>PG: INSERT decision (synchronous_commit = remote_apply)
    PG-->>Svc: ok
    Svc-->>Env: decision
    Env-->>CB: pacs.002 status (p99 ≈ 60 ms)
    Svc--)K: produce (acks=all, min.insync.replicas=2)
```

## 4. Component walkthrough

| Component | Implementation | Operational duties |
|---|---|---|
| Compute | Compute Engine C3/N2 on a **sole-tenant node group**, regional MIGs, Shielded VM, OS Login, **Confidential VMs** where supported | Golden image pipeline (Packer + CIS benchmarks), monthly patch cycle, MIG rolling updates |
| Edge | Cloud Armor → passthrough NLB → Envoy MIG | Envoy upgrades, certificate rotation (from Vault PKI) |
| Kafka | Apache Kafka (KRaft) on 6 VMs with Hyperdisk Balanced, rack-awareness = zone | Broker upgrades, partition rebalancing (Cruise Control), disk expansion |
| Stream processing | Apache Flink, checkpoints to GCS | Savepoints before upgrades, state migration |
| Ledger | PostgreSQL 16 + Patroni + etcd, synchronous replication across 3 zones; pgBackRest to GCS with Bucket Lock | Failover testing, vacuum tuning, PITR restore drills |
| Cache | Redis + Sentinel | Failover testing, memory sizing |
| Analytics | ClickHouse cluster | Shard and replica management, upgrades |
| ML | MLflow + Airflow + Triton on GPU VMs | Driver updates (NVIDIA), model rollout scripts |
| Keys | **HashiCorp Vault Enterprise** (Transit, Transform, PKI), auto-unseal with **Cloud HSM** | Vault upgrades, Raft snapshots, DR replication, unseal-key ceremony |
| SIEM | Wazuh agents + OpenSearch | Index lifecycle, cluster scaling, detection-rule authoring |
| Monitoring | Prometheus, Grafana, Alertmanager | Long-term storage (Thanos), alert tuning |

## 5. Implementing the erasure puzzle in Case 3

With full control comes full responsibility. **Vault Transit** holds a named key per customer cohort, plus per-customer DEKs stored wrapped in Postgres.

```mermaid
flowchart TD
    REQ(["Client bank forwards DSR for subject S"]) --> CHK{"Legal hold?"}
    CHK -->|"No"| DEL["Postgres: DELETE + VACUUM<br/>ClickHouse: ALTER TABLE DELETE<br/>Redis: DEL"]
    CHK -->|"Yes"| RES["Postgres: move to restricted schema<br/>separate role, row-level security"]
    DEL --> SHRED["Delete subject DEK row<br/>+ rotate Vault cohort key<br/>+ rewrap remaining DEKs"]
    RES --> SCHED["Airflow: schedule shred at hold expiry"]
    SHRED --> BK["Backups: pgBackRest retention 35 days,<br/>ciphertext unreadable without DEK"]
    BK --> LOGS["OpenSearch: delete-by-query on<br/>indices containing subject token"]
    LOGS --> EVID(["Evidence pack: SQL logs, Vault audit log,<br/>Airflow run IDs"])
    SCHED --> EVID
```

> ⚠️ **ClickHouse `ALTER TABLE ... DELETE` is an asynchronous mutation** that rewrites data parts. Your evidence has to show that the mutation *completed*, not only that it was submitted. Lightweight deletes mark rows and remove them on merge, which raises the same question.

> ⚠️ **Postgres `DELETE` does not remove data from disk immediately.** Dead tuples stay until `VACUUM`, and WAL archives keep the old values. That's why crypto-shredding matters even when you control everything.

## 6. Compliance mapping highlights

| Requirement | Case 3 approach | Who provides the evidence |
|---|---|---|
| Physical isolation | Sole-tenant nodes | Google (node affinity) + Lukas (placement config) |
| Key custody | Vault (operated by the division) with Cloud HSM as root of trust; or EKM to an on-prem HSM if Google-hosted HSM is unacceptable | **Lukas's team** |
| OS patching | Monthly cycle, OS Config / VM Manager patch reports | **Lukas's team** |
| Vulnerability scanning | VM Manager + Wazuh + SCC | **Lukas's team** |
| Logging | Cloud Audit Logs (Google layer) **plus** Wazuh/OpenSearch (OS and application layer) | Both |
| HA and DR | Self-built: Patroni, Kafka replication, Flink checkpoints, DR restore drills | **Lukas's team** |
| DORA exit | ✅ Excellent: everything is open source on generic Linux VMs | |
| DORA ICT risk | ⚠️ Huge surface: 200+ VMs and 9 stateful products to evidence | **Lukas's team** |

## 7. Operations: who gets paged?

| Event | Who handles it |
|---|---|
| Kernel CVE (e.g. a container escape) | **Lukas's team**: emergency CAB, rolling patch of 200 VMs |
| Zone failure | **Lukas's team**: Patroni fails over automatically if configured correctly; Kafka ISR shrinks; Flink restarts from checkpoint |
| Disk full on a Kafka broker | **Lukas's team** (3 a.m.) |
| Vault sealed after restart | Auto-unseal via Cloud HSM; **Lukas's team** if the HSM is unreachable |
| Hardware failure | Google live-migrates the VM (sole-tenant nodes support live migration under maintenance policies) |

**On-call footprint:** 3–4 specialist rotations (Linux, data platform, security, application). Expect **15–25 FTE** in total.

## 8. Cost shape

```mermaid
xychart-beta
    title "Indicative TCO split: infrastructure vs. people (Case 3)"
    x-axis ["Case 1 Managed", "Case 2 Semi", "Case 3 Least"]
    y-axis "Relative annual TCO" 0 --> 100
    bar [35, 45, 70]
    line [10, 22, 45]
```

*Bars show total relative TCO; the line shows the people/operations share.* Raw infrastructure can be **cheaper** in Case 3 (3-year CUDs, no managed-service premium), but **people costs dominate**. Sole-tenant nodes add a premium on top of VM pricing.

## 9. What can go wrong

| Failure mode | Real-world consequence | Mitigation |
|---|---|---|
| **Patch backlog** | Audit finding: "critical CVEs older than 30 days" | Immutable images, automated rolling MIG updates |
| **Split-brain in Patroni** | Two primaries, ledger divergence | etcd quorum across 3 zones, fencing, `synchronous_mode_strict` |
| **Untested restores** | Backups that cannot be restored | Monthly automated restore tests with evidence |
| **Key loss** | Permanent data loss | Vault DR replication, HSM-backed unseal, documented key ceremony |
| **Snowflake servers** | Configuration drift | Immutable infrastructure, no SSH by default (OS Login + IAP + break-glass only) |
| **Expertise attrition** | Bus factor of 1 for Kafka or Vault | Cross-training, vendor support contracts |

## 10. Key takeaways

- ✅ **Maximum control**: isolation, versions and key custody are all yours.
- ✅ **Maximum portability**: this design runs on any IaaS or on-prem.
- ❌ **Maximum toil and compliance burden.** Every layer above the hypervisor is yours to evidence.
- 💡 Choose this **only when a contract or regulation forces it**, and even then, keep using the cloud-native guardrails (Org Policies, VPC-SC, IAM, Cloud HSM, audit logs) that cost almost nothing.

➡️ Next: [Case 4 · Hybrid and multi-cloud](04-hybrid-multicloud.md)
