---
slug: agente-ia-sre-datadog
status: plan-complete
intent: clear
review_required: false
pending-action: handoff entregado; el usuario decide entre $start-work agente-ia-sre-datadog o la revisión de alta precisión opcional (CLEAR, review_required: false)
approach: Slice vertical L1→L3 del agente AI SRE sobre fuente de telemetría REAL: alerta CPU de Zabbix 7.4 (harness existente del usuario: zabbix-cpu-simulator + stress-ng, README.md:1-46) — investigación con evidencia viva vía API JSON-RPC de Zabbix, decisión y propuesta del agente como núcleo, remediación L3 aprobada por humano (única acción allowlisted: detener la carga stress-ng), postcheck de recuperación observable y postmortem desde journal. Datadog como segundo adaptador pluggable: fixtures shaped con contract tests + cliente real @datadog/datadog-api-client env-gated (sin creds aún). Hereda base ThreadSRE: contratos IncidentEnvelope, Node 22 + TS + pnpm, Temporal, Postgres/pgvector, OPA, MCP read-only, broker idempotente. Slack Bolt harness offline + live env-gated. L4 solo guardrail. Preservar intactos los archivos del harness Zabbix del usuario. Scaffold replicado a mano byte-fiel porque esta sesión no dispone de herramienta shell.
---

# Draft: agente-ia-sre-datadog

## Components (topology ledger)
<!-- Lock the SHAPE before depth. One row per top-level component that can succeed or fail independently. -->
<!-- id | outcome (one line) | status: active|deferred | evidence path -->
| telemetry-trigger | Alerta Zabbix real (webhook del media type) autenticada con secreto compartido, deduplicada, normalizada a IncidentEnvelope y journal durable; normalizador Datadog-shaped con contract tests | active | README.md:28-38; .omo/plans/agente-ia-sre-hackathon.md:84-90; fix Metis #6 |
| telemetry-collector | Interfaz TelemetrySource con dos adaptadores: Zabbix real (API JSON-RPC: problems, items, history) y Datadog (SDK real env-gated + fixtures shaped + parity tests), expuestos como tools MCP read-only | active | Doc Gemini §2 capa 3, §3 paso 3; README.md:38; fixes Metis #5/#9 |
| context-topology | Catálogo de hosts/servicios del escenario + RAG semilla versionado (runbooks/postmortems fixtures) como contexto citado, sin realimentar postmortems generados | active | Doc Gemini §2 capa 2; fix Metis #10 |
| cognitive-loop | Motor de hipótesis falsables (2-3) con prueba falsadora sobre evidencia viva Zabbix, síntesis causal + blast radius, decisión y propuesta de la única acción allowlisted o needs_human | active | Doc Gemini §3 pasos 3-4; fixes Metis #11 |
| slack-surface | Bot Bolt con tarjeta de incidente, evidencia citada y aprobación interactiva L3 con identidad→rol allowlist validada por OPA | active | Doc Gemini §4 nivel 3; fix Metis #7 |
| safety-action | Policy OPA + broker idempotente ejecutando la única acción L3 allowlisted (detener carga stress-ng) + postcheck de recuperación CPU + borrador de postmortem desde journal | active | Doc Gemini §4, §3 pasos 5-6; README.md:40-44; fix Metis #8 |

## Open assumptions (announced defaults)
<!-- Record any default you adopt instead of asking, so the user can veto it at the gate. -->
<!-- assumption | adopted default | rationale | reversible? -->
| Estrategia de pruebas | TDD para contratos/policy/broker + tests-after para tarjetas Slack; QA agent-ejecutada siempre, evidencia en .omo/evidence/ | Hereda la decisión ya aprobada en ThreadSRE | Sí |
| Proveedor LLM | Adaptador pluggable: provider fixture para tests/demo offline + provider real configurable por env; claves nunca versionadas ni persistidas | Reproducibilidad offline + zero-retention | Sí |
| Superficie de interacción | Slack nativo (Bolt SDK) para tarjeta de incidente y aprobaciones L3; reemplaza CopilotKit Channels (constraint de sponsor hackathon) | Doc de diseño §4 apunta a Slack/Teams | Sí |
| Autonomía L4 | No habilitada en ejecución: solo guardrails y catálogo documentado | Postura de seguridad del doc (Q4 roadmap) y del plan previo | Sí |
| Frontera de tools | Solo tools MCP read-only para investigación; toda mutación pasa por el action broker con policy | Evitar shell/escritura directa del modelo | No |

