# agente-ia-sre-datadog - Work Plan

## TL;DR (For humans)
<!-- Fill this LAST, after the detailed plan below is written, so it summarizes the REAL plan. -->
<!-- Plain English for a non-engineer: NO file paths, NO todo numbers, NO wave/agent/tool names. -->

**What you'll get:** Un agente SRE que recibe la alerta real de CPU alta de tu simulador Zabbix, la valida consultando la API de Zabbix, plantea hipótesis y las pone a prueba con evidencia, diagnostica la causa, decide y propone la solución (detener la carga), pide tu aprobación por Slack, la ejecuta de forma segura y verificable, comprueba que la CPU se recupera y redacta el informe del incidente. Datadog queda integrado como segunda fuente de datos, lista para activarse con credenciales sin cambiar código.

**Why this approach:** Tu harness Zabbix ya existe y produce alertas reales hoy — el agente se construye y demuestra sobre evidencia viva, no simulada; y el núcleo del producto es el razonamiento (hipótesis → decisión → propuesta), con toda acción ejecutable acotada a UNA acción reversible aprobada por un humano.

**What it will NOT do:** No toca producción ni ejecuta comandos arbitrarios sugeridos por el modelo; no habilita autonomía total (nivel 4); no modifica tu harness Zabbix ni tus scripts; no requiere credenciales de Datadog o Slack para desarrollar y probar.

**Effort:** XL
**Risk:** High - integra razonamiento LLM, herramientas, estado durable y una frontera de seguridad; se controla con contratos congelados, fixtures, suite adversarial y aprobación digest-bound.
**Decisions to sanity-check:** Única acción L3 = detener la carga stress-ng (no reiniciar el contenedor); aprobación con TTL de 10 minutos por allowlist de usuarios Slack; Datadog sólo se activa con variables de entorno; pruebas TDD en contratos/policy/broker.

Your next move: di "start" para ejecutar el plan (vía $start-work), o pide primero la revisión de alta precisión. Full execution detail follows below.

---

> TL;DR (machine): XL, High - agente SRE L1→L3 sobre alerta CPU Zabbix real (harness del usuario) con TelemetrySource pluggable (Zabbix real + Datadog env-gated), hipótesis falsables, Slack Bolt con aprobación L3 digest-bound, postcheck/postmortem y suite adversarial; 12 todos + F1-F4.

## Scope
### Must have
- Las cinco capas del doc de diseño sobre fuente REAL: trigger (webhook Zabbix autenticado con secreto compartido + normalizador Datadog shaped con contract tests), contexto (catálogo del escenario + RAG citado), tooling (interfaz TelemetrySource: ZabbixAdapter real vía API JSON-RPC + DatadogAdapter fixture/real env-gated, expuestos como tools MCP read-only), bucle cognitivo (2-3 hipótesis falsables con prueba falsadora, síntesis causal, decisión y propuesta acotada), safety/action (OPA + broker idempotente + aprobación L3 digest-bound + postcheck + postmortem).
- Caso versionado: alerta CPU real del host `zabbix-cpu-simulator` (carga stress-ng, item `system.cpu.util`, trigger de plantilla estándar) sobre el stack Zabbix 7.4 existente del usuario.
- Interfaz Slack Bolt: incident_card con evidencia citada por origen (tool|rag), badge SANDBOX y aprobación interactiva L3 con allowlist de approvers (SLACK_APPROVERS).
- Única acción L3 allowlisted: `simulator.stop-cpu-load` (docker exec pkill stress-ng, ejecutada solo por el broker), reversible (re-aplicable con scripts/set-cpu-load.sh) y con recuperación observable vía history.
- Contratos congelados (IncidentEnvelope con round-trip Zabbix+Datadog, ActionPlan con digest SHA-256, Approval con TTL 10 min), journal durable e idempotencia de webhooks (reintentos de Zabbix/Datadog).
- Suite adversarial (webhook forjado, prompt injection, duplicados, expiraciones, outage) y demo reproducible offline + live opcional; harness Zabbix del usuario preservado intacto.

