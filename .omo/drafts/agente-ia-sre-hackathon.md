---
slug: agente-ia-sre-hackathon
status: superseded
intent: unclear
review_required: true
plan_path: .omo/plans/agente-ia-sre-hackathon.md
plan_sha256: 849D25D35C0DB9010D245313EBBA12A107AED32256BA6B75A0196ED972306B8E
review_round_id: null
pending-action: none - superseded by agente-ia-sre-datadog (usuario aprobó heredar base y superseder el 2026-09-12; la revisión de alta precisión pendiente se abandona)
---

# Draft: agente-ia-sre-hackathon

## Components (topology ledger)
| id | outcome | status | evidence path |
| --- | --- | --- | --- |
| trigger-incident | Alerta normalizada y journal durable | active | Documento adjunto §2–3 |
| context-evidence | Contexto, evidencia viva y RAG citado | active | Documento adjunto §1–3 |
| cognitive-loop | Hipótesis falsificables y causalidad | active | Documento adjunto §3 |
| safety-action | Policy, aprobación y acción idempotente | active | Documento adjunto §4–5 |
| verification-close | Postcheck, escalamiento y postmortem | active | Documento adjunto §3 y §6 |

## Open assumptions (announced defaults)
| assumption | adopted default | rationale | reversible? |
| --- | --- | --- | --- |
| Entorno | Gemelo digital `payment-gateway` sin producción | Seguridad y repetibilidad | Sí |
| Datos | PostgreSQL + pgvector | Una sola plataforma de datos | Sí |
| Política | OPA | Menor complejidad que OPA + Cedar | Sí |
| Tooling | MCP allowlisted, read-only para investigación | Sin ejecución arbitraria | No |
| Autonomía | L4 sólo en sandbox/acciones allowlisted | Límite de seguridad | No |
| Paralelismo | Preflight + tres ramas propietarias + integración | Evita conflictos | Sí |

## Findings (cited - path:lines)
- `README.md:1`: repositorio sin producto, infraestructura ni pruebas existentes.
- Documento adjunto §1–6: cinco capas, loop de investigación, matriz gradual, seguridad, roadmap y postmortem.
- https://kubernetes.io/docs/concepts/security/rbac-good-practices/ respalda mínimo privilegio.
- https://modelcontextprotocol.io/specification/2025-11-25/server/tools establece una frontera de tools validada.
- https://opentelemetry.io/docs/specs/semconv/general/events/ respalda el journal/auditoría de eventos.

## Decisions (with rationale)
- Vertical slice end-to-end con todos los contratos, no un panel de monitorización.
- Evidencia viva confirma hipótesis; RAG sólo contextualiza.
- Toda mutación se vincula a digest, TTL, identidad, policy, precondiciones e idempotencia.
- Tres streams Git trabajan en rutas exclusivas desde el mismo SHA de contratos.

## Scope IN
- Flujo completo alerta→investigación→política/aprobación→mitigación→verificación→postmortem en sandbox.
- Cuatro niveles de autonomía como contrato visible y acciones L4 allowlisted.
- QA automatizada, E2E y artefactos de auditoría.

## Scope OUT (Must NOT have)
- Producción, credenciales reales, tool write directa al modelo, shell arbitrario o autonomía general.

## Open questions
- Ninguna bloqueante; el usuario aprobó el enfoque y pidió tres sesiones en paralelo.

## Approval gate
status: superseded (2026-09-12 por agente-ia-sre-datadog: hereda la base — contratos, stack, arquitectura; fuente Zabbix real + Datadog pluggable; sin entregables hackathon)
Approach original: ThreadSRE usa Slack, OpenAI y CopilotKit Channels; incluye rúbrica/entregables sin publicación ni fecha asumida.