## Findings (cited - path:lines)
- CORREGIDO (2026-09-12, hallazgo #1 de Metis verificado por lectura directa): al inicio de la sesión `README.md` era "# intellias" (1 línea) y el repo estaba verde; AHORA `README.md:1-46` documenta un harness Zabbix real ("Zabbix CPU simulation... carga reproducible para probar un agente SRE frente a una alerta de CPU alta"): stack Zabbix 7.4 existente + contenedor `zabbix-cpu-simulator` (Zabbix Agent 2 + stress-ng), métrica `system.cpu.util` con triggers de plantilla estándar, `scripts/provision-zabbix-cpu.sh`, `scripts/set-cpu-load.sh`, `docker-compose.cpu-simulation.yml`, web UI 127.0.0.1:8080. Trabajo del usuario creado EN PARALELO durante esta sesión de planificación.
- Dirty worktree: `cpu-simulator/`, `scripts/provision-zabbix-cpu.sh`, `scripts/set-cpu-load.sh`, `docker-compose.cpu-simulation.yml`, `README.md` son trabajo vivo del usuario — el plan debe preservarlos intactos, jamás sobrescribirlos ni moverlos.
- `.omo/plans/agente-ia-sre-hackathon.md:1-217`: plan ThreadSRE aprobado, 13 todos + F1-F4, telemetría SIMULADA (gemelo digital, sin Datadog real), orientado a hackathon (CopilotKit Channels, rúbrica, submission).
- `.omo/drafts/agente-ia-sre-hackathon.md:1-59`: estado previo `review-in-progress`; revisión de alta precisión PENDIENTE; decisiones previas: Node 22 + TS + pnpm, Temporal, Postgres/pgvector, OPA, MCP read-only.
- `.git/refs/heads` + `.git/packed-refs`: solo ramas `develop` y `main`; ninguna rama `codex/*` → el plan anterior nunca se ejecutó.
- `C:/Users/danie/Downloads/hackathon-overview.md`, `hackathon-rules.md`: contexto hackathon aún presente (using-sponsor-tools.md ya no está).
- Mensaje del usuario (doc Gemini) §1-6: perfil SRE L2, cinco capas, bucle cognitivo (6 pasos), matriz L1-L4, arquitectura de referencia (Temporal, MCP, pgvector/Qdrant, OPA), roadmap 12 meses.
- Investigación externa COMPLETADA (librarian bg_72e8c45b, ses_f68fedfe9ffen9yCY6wcA0PMAb, 2026-09-12; fuentes: docs.datadoghq.com, github.com/DataDog + datadog-labs, registry.modelcontextprotocol.io). Hechos load-bearing:
  - SDK real: `@datadog/datadog-api-client` (npm v1.63.0, activamente mantenido; config env DD_SITE/DD_API_KEY/DD_APP_KEY, helpers WithPagination). https://docs.datadoghq.com/api/latest/
  - Endpoints del investigador: GET /api/v1/query (from/to epoch-segundos) y POST /api/v2/query/timeseries (from epoch-ms, ≤10k buckets group-by); POST /api/v2/logs/events/search (page.limit máx 1000, cursor page.cursor ← meta.page.after); GET/POST /api/v2/events y /api/v2/events/search; GET /api/v2/trace/{trace_id} (preview — NO existe REST público de búsqueda de spans; span search solo vía MCP oficial); GET /api/v1/monitor, /{monitor_id}, /search; GET /api/v1/validate. https://docs.datadoghq.com/api/latest/{metrics,logs,events,apm-trace,monitors}.md
  - Auth: headers DD-API-KEY + DD-APPLICATION-KEY; application keys con permisos RBAC granulares (timeseries_query, logs_read_data, events_read, monitors_read); base URL por sitio (DD_SITE). https://docs.datadoghq.com/api/latest/authentication/ + /scopes.md
  - Rate limits: sin tabla numérica pública — descubiertos vía headers X-RateLimit-*; 429 + backoff; envío de eventos 250k/min/org. https://docs.datadoghq.com/api/latest/rate-limits.md
  - Webhook de monitores: integración Webhooks (@webhook-<NOMBRE> en el mensaje del monitor); payload JSON personalizable con variables documentadas ($ALERT_ID, $ALERT_TRANSITION, $EVENT_TITLE, $EVENT_MSG, $TAGS, $ALERT_QUERY, $ALERT_SCOPE, $DATE, $ID, $LINK, $ORG_ID, $EVENT_TYPE...); custom headers + variables ocultas (patrón shared-secret); SIN firma HMAC documentada; timeout 15s con 5 reintentos ante 5xx → el gateway DEBE deduplicar; configurable vía POST /api/v1/integration/webhooks/configuration/webhooks. https://docs.datadoghq.com/integrations/webhooks.md
  - MCP oficial Datadog: servidor remoto https://mcp.datadoghq.com/v1/mcp (GA 2026-03-09; toolsets=core,apm; OAuth o headers DD_API_KEY/DD_APPLICATION_KEY; repo github.com/datadog-labs/mcp-server, Python, MIT). Tools relevantes: search_datadog_logs, get_datadog_metric, get_datadog_trace, search_datadog_spans, search_datadog_monitors, search_datadog_events, search_datadog_incidents. https://docs.datadoghq.com/mcp_server/{setup,tools}.md
  - Retención/paginación: métricas 15 meses (1s y luego agregación, ~300 puntos/query); eventos 15 meses; spans indexados 15-30 días; logs por índice/plan; logs v2 paginación cursor máx 1000/página. https://docs.datadoghq.com/data_security/data_retention_periods.md + /logs/guide/collect-multiple-logs-with-pagination.md
  - UNVERIFIED (dejar así en el plan): keys exactos del payload webhook POR DEFECTO (solo visibles en el UI tile — se mitiga definiendo un payload custom con las variables documentadas), firma HMAC (no hay opción documentada), REST span search público, tabla numérica de rate limits, "logs 15 días por defecto".
- Metis (bg_8d1dd5b7, ses_f68f5e93affeR7ID6oAdz6CCq9, 2026-09-12, 2m07s) completó el análisis de brechas: 12 hallazgos (contradicción ×3, supuesto-no-validado ×4, constraint faltante ×2, acceptance faltante ×2, scope-creep ×1); el #1 (README Zabbix) verificado como cierto; los demás citan líneas del plan hackathon consistentes con la lectura propia previa. Fixes que se pliegan al plan sin preguntar: schema `.env.example` con DD_* y sin claves Channels; test de webhook forjado/sin secreto compartido en la suite adversarial + verificación de secreto en el gateway; mapeo identidad Slack→rol allowlist para aprobaciones L3 validado por OPA; valor TTL concreto + test de expiración con reloj lógico Y ventana real; enumeración exacta del set de tools MCP por fuente; corpus RAG semilla versionado fijo, sin realimentar postmortems generados; motor de decisión acotado a proponer la única acción allowlisted o needs_human (anti scope-creep); criterio de round-trip IncidentEnvelope↔payload de webhook en Wave 0; parity tests (misma suite contra simulador y cassettes grabados del formato real).

## Decisions (with rationale)
- Q4 resuelta (2026-09-12, usuario eligió opción recomendada): fuente del slice = Zabbix real (harness existente) + Datadog pluggable shaped/env-gated; acción L3 única = detener la carga stress-ng del contenedor zabbix-cpu-simulator (reversible: re-aplicable con scripts/set-cpu-load.sh; recuperación observable vía history de system.cpu.util). El rollback GitOps/escenario payment-gateway queda FUERA de este slice (futuro narrative Datadog).
- Interfaz TelemetrySource pluggable (ZabbixAdapter real + DatadogAdapter env-gated) materializa el frente #1 del doc de Gemini (inteligencia cross-stack agnóstica) y honra el "datadog por ejemplo" del pedido original.
- Correlación git/deploy (frente #2 del doc) diferida: no aplica a la narrativa CPU; queda como Must-NOT de este slice.
- Los archivos del harness Zabbix (README.md, cpu-simulator/, scripts/provision-zabbix-cpu.sh, scripts/set-cpu-load.sh, docker-compose.cpu-simulation.yml) se preservan intactos: el monorepo del agente se estructura a su lado (apps/ + packages/), sin moverlos ni sobrescribirlos; el aprovisionamiento del webhook/media type Zabbix se hace con un script NUEVO.
- Datadog es la fuente de telemetría, NO el núcleo: rol de "analista" que reporta; el agente razona, diagnostica, toma decisiones y propone la solución (aclaración explícita del usuario al responder Q1).
- Heredar la base aprobada de ThreadSRE: arquitectura 5 capas, contratos (IncidentEnvelope, Hypothesis, Evidence, ActionPlan, Approval, JournalEvent), stack Node 22 + TS + pnpm, Temporal, Postgres/pgvector, OPA, MCP read-only (respuesta del usuario a Q1).
- Sin acceso Datadog: adaptador Datadog con fixtures shaped (formatos webhook custom + API v2 según ficha librarian verificada) + cliente real @datadog/datadog-api-client detrás de DD_API_KEY/DD_APP_KEY/DATADOG_MODE env vars (respuesta a Q2).
- Alcance: slice vertical L1→L3 completo (alerta → investigación → Slack → remediación L3 aprobada → postcheck → postmortem); L4 queda como guardrail documentado, no habilitado (respuesta a Q3).
- Tras aprobación, el plan hackathon ThreadSRE quedó superseded (2026-09-12; archivo conservado como referencia).

## Scope IN
- Flujo completo sobre la alerta CPU real de Zabbix: webhook autenticado → investigación con hipótesis falsables y evidencia viva (API Zabbix) → decisión y propuesta del agente → tarjeta Slack con evidencia citada → aprobación L3 humana digest-bound → única acción allowlisted (detener carga stress-ng vía broker) → postcheck de recuperación CPU → borrador de postmortem desde journal.
- Interfaz TelemetrySource pluggable: adaptador Zabbix real + adaptador Datadog (fixtures shaped con contract tests + cliente real env-gated, parity tests).
- Contratos normalizados (IncidentEnvelope round-trip Zabbix + Datadog), journal durable, tools MCP read-only, RAG semilla versionado, suite adversarial (incl. webhook forjado), demo reproducible que preserva el harness del usuario.

## Scope OUT (Must NOT have)
- Producción no delimitada, secretos versionados, shell/kubectl arbitrario para el LLM, autonomía L4 habilitada, segunda superficie web/móvil, confirmar causas sin evidencia viva.
- Correlación git/deploy y rollback GitOps (narrativa payment-gateway diferida), más de una acción L3, realimentar RAG con postmortems generados, modificar/mover los archivos del harness Zabbix del usuario.

## Open questions
- Ninguna bloqueante. Q4 resuelta (Zabbix real + Datadog pluggable). Pendiente solo la research wave de API/webhook Zabbix 7.4 (librarian en vuelo) para las referencias exactas del adaptador real.
- Vetables (silencio = default adoptado): TDD contratos/policy/broker + tests-after Slack; LLM pluggable (fixture + OpenAI primer ejemplo real); Slack Bolt harness offline + live env-gated; adaptador Temporal + fixture local persistido; L4 no habilitado; tools MCP read-only; aprovisionamiento del webhook Zabbix vía script nuevo sin tocar los scripts del usuario; Approval TTL = 10 min.

## Approval gate
status: plan-complete (plan escrito y self-check estructural en verde: 12 todos column-zero + F1-F4, headers en orden del template, TL;DR primero, matriz consistente)
Approach: slice L1→L3 sobre alerta CPU Zabbix real (harness del usuario, preservado intacto) con Datadog como adaptador pluggable shaped/env-gated; hereda base ThreadSRE; Slack Bolt; L4 guardrail (deny); 12 fixes Metis plegados; única acción L3 = detener carga stress-ng; investigación con evidencia viva vía API JSON-RPC Zabbix (URLs oficiales verificadas 2026-09-12). Next: usuario decide — $start-work agente-ia-sre-datadog [--worktree <ruta> | --make-pr | --ship] o revisión de alta precisión opcional (momus + oracle).
<!-- When exploration is exhausted and unknowns are answered, set status: awaiting-approval. -->
<!-- That durable record is the loop guard: on a later turn read it and resume at the gate instead of re-running exploration. -->