### Must NOT have (guardrails, anti-slop, scope boundaries)
- Producción, secretos versionados, shell/kubectl arbitrario para el LLM, autonomía L4 habilitada (OPA siempre deny), segunda superficie web/móvil, confirmar causas desde RAG/logs no verificados.
- Más de una acción L3 (sin restart de contenedor, sin escalado, sin GitOps), correlación git/deploy (diferida a la narrativa Datadog futura), realimentar RAG con postmortems generados.
- Dos motores de política, dos bases vectoriales, despliegue GPU/vLLM local, dos bots completos.
- Modificar, mover o renombrar los archivos del usuario: README.md, docker-compose.cpu-simulation.yml, cpu-simulator/**, scripts/provision-zabbix-cpu.sh, scripts/set-cpu-load.sh.
- Requerir credenciales reales (Datadog/Slack) para desarrollo, CI o demo offline.

## Verification strategy
> Zero human intervention - all verification is agent-executed.
- Test decision: TDD para contratos, policy OPA, broker y normalizadores de webhook; tests-after para tarjetas Slack (Block Kit) y docs de demo. Framework: Vitest + Testcontainers (Postgres 16) + `opa eval` + cliente MCP de pruebas + harness Bolt (mock del Web API).
- Evidence: .omo/evidence/task-<N>-agente-ia-sre-datadog.{json,log,png} (fuera de ulw-loop: .omo/evidence/).
- Comando final: `pnpm lint && pnpm typecheck && pnpm test && pnpm test:e2e && pnpm demo:verify`.
- Recuperación: postcheck acepta ventana real de 5 min; los fixtures usan reloj lógico y lo declaran en journal/evidencia (fix Metis #8).

## Execution strategy
### Parallel execution waves
> Target 5-8 todos per wave. Fewer than 3 (except the final) means under-split.

- **Wave 0 — contratos congelados:** `codex/sre-foundation` crea y fusiona a `develop` el monorepo + contratos + fixtures + corpus + migración baseline + ownership-manifest + audit script + threat model baseline, y registra el SHA del contrato. Ninguna funcionalidad antes de ese SHA. Toda migración posterior vive exclusivamente en `infra/postgres/migrations/0002_*.sql` bajo Sesión A.
- **Wave 1 — tres sesiones simultáneas** desde el SHA del contrato, cada una con worktree y rama propia, PR atómico a `develop`, sólo rutas propietarias:
  - **Sesión A / `codex/sre-core`:** `apps/api/src/core/**`, `packages/telemetry/**`, `infra/workflows/**`, `infra/postgres/migrations/0002_*.sql`.
  - **Sesión B / `codex/sre-intelligence`:** `packages/zabbix/**`, `packages/datadog/**`, `packages/tools/**`, `packages/analysis/**`.
  - **Sesión C / `codex/sre-slack-safety`:** `packages/policy/**`, `packages/action-broker/**`, `apps/channel/**`, `infra/opa/**`, `docs/security/**`.
- **Wave 2 — integración:** `codex/sre-integration` desde `develop` actualizado posee `e2e/**`, `scripts/sre-agent/**` (demo/provision), `compose.yaml`, `docs/**`. Nunca reescribe internals de los tres PRs salvo corrección mínima de interfaz documentada.
- Cada PR declara el SHA del contrato; las ramas no se fusionan entre sí: fusión secuencial a `develop` (foundation → core → intelligence → slack-safety → integration). El ownership-manifest falla ante solapamiento, archivo sin dueño, SHA contractual distinto o cualquier path del usuario asignado a una sesión.

### Dependency matrix
| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | Ninguno | 2-9 | Ninguno |
| 2 | 1 | 10 | 3-4, 5-9 |
| 3 | 1 | 10 | 2, 4-9 |
| 4 | 1 | 10 | 2-3, 5-9 |
| 5 | 1 | 6, 10 | 2-4, 7-9 |
| 6 | 1, 5 | 10 | 2-5, 7-9 |
| 7 | 1 | 9, 10 | 2-6, 8 |
| 8 | 1 | 10 | 2-7, 9 |
| 9 | 1, 7 | 10 | 2-8 |
| 10 | 2-9 | 11-12 | Ninguno |
| 11 | 2-10 | F1-F4 | 12 |
| 12 | 2-10 | F1-F4 | 11 |
| F1-F4 | 10-12 | — | entre sí |

## Todos
> Implementation + Test = ONE todo. Never separate.
<!-- APPEND TASK BATCHES BELOW THIS LINE WITH edit/apply_patch - never rewrite the headers above. -->
- [ ] 1. Congelar monorepo, contratos, corpus y fixtures inter-sesión
  What to do / Must NOT do: Crear monorepo Node 22 + pnpm (`.tool-versions` fijando node 22.x, pnpm, Docker, Postgres 16, OPA 1.x); `packages/contracts/**` con JSON Schema + tipos TS para `IncidentEnvelope` (source: zabbix|datadog, alertId, monitorRef, severity normalizada 1-5, host/scope, tags, startedAt, dedupKey=sha256(source+alertId+scope)), `Hypothesis` (statement, confidence, requiredEvidence[], falsifier, status: confirmed|refuted|inconclusive), `Evidence` (trust, provenance: tool|rag, freshness, logicalClock), `ActionPlan` (serialización canónica JSON ordenada por clave + digest SHA-256; ÚNICA acción allowlisted `simulator.stop-cpu-load` con target `zabbix-cpu-simulator`, comando exacto `docker exec zabbix-cpu-simulator pkill -f 'stress-ng --cpu'`, precondiciones, rollback manual documentado vía `scripts/set-cpu-load.sh`, blastRadius, evidenceRefs, policyVersion, expiresAt=propuesta+10min), `Approval` (id, actionDigest, approverSlackUserId, role, issuedAt, expiresAt) y `JournalEvent`; ABI congelado de telemetría y MCP; fixtures de contrato en `fixtures/contracts/**` (payload webhook Zabbix: event id, host, item key/valor, trigger nombre/severidad, event time; respuestas problem.get/item.get/history.get/host.get del escenario; payload webhook Datadog con template custom de variables documentadas $ALERT_ID/$ALERT_TRANSITION/$EVENT_TITLE/$EVENT_MSG/$TAGS/$ALERT_QUERY; cassettes Datadog API v2: timeseries/logs/events);
  corpus semilla versionado en `knowledge/**` (runbook fixture "CPU alta en zabbix-cpu-simulator" + postmortem fixture histórico), congelado y sin realimentación; migración baseline `infra/postgres/migrations/0001_baseline.sql` (vector + full-text; tablas journal, approvals, reservations, receipts; unique (incidentId, actionDigest)); `.env.example` con claves vacías o default inofensivo: ZABBIX_API_URL (default http://127.0.0.1:8080/api_jsonrpc.php), ZABBIX_API_TOKEN, ZABBIX_WEBHOOK_SECRET, DATADOG_MODE (default sim), DD_API_KEY, DD_APP_KEY, DD_SITE, SLACK_BOT_TOKEN, SLACK_SIGNING_SECRET, SLACK_APP_TOKEN, SLACK_APPROVERS, SLACK_INCIDENT_CHANNEL, MODEL_PROVIDER (default fixture), MODEL, OPENAI_API_KEY, DATABASE_URL; `scripts/sre-agent/ownership-manifest.json` EXCLUYENDO explícitamente los archivos del usuario (README.md, docker-compose.cpu-simulation.yml, cpu-simulator/**, scripts/provision-zabbix-cpu.sh, scripts/set-cpu-load.sh) y fallando si una sesión los toca; `scripts/sre-agent/audit-plan.mjs`; `docs/security/threat-model-baseline.md` (webhook forjado, prompt injection, approver no autorizado, L4 deny). No implementar lógica de negocio, UI, adaptadores ni pipelines.
  Parallelization: Wave 0 | Blocked by: ninguno | Blocks: 2-9
  References (executor has NO interview context - be exhaustive): README.md:1-46 (harness Zabbix del usuario: stack existente, red docker, comandos, credenciales Admin/zabbix, métrica system.cpu.util, URL web 127.0.0.1:8080); .omo/drafts/agente-ia-sre-datadog.md:39-48 (fichas verificadas Datadog + 12 fixes Metis); https://www.zabbix.com/documentation/7.4/en/manual/api/reference/problem/get, https://www.zabbix.com/documentation/7.4/en/manual/api/reference/item/get, https://www.zabbix.com/documentation/7.4/en/manual/api/reference/history/get, https://www.zabbix.com/documentation/7.4/en/manual/api/reference/host/get (verificadas 2026-09-12); https://www.zabbix.com/documentation/7.4/en/manual/api (auth Bearer token); https://www.zabbix.com/documentation/7.4/en/manual/config/notifications/media/webhook; https://docs.datadoghq.com/integrations/webhooks.md; https://docs.datadoghq.com/api/latest/; .omo/plans/agente-ia-sre-hackathon.md:76-82 (patrón de contratos heredado).
  Acceptance criteria (agent-executable): `pnpm install --frozen-lockfile && pnpm --filter @sre/contracts test && node scripts/sre-agent/audit-plan.mjs .omo/plans/agente-ia-sre-datadog.md` en verde; schemas validan round-trip del fixture webhook Zabbix Y del Datadog a IncidentEnvelope v1 (fix Metis #12) y rechazan fixture inválido; digest de ActionPlan determinista (mismo JSON canónico → mismo SHA-256); corpus knowledge/** con hash versionado; ownership-manifest falla al asignar un path del usuario a cualquier sesión.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/contracts test`; failure `pnpm --filter @sre/contracts test -- --testNamePattern=rejects-malformed-webhook-fixture`; Evidence .omo/evidence/task-1-agente-ia-sre-datadog.json
  Commit: Y | chore(contracts): scaffold workspace and freeze incident contracts

- [ ] 2. Implementar gateway, journal durable y ciclo de estado del incidente
  What to do / Must NOT do: En `apps/api/src/core/**`: endpoint `POST /webhooks/zabbix` que verifica header de secreto compartido (timing-safe compare contra ZABBIX_WEBHOOK_SECRET; 401 si falta o difiere — fix Metis #6), deduplica por dedupKey con idempotencia (Zabbix/Datadog reintentan ante 5xx → re-POSTs repetidos deben ser idempotentes) y normaliza a IncidentEnvelope (source=zabbix); endpoint `POST /webhooks/datadog` con el mismo contrato (normalizador shaped); journal Postgres append-only ordenado; interfaz `DurableIncidentWorkflow` + adaptador Temporal (`infra/workflows/**`) + fixture local persistido con retry/backoff, errores no reintentables e idempotency keys; máquina de estados `received → investigating → proposed → awaiting_approval → executing → verifying → resolved|needs_human` con transiciones inválidas rechazadas. No llamar LLM, no ejecutar writes, no exponer endpoints mutantes.
  Parallelization: Wave 1, Sesión A / `codex/sre-core` | Blocked by: 1 | Blocks: 10
  References (executor has NO interview context - be exhaustive): `fixtures/contracts/**` y `packages/contracts/**` de todo 1; .omo/plans/agente-ia-sre-hackathon.md:84-90 (estructura heredada gateway/journal); .omo/drafts/agente-ia-sre-datadog.md:44 (webhook Datadog reintenta 5 veces ante 5xx → dedup obligatorio); https://www.zabbix.com/documentation/7.4/en/manual/config/notifications/media/webhook (el script del media type se aprovisiona en todo 12).
  Acceptance criteria (agent-executable): con Postgres efímero (Testcontainers): creación desde fixture Zabbix; dedup de webhook repetido; 401 ante secreto ausente/incorrecto; retry tras fallo transitorio; no-retry ante schema inválido; recuperación tras reinicio; transición inválida rechazada; journal ordenado. `pnpm --filter @sre/api test`.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/api test -- --testNamePattern=creates-incident-from-zabbix-webhook`; failure `pnpm --filter @sre/api test -- --testNamePattern=rejects-missing-webhook-secret` + `deduplicates-repeated-webhook`; Evidence .omo/evidence/task-2-agente-ia-sre-datadog.json
  Commit: Y | feat(core): add durable incident gateway and journal

- [ ] 3. Construir catálogo de servicios y pipeline RAG del corpus semilla
  What to do / Must NOT do: Catálogo versionado del escenario (host `zabbix-cpu-simulator`: contenedor, Zabbix Agent 2, template estándar, item `system.cpu.util`, comandos de carga/descarga documentados, ownership fixture) consultable por el motor; pipeline de ingesta de `knowledge/**` (corpus congelado de todo 1) hacia pgvector con búsqueda híbrida (vectorial + full-text) expuesta como `rag.search_runbooks` devolviendo pasajes CITADOS y marcados untrusted. No realimentar postmortems generados al corpus (fix Metis #10); el RAG jamás confirma causas — solo contextualiza.
  Parallelization: Wave 1, Sesión A | Blocked by: 1 | Blocks: 10
  References (executor has NO interview context - be exhaustive): README.md:28-44 (escenario, métrica y comandos); `knowledge/**` y migración baseline de todo 1; doc Gemini §2 capa 2 (contexto/topología); fix Metis #10.
  Acceptance criteria (agent-executable): búsqueda semántica recupera el runbook/postmortem fixture relevante para "CPU alta zabbix-cpu-simulator" con score y cita; ingesta idempotente (re-run no duplica); un postmortem generado NO aparece en resultados tras re-ingesta.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/api test -- --testNamePattern=retrieves-relevant-runbook`; failure `pnpm --filter @sre/api test -- --testNamePattern=no-postmortem-feedback-loop`; Evidence .omo/evidence/task-3-agente-ia-sre-datadog.json
  Commit: Y | feat(context): add scenario catalog and seeded RAG pipeline

- [ ] 4. Añadir observabilidad, redacción y trazabilidad OTel del núcleo
  What to do / Must NOT do: En `packages/telemetry/**`: ABI de eventos (`incident.*`, `tool.*`, `policy.*`, `approval.*`, `broker.*`, `postcheck.*`) congelado en todo 1; instrumentar gateway/core/redacción; redacción de todos los secretos (ZABBIX_API_TOKEN, ZABBIX_WEBHOOK_SECRET, DD_API_KEY, DD_APP_KEY, SLACK_*, OPENAI_API_KEY, DATABASE_URL) en journal/evidencia/transcript. No almacenar payloads crudos con secretos; cada dueño de componente emite sus propios eventos vía ABI.
  Parallelization: Wave 1, Sesión A | Blocked by: 1 | Blocks: 10
  References (executor has NO interview context - be exhaustive): https://opentelemetry.io/docs/specs/semconv/general/events/; .omo/plans/agente-ia-sre-hackathon.md:100-106 (patrón heredado); ABI de todo 1.
  Acceptance criteria (agent-executable): test inspecciona trazas/eventos con correlación de incidente, timestamp y ausencia total de secretos de fixture; schema del ABI estable.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/telemetry test -- --testNamePattern=records-audit-events`; failure `pnpm --filter @sre/telemetry test -- --testNamePattern=redacts-secrets`; Evidence .omo/evidence/task-4-agente-ia-sre-datadog.json
  Commit: Y | feat(observability): add sanitized incident telemetry

- [ ] 5. Implementar TelemetrySource, adaptadores Zabbix/Datadog y tools MCP read-only
  What to do / Must NOT do: Interfaz `TelemetrySource` en `packages/tools/**` (o contrato compartido); `packages/zabbix/**`: ZabbixAdapter REAL — cliente JSON-RPC (POST a ZABBIX_API_URL con Content-Type application/json-rpc y `Authorization: Bearer ZABBIX_API_TOKEN`) con getProblem(host)→problem.get, getItem(host,key)→item.get, getItemHistory(host,key,from,to,limit≤1000)→history.get (history=0 float, sortfield=clock), getHost(host)→host.get; SOLO lectura, timeouts y errores tipados. `packages/datadog/**`: DatadogAdapter con la MISMA interfaz y dos providers: FixtureProvider (cassettes de todo 1) y RealProvider (`@datadog/datadog-api-client`, instanciado SOLO con DATADOG_MODE=real + DD_API_KEY/DD_APP_KEY/DD_SITE; mapea dd.query_metrics→POST /api/v2/query/timeseries, dd.search_logs→POST /api/v2/logs/events/search con page.cursor, dd.search_events→POST /api/v2/events/search); parity test: la MISMA suite corre contra FixtureProvider y contra cassettes de formato real (fix Metis #5). `packages/tools/**`: servidor MCP (stdio + HTTP para tests) que expone EXCLUSIVAMENTE: zbx.get_problem, zbx.get_item, zbx.get_item_history, zbx.get_host, dd.query_metrics, dd.search_logs, dd.search_events, catalog.get_service, rag.search_runbooks (fix Metis #9: set exacto); cada tool valida schema JSON de entrada; unallowlisted/mutante → rechazo. Sin credenciales Datadog reales, DATADOG_MODE permanece sim.
  Parallelization: Wave 1, Sesión B / `codex/sre-intelligence` | Blocked by: 1 | Blocks: 6, 10
  References (executor has NO interview context - be exhaustive): URLs Zabbix API verificadas (problem/get, item/get, history/get, host/get — ver todo 1); https://www.zabbix.com/documentation/7.4/en/manual/api (auth); https://www.zabbix.com/documentation/7.4/en/manual/web_interface/frontend_sections/users/api_tokens; .omo/drafts/agente-ia-sre-datadog.md:40-47 (SDK @datadog/datadog-api-client v1.63.0, endpoints v2 exactos, paginación máx 1000, RBAC scopes); https://modelcontextprotocol.io/specification/2025-11-25/server/tools; fixes Metis #5/#9.
  Acceptance criteria (agent-executable): un cliente MCP descubre SOLO las 9 tools allowlisted; invocación no declarada/mutante rechazada; zbx.* contra mock JSON-RPC devuelve problema/ítem/historia correctos del fixture (system.cpu.util 95%); dd.* en sim devuelve formas v2 exactas; parity test pasa en ambos modos; test afirma que RealProvider jamás se instancia con DATADOG_MODE≠real. `pnpm --filter @sre/tools test && pnpm --filter @sre/zabbix test && pnpm --filter @sre/datadog test`.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/tools test -- --testNamePattern=serves-allowlisted-tools`; failure `pnpm --filter @sre/tools test -- --testNamePattern=rejects-unallowlisted-tool` + `pnpm --filter @sre/datadog test -- --testNamePattern=never-instantiates-real-provider-in-sim`; Evidence .omo/evidence/task-5-agente-ia-sre-datadog.json
  Commit: Y | feat(intelligence): add telemetry adapters and read-only MCP tools

- [ ] 6. Implementar motor de hipótesis, decisión y propuesta acotada
  What to do / Must NOT do: En `packages/analysis/**`: `LLMProvider` con FixtureProvider (determinista, replay del caso CPU) por defecto y OpenAIProvider opcional (MODEL_PROVIDER=openai, MODEL=gpt-5.6-sol; clave jamás persistida); motor: IncidentEnvelope → contexto (catalog.get_service + rag.search_runbooks citado y marcado untrusted) → 2-3 Hypothesis tipadas con confidence, requiredEvidence y falsifier → ejecución de falsificadores vía tools MCP (zbx.get_item_history: system.cpu.util sostenido >90%; zbx.get_problem: sin problemas en otros hosts; zbx.get_item: lastvalue consistente) → síntesis causal (carga stress-ng → saturación CPU → trigger) + blast radius (contenedor único) → DECISIÓN ACOTADA (fix Metis #11): proponer la ÚNICA ActionPlan allowlisted `simulator.stop-cpu-load` o `needs_human` con razón; salida JSON validada contra schema; instrucciones separadas de datos; texto de logs/RAG tratado como dato opaco no confiable. El LLM nunca confirma causas (solo evidencia viva), nunca selecciona writes, nunca altera policy.
  Parallelization: Wave 1, Sesión B | Blocked by: 1, 5 | Blocks: 10
  References (executor has NO interview context - be exhaustive): doc Gemini §3 pasos 2-4 (bucle cognitivo); README.md:38 ("el agente puede validar la alerta, consultar el estado y verificar la recuperación" — propósito declarado del harness); contratos de todo 1; tools de todo 5; fix Metis #11.
  Acceptance criteria (agent-executable): caso CPU fixture: confirma H1 (carga stress-ng) con métrica+problema+ítem; refuta H2 (otros hosts normales); evidencia faltante → inconclusive; FixtureProvider reproduce el journal completo sin red ni secretos; inyección de prompt embebida en log/RAG fixture NO selecciona tools extra, NO crea ActionPlan, NO cambia policy; la decisión propuesta es exactamente simulator.stop-cpu-load con digest válido o needs_human. `pnpm --filter @sre/analysis test`.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/analysis test -- --testNamePattern=confirms-stress-ng-cause`; failure `pnpm --filter @sre/analysis test -- --testNamePattern=does-not-confirm-without-live-evidence` + `ignores-prompt-injection`; Evidence .omo/evidence/task-6-agente-ia-sre-datadog.json
  Commit: Y | feat(analysis): add falsifiable incident reasoning engine

- [ ] 7. Construir política OPA, planes inmutables y action broker idempotente
  What to do / Must NOT do: `packages/policy/**` + `infra/opa/**`: reglas OPA — `simulator.stop-cpu-load` L3 permitido SOLO con Approval válida (digest == ActionPlan pendiente, approverSlackUserId ∈ SLACK_APPROVERS, TTL 10 min no expirado, incidentId coincidente, policyVersion correcta — fixes Metis #7/#8); deniega digest distinto, expirado, approver fuera de allowlist, replay y evidencia insuficiente; L4 documentado en `docs/security/autonomy-matrix.md` pero SIEMPRE deny en ejecución. `packages/action-broker/**`: reserva atómica única (incidentId, actionDigest) con estados `reserved → external_write_started → receipt_recorded|failed`; ejecutor EXACTO y allowlisted: `docker exec zabbix-cpu-simulator pkill -f 'stress-ng --cpu'` vía child_process desde el broker (nunca shell del LLM), preflight (contenedor corriendo + proceso stress-ng presente); receipt (operationId, before/after); recuperación consulta operationId antes de repetir; postflight emite eventos ABI. Sin aprobación libre, sin bypass UI/LLM, sin segunda acción, sin auto-reintento (escala a humano).
  Parallelization: Wave 1, Sesión C / `codex/sre-slack-safety` | Blocked by: 1 | Blocks: 9, 10
  References (executor has NO interview context - be exhaustive): README.md:40-44 (comando de detención documentado por el usuario: `docker exec zabbix-cpu-simulator pkill -f 'stress-ng --cpu'`); doc Gemini §4 (matriz L1-L4); .omo/plans/agente-ia-sre-hackathon.md:124-130 (patrón heredado broker/reservas); https://www.openpolicyagent.org/docs/latest/policy-language/; fixes Metis #7/#8.
  Acceptance criteria (agent-executable): OPA permite stop-cpu-load sólo con approval válida y deny absoluto para L4; deniega digest/expired/allowlist/replay/evidencia insuficiente; submit paralelo produce UNA reserva; crash tras write antes de receipt → recuperación por operationId sin segundo write; contador de writes == 1 en happy y adversarial; TTL probado con reloj lógico Y ventana real. `pnpm --filter @sre/policy test && pnpm --filter @sre/action-broker test`.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/policy test -- --testNamePattern=allows-approved-stop-cpu-load`; failure `pnpm --filter @sre/policy test -- --testNamePattern=denies-expired-approval` + `denies-non-allowlisted-approver`; Evidence .omo/evidence/task-7-agente-ia-sre-datadog.json
  Commit: Y | feat(safety): enforce approval-bound remediation policy

- [ ] 8. Construir bot Slack Bolt con tarjeta de incidente y aprobación L3
  What to do / Must NOT do: `apps/channel/**`: app Slack Bolt (Socket Mode cuando exista SLACK_APP_TOKEN; harness offline con mock del Web API por defecto): publica `incident_card` (Block Kit) en SLACK_INCIDENT_CHANNEL con título/severidad/host, hipótesis con confianza y estado, evidencia con origen `tool|rag`, síntesis causal, blast radius, propuesta con digest y badge SANDBOX; botones Aprobar/Rechazar (block_actions) → Approval con approverSlackUserId del click → OPA/broker; DENY visible ante digest inválido/expirado o approver no autorizado; actualización del card al resolver. Identidad→rol exclusivamente vía SLACK_APPROVERS. Sin segunda superficie web/móvil, sin leer otros canales, sin ejecutar acción fuera del broker.
  Parallelization: Wave 1, Sesión C | Blocked by: 1 | Blocks: 10
  References (executor has NO interview context - be exhaustive): doc Gemini §4 nivel 3 (aprobación interactiva); fix Metis #7 (identidad→rol); .omo/plans/agente-ia-sre-hackathon.md:132-138 (patrón heredado); https://api.slack.com/tools/bolt (Bolt JS); contratos Approval de todo 1.
  Acceptance criteria (agent-executable): harness renderiza el card con evidencia citada y badge SANDBOX; click Aprobar de usuario allowlisted produce Approval digest-bound que OPA acepta; click de usuario NO allowlisted → DENY + mensaje; aprobación sin digest válido → bloqueada; sin SLACK_* env, el harness offline pasa completo (live sólo con .env). `pnpm --filter @sre/channel test`.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/channel test -- --testNamePattern=renders-incident-card`; failure `pnpm --filter @sre/channel test -- --testNamePattern=blocks-non-allowlisted-approver` + `blocks-action-without-valid-digest`; Evidence .omo/evidence/task-8-agente-ia-sre-datadog.png
  Commit: Y | feat(slack): add incident card and L3 approval flow

- [ ] 9. Añadir postcheck, escalamiento y generador de postmortem desde journal
  What to do / Must NOT do: Postcheck con ventana configurable (default 5 min reloj real; fixtures con reloj lógico declarado en journal): consulta zbx.get_item_history(system.cpu.util) hasta descenso sostenido bajo el umbral (<80% por 2 min) → `resolved`; timeout o métrica roja → `needs_human_intervention`; SIN nueva mutación automática. Generador de postmortem desde JournalEvents: timeline exacto (alerta → hipótesis → decisión → aprobación → ejecución → recuperación) con timestamps y evidencia vinculada, en Markdown.
  Parallelization: Wave 1, Sesión C | Blocked by: 1, 7 | Blocks: 10
  References (executor has NO interview context - be exhaustive): README.md:38 (verificar la recuperación cuando la carga termina — requisito del propio harness); doc Gemini §3 pasos 5-6 y §6 (cierre/postmortem); .omo/plans/agente-ia-sre-hackathon.md:139-145 (patrón heredado); journal de todo 2.
  Acceptance criteria (agent-executable): fixture saludable → resolved + postmortem con timeline y timestamps exactos; fixture rojo tras stop (carga re-aplicada) → needs_human y contador de writes == 1. `pnpm --filter @sre/action-broker test`.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/action-broker test -- --testNamePattern=verifies-cpu-recovery`; failure `pnpm --filter @sre/action-broker test -- --testNamePattern=escalates-after-failed-mitigation`; Evidence .omo/evidence/task-9-agente-ia-sre-datadog.json
  Commit: Y | feat(recovery): add postcheck escalation and postmortems

- [ ] 10. Integrar flujo E2E y los tres PRs de Wave 1
  What to do / Must NOT do: En `codex/sre-integration` (desde develop actualizado): conectar gateway + tools + motor + policy + broker + channel + postcheck; E2E automatizado en `e2e/**` en modo harness (webhook fixture + mock Slack + Zabbix API mock del fixture): alerta → investigación → propuesta → aprobación fixture → broker → postcheck → postmortem; modo `--live` opcional contra el stack Zabbix real del usuario (requiere stack corriendo y provisioning de todo 12). No refactorizar internals de las tres ramas salvo corrección mínima de interfaz documentada; CI jamás requiere credenciales Slack/Datadog.
  Parallelization: Wave 2 | Blocked by: 2-9 | Blocks: 11, 12
  References (executor has NO interview context - be exhaustive): matriz de dependencias de este plan; contratos de todo 1 (SHA de contrato); PRs codex/sre-core, codex/sre-intelligence, codex/sre-slack-safety; README.md:9-12 (docker compose del usuario).
  Acceptance criteria (agent-executable): flujo completo pasa: alerta fixture → causalidad confirmada → propuesta → aprobación → UN recibo broker → postcheck verde → postmortem generado; `pnpm test:e2e` verde; verificación de integración contra las tres implementaciones (SHA de contrato declarado en cada PR).
  QA scenarios (name the exact tool + invocation): happy `pnpm test:e2e -- --grep "cpu alert causal stop-load"`; failure `pnpm test:e2e -- --grep "needs human on failed stop"`; Evidence .omo/evidence/task-10-agente-ia-sre-datadog.json
  Commit: Y | feat(integration): compose end-to-end incident workflow

- [ ] 11. Ejecutar suite de seguridad adversarial y deduplicación
  What to do / Must NOT do: Escenarios automatizados (`scripts/sre-agent/demo-verify.mjs` o equivalente en `e2e/**`): webhook forjado (sin/mal secreto → 401 y CERO efectos — fix Metis #6), replay de webhook (idempotente), inyección de prompt en log/RAG (sin tools extra ni ActionPlan), aprobación expirada (TTL lógico y real), doble aprobación paralela (una reserva), approver no allowlisted (DENY), observabilidad caída (Zabbix API mock en error → inconclusive → needs_human sin writes), mitigación fallida (stop no termina la carga → postcheck rojo → needs_human, writes == 1), alerta duplicada concurrente. Ningún éxito se declara porque la UI dibuje un mensaje: cada assertion lee journal + contador del broker.
  Parallelization: Wave 2 | Blocked by: 2-10 | Blocks: F1-F4
  References (executor has NO interview context - be exhaustive): fixes Metis #6/#7/#8; todos 7-9; doc Gemini §4; fichas webhook Datadog (reintentos) .omo/drafts/agente-ia-sre-datadog.md:44.
  Acceptance criteria (agent-executable): evidencia JSON afirma cero writes por cada DENY, un único recibo para duplicados/replays, needs_human en outage/fallo; todas las assertions leen journal y contador del broker.
  QA scenarios (name the exact tool + invocation): happy `pnpm demo:verify --scenario happy`; failure `pnpm demo:verify --scenario forged-webhook --scenario duplicate --scenario prompt-injection --scenario expired-approval --scenario observability-outage --scenario failed-mitigation`; Evidence .omo/evidence/task-11-agente-ia-sre-datadog.json
  Commit: Y | test(safety): cover hostile incident scenarios

- [ ] 12. Empaquetar demo reproducible, aprovisionamiento Zabbix y documentación
  What to do / Must NOT do: `scripts/sre-agent/provision-zabbix-webhook.sh` (NUEVO — no toca los scripts del usuario; replica el patrón de README.md:14-26: contenedor alpine con curl/jq contra la API): con credenciales Admin del stack crea (a) token API read-only para el agente, (b) media type webhook cuyo script JS POSTea el evento de problema (event id, host, item key/valor, trigger nombre/severidad, event time) al gateway con header de secreto compartido, (c) action que envíe problemas del host zabbix-cpu-simulator al webhook — vía mediatype.create/action.create o importación XML; `compose.yaml` propio del agente (Postgres+pgvector, OPA); `pnpm demo:seed` (corpus + fixtures) y `pnpm demo:run` (modo harness offline completo) + `pnpm demo:run --live` (stack real: dispara con `bash scripts/set-cpu-load.sh 2 95 180` del usuario); docs en `docs/**`: arquitectura, runbook de demo, `docs/security/autonomy-matrix.md` (L1-L4, L4 deny), threat model final y guía de activación Datadog real (DATADOG_MODE=real + DD_*) y Slack live. Sin secretos en repo, sin pasos manuales ocultos, sin tocar archivos del usuario, sin afirmar integración productiva.
  Parallelization: Wave 2 | Blocked by: 2-10 | Blocks: F1-F4
  References (executor has NO interview context - be exhaustive): README.md:14-26 y 30-36 (patrón de provisión del usuario y disparo de carga); https://www.zabbix.com/documentation/7.4/en/manual/config/notifications/media/webhook y .../webhook_examples (script JS del media type); https://www.zabbix.com/documentation/7.4/en/manual/api/reference/mediatype/create y .../action/create; URLs API de todo 1; artefactos de todos 1-11.
  Acceptance criteria (agent-executable): entorno limpio: `pnpm bootstrap && pnpm demo:seed && pnpm demo:run` pasa offline sin secretos; con stack real corriendo + provision script: `bash scripts/set-cpu-load.sh 2 95 180` produce incidente completo con recuperación; docs coinciden con artefactos y declaran sandbox/reloj lógico; guía Datadog/Slack documentada.
  QA scenarios (name the exact tool + invocation): happy `pnpm demo:run`; failure `pnpm demo:run --scenario missing-metrics`; Evidence .omo/evidence/task-12-agente-ia-sre-datadog.log
  Commit: Y | docs(demo): package reproducible AI SRE showcase

## Final verification wave
> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.
- [ ] F1. Plan compliance audit
  What to do / Must NOT do: Verificar que cada Must have y Must NOT have traza a uno o más todos, que todo archivo del agente tiene un único dueño y que los archivos del usuario permanecen sin dueño (intocables). No aceptar cobertura por descripción oral.
  Acceptance criteria (agent-executable): `node scripts/sre-agent/audit-plan.mjs .omo/plans/agente-ia-sre-datadog.md` genera la matriz requisito→todo→evidencia con las 12 filas de todo y 4 final-verifier rows, y falla ante path overlap, archivo sin dueño, SHA contractual cambiado o path del usuario asignado.
  QA scenarios (name the exact tool + invocation): happy audit en verde con matriz completa; failure referencia faltante inducida → audit falla; Evidence .omo/evidence/f1-plan-compliance.json
  Commit: N | n/a

- [ ] F2. Code quality review
  What to do / Must NOT do: Ejecutar lint, typecheck y tests completos; revisar límites de módulos; rechazar `any`, secretos, accesos de escritura no mediados por el broker y duplicación de contratos.
  Acceptance criteria (agent-executable): `pnpm lint && pnpm typecheck && pnpm test` con salida cero y reporte estático sin `any` ni secretos.
  QA scenarios (name the exact tool + invocation): happy comando completo; failure `pnpm --filter @sre/policy test -- --testNamePattern=denies-write-bypass`; Evidence .omo/evidence/f2-quality.log
  Commit: N | n/a

- [ ] F3. Real manual QA
  What to do / Must NOT do: Ejecutar la demo en harness Bolt (y Slack live sólo si existen credenciales en .env), capturando alerta→investigación→aprobación→stop→recuperación→postmortem y los estados DENY/escalación, con badge SANDBOX visible. No sustituir assertions visuales por grep de mensajes.
  Acceptance criteria (agent-executable): harness guarda transcript/capturas y journal verificable para happy, DENY, acción aprobada, badge SANDBOX y failed mitigation.
  QA scenarios (name the exact tool + invocation): `pnpm --filter @sre/channel test -- --testNamePattern="incident card"`; failure `pnpm --filter @sre/action-broker test -- --testNamePattern="escalates after failed mitigation"`; Evidence .omo/evidence/f3-manual-qa/
  Commit: N | n/a

- [ ] F4. Scope fidelity
  What to do / Must NOT do: Comparar la entrega contra este plan: sin producción, L4 deny en policy, única acción L3, sin git-correlación, archivos del usuario intactos (diff vacío en sus paths), dd.* real sólo con DATADOG_MODE=real. No declarar L4 productivo ni integración Datadog "activa".
  Acceptance criteria (agent-executable): checklist script inspecciona configuración, policies y el estado git de los paths del usuario; todos los guardrails pasan.
  QA scenarios (name the exact tool + invocation): `pnpm demo:verify --scenario scope-guardrails`; failure `pnpm demo:verify --scenario production-target`; Evidence .omo/evidence/f4-scope.json
  Commit: N | n/a

## Commit strategy

- Preflight en `codex/sre-foundation`: `chore(contracts): scaffold workspace and freeze incident contracts` se fusiona primero a `develop`; el SHA del contrato queda registrado como base de las tres sesiones.
- Tres PRs de Wave 1 desde worktrees aislados, sin commits cruzados: `codex/sre-core`, `codex/sre-intelligence`, `codex/sre-slack-safety`. Cada PR declara el SHA de contrato y sólo toca sus rutas propietarias — el ownership-manifest hace fallar el CI de lo contrario.
- El integrador rebasa sobre `origin/develop` antes de abrir `codex/sre-integration`; su PR incluye sólo composición, E2E, aprovisionamiento Zabbix, demo y documentación.
- Sin rebase de ramas compartidas ni force-push; fusión de PRs sólo con checks verdes; commits atómicos de feature + prueba directa; los archivos del harness del usuario jamás entran en un commit del agente.

## Success criteria

- El agente valida la alerta real del harness: webhook autenticado del problema Zabbix → investigación con evidencia viva (problem/item/history) → 2-3 hipótesis falsables → causalidad confirmada (stress-ng → saturación CPU → trigger) → propuesta única con digest.
- La acción `simulator.stop-cpu-load` jamás ocurre sin Approval válida (digest + allowlist + TTL); L4 siempre deny; tras fallo o postcheck rojo el sistema escala a humano, no muta de nuevo.
- La recuperación de CPU es observable vía history de `system.cpu.util` y el postmortem se genera desde el journal con timeline exacto.
- El adaptador Datadog pasa parity tests y sólo se activa con DATADOG_MODE=real + DD_*; toda la suite pasa offline sin secretos ni credenciales.
- Los 12 todos y F1-F4 pasan sus checks; las tres ramas se integran sin overlap; los archivos del harness Zabbix del usuario quedan intactos.
