# Threat model baseline

| Threat | Boundary | Baseline control |
| --- | --- | --- |
| Forged webhook | Ingress | Shared-secret verification before parsing; failures have zero side effects. |
| Prompt injection | Logs and RAG | Treat all external text as untrusted data; only typed, read-only tool ABI is available to analysis. |
| Unauthorized approver | Slack action | Allowlist Slack user IDs; bind approval to incident, digest, policy version and ten-minute TTL. |
| L4 autonomy | Policy | Deny unconditionally. The sole L3 action is simulator.stop-cpu-load after a valid approval. |

No production credentials or arbitrary command capability are part of this baseline.
