# agente-ia-sre-hackathon - Work Plan

## TL;DR (For humans)

**What you'll get:** ThreadSRE es un copiloto AI SRE dentro de un hilo de incidente de Slack: lee el contexto ya discutido, investiga un incidente sandbox de `payment-gateway`, publica una tarjeta nativa con evidencia y propone un rollback L3 seguro.

**Why this approach:** Slack es donde ya opera el equipo SRE. El hilo puede revelar que un rollback anterior falló, información que se pierde fuera de esa superficie; OpenAI y CopilotKit Channels permiten convertirla en una interacción visible y útil.

**What it will NOT do:** No se conectará a producción, no expondrá shell/kubectl al modelo, no creará una segunda superficie web/móvil y no publicará la entrega, vídeo o post social por cuenta del equipo.

**Effort:** XL
**Risk:** High - integra razonamiento, herramientas, estado, UX y una frontera de seguridad; se controla con contratos congelados, fixtures y una sola narración de demo.
**Decisions I made for you:** Node.js 22 + TypeScript; Slack/CopilotKit Channels como única superficie; OpenAI Responses `MODEL=gpt-5.6-sol` para demo live y fixture provider offline; Postgres + pgvector, OPA y MCP read-only. El rollback GitOps es L3 con aprobación humana; L4 sandbox sólo cubre cleanup `/tmp`, restart y scale allowlisted.

Your next move: ejecutar el plan mediante `$start-work agente-ia-sre-hackathon --worktree <ruta-absoluta>`; usar `--make-pr` para que el resultado llegue como PR.

---

> TL;DR (machine): XL, ThreadSRE usa Slack thread context, OpenAI + CopilotKit Channels y AI SRE sandboxed con rollback L3, L4 allowlisted, recuperación/postmortem y tres ramas paralelas.

## Scope

### Must have

- Las cinco capas del documento: trigger, contexto/topología, tooling, cognitive loop y safety/action.
- Agente Slack de CopilotKit Channels que usa `read_thread`, publica `incident_card` y atribuye evidencia de hilo, tools y RAG; `IncidentEnvelope v1`, journal durable e idempotente.
- Caso versionado: despliegue `abc1234` de `payment-gateway` dentro de una ventana de 60 minutos, saturación de pool PostgreSQL y alerta HTTP 504.
- Lecturas bajo demanda de métricas, logs, trazas, despliegues y Git; RAG de runbook/postmortem como antecedente citado.
- Dos o tres hipótesis con prueba falsadora, evidencia causal, blast radius y decisión explícita confirmada/refutada/inconclusa.
- Remediación GitOps reversible, OPA, aprobación ligada a un digest de acción y broker idempotente; observación de SLO y postmortem desde el journal.
- Matriz L1–L4 sobre sandbox: L1/L2 aconsejan; L3 ejecuta el rollback GitOps sólo tras aprobación humana digest-bound; L4 sólo cleanup `/tmp`, restart de pod fixture y scale temporal allowlisted, todos reversibles y con escalamiento.
- Pruebas automatizadas y artefactos de evidencia de camino feliz y fallos de seguridad.

### Must NOT have (guardrails, anti-slop, scope boundaries)

- Acceso a producción, secretos reales, shell, `kubectl` genérico, autoescalación de privilegios, herramientas de escritura directas al LLM o una segunda superficie web/móvil.
- Más de una mutación narrativa principal: el rollback GitOps de `payment-gateway`. Las tres acciones L4 se prueban por fixtures aislados, no como acceso abierto.
- Dos motores de política, dos bases vectoriales, dos bots completos o despliegue GPU/vLLM local.
- Confirmar una causa desde RAG, logs no verificados o texto no confiable; toda conclusión accionable exige evidencia viva y prueba falsadora.
- Una aprobación sin identidad, TTL, objetivo, evidencia, política y digest exactos; tras fallo o postcheck rojo el sistema escala, no muta de nuevo.

## Verification strategy

> Zero human intervention - all verification is agent-executed.

- Test decision: TDD para contratos, policy, broker y Channel tools; tests-after para tarjetas Slack. Node.js 22, pnpm, Vitest, Testcontainers/Postgres, Channels test harness y OPA. Offline se verifica sin cuentas; Slack live se verifica con `.env`.
- Evidence: `.omo/evidence/task-<N>-agente-ia-sre-hackathon.{json,log,png}`. Cada prueba persiste request/response sanitizados, journal, decisiones de policy, recibos idempotentes y capturas de flujo.
- Comando final: `pnpm lint && pnpm typecheck && pnpm test && pnpm test:e2e && pnpm demo:verify`.
- Tiempo de recuperación: runtime acepta ventana real de 5 min; fixtures pueden usar reloj lógico y deben declararlo en el journal/evidencia.

## Execution strategy

### Parallel execution waves

- **Wave 0 — sincronización breve:** la rama `codex/sre-foundation` crea y fusiona un commit de contratos congelados contra `develop`: `packages/contracts/**`, `fixtures/contracts/**`, manifest raíz, lockfile, `scripts/ownership-manifest.json`, `scripts/audit-plan.mjs`, `infra/postgres/migrations/0001_baseline.sql`, `docs/contracts/**`, `docs/hackathon-source/**`, `scripts/submission-verify.mjs` y `docs/security/threat-model-baseline.md`. La migración baseline habilita pgvector/full-text y crea tablas de journal, approvals, reservations y receipts; toda migración posterior queda exclusivamente en `infra/postgres/migrations/0002_*.sql` bajo Sesión A. No se inicia funcionalidad hasta registrar ese SHA.
- **Wave 1 — tres sesiones simultáneas:** cada sesión crea un worktree y rama desde el SHA contractual, trabaja sólo en sus rutas exclusivas y abre un PR atómico a `develop`.
  - **Sesión A / `codex/sre-core`:** `apps/api/src/core/**`, `packages/telemetry/**`, `infra/workflows/**`, `infra/postgres/migrations/0002_*.sql`; no modifica el baseline `0001_baseline.sql` de foundation.
  - **Sesión B / `codex/sre-intelligence`:** `packages/simulator/**` incluidos `packages/simulator/fixtures/**`, `packages/tools/**`, `packages/analysis/**`, `knowledge/**`.
  - **Sesión C / `codex/sre-slack-safety`:** `packages/policy/**`, `packages/action-broker/**`, `apps/channel/**`, `infra/opa/**`, `gitops/**`, `docs/security/threat-model-demo.md` y tests browser bajo `apps/channel/**`. Su broker consume únicamente el `ActionPlan` congelado y fixtures de contrato, por lo que no necesita esperar código de B.
- **Wave 2 — integración:** una sesión integradora crea `codex/sre-integration` desde `develop` actualizado y posee exclusivamente `apps/api/src/integration/**`, `e2e/**`, `compose.yaml`, `.devcontainer/**`, `docs/demo/**`, `docs/submission/**` y `scripts/demo/**`. La Wave 0 predeclara en el manifest raíz los entrypoints que invocan `scripts/demo/**`, por lo que la integración no toca configuración raíz. Nunca reescribe código interno de los tres PRs sin acuerdo explícito.
- Cada PR debe rebasarse sobre `origin/develop`, pasar sus checks y declarar el SHA del contrato `IncidentEnvelope v1`. Las ramas no se fusionan entre sí; se fusionan secuencialmente a `develop`: foundation, core, intelligence, slack-safety, integration. El manifiesto de ownership debe fallar ante solapamiento, archivo no asignado o SHA contractual distinto.

### Dependency matrix

| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| 1 | Ninguno | 2–9 | Ninguno |
| 2–4 | 1 | 10 | 5–9 |
| 5–6 | 1 | 10 | 2–4, 8–9 |
| 7 | 1 | 9, 10 | 2–6, 8 |
| 8–9 | 1 | 10 | 2–7 |
| 10–13 | 2–9 | F1–F4 | Ninguno |

## Todos

- [ ] 1. Congelar el monorepo, contratos y fixtures inter-equipo
  What to do / Must NOT do: Crear monorepo Node.js 22/pnpm, root `.env.example` sin valores, schema de variables server-only, comprobación `.gitignore` de secretos, layout/manifest de ownership, y JSON Schema/TypeScript para `IncidentEnvelope`, `Hypothesis`, `Evidence`, `ActionPlan`, `Approval` y `JournalEvent`; congelar ABI de telemetría y MCP, fixtures de contrato separados de fixtures de escenario, y baseline de threat model en `docs/security/threat-model-baseline.md`. `Evidence` incluye trust/provenance/freshness/logical-clock; `ActionPlan` se serializa canónicamente y se hashea SHA-256 con incidentId, target, blast radius, preconditions, rollback, evidencia, policyVersion y expiry. `Approval` incluye ID, issuer sandbox, subject, role, digest y TTL. No implementar lógica de negocio, UI ni adaptadores en este commit.
  Parallelization: Wave 0 | Blocked by: ninguno | Blocks: 2–9
  References (executor has NO interview context - be exhaustive): `README.md:1`; documento adjunto §1–3 (alerta, contexto, hipótesis); §4–5 (acción/política); `C:/Users/danie/Downloads/hackathon-overview.md`; `C:/Users/danie/Downloads/using-sponsor-tools.md`; `C:/Users/danie/Downloads/hackathon-rules.md`; `.omo/drafts/agente-ia-sre-hackathon.md`.
  Acceptance criteria (agent-executable): fijar Node.js 22, pnpm, Postgres, OPA, Docker y versiones CopilotKit Channels en `.tool-versions`/documentación; crear `.env.example` con sólo `MODEL_PROVIDER`, `MODEL`, `OPENAI_API_KEY`, `CHANNEL_CODE`, `INTELLIGENCE_API_KEY`, validar que claves son server-only/no aparecen en transcript-journal-evidence y predeclarar entrypoints `bootstrap`, `test`, `test:e2e`, `demo:*`, `dev:slack`, `submission:verify`; archivar extractos con procedencia en `docs/hackathon-source/**`; migración habilita `vector`, full-text, journal, approvals, reservations y receipts con unique `(incidentId, actionDigest)`; `pnpm install --frozen-lockfile && pnpm --filter @sre/contracts test && node scripts/audit-plan.mjs`; validar schemas, ABI MCP/telemetría, digest, emisor/rol/TTL, ownership, migración pgvector y fixture inválido.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/contracts test`; failure `pnpm --filter @sre/contracts test -- --testNamePattern=rejects-invalid-envelope`; Evidence `.omo/evidence/task-1-agente-ia-sre-hackathon.json`.
  Commit: Y | chore(contracts): scaffold workspace and freeze incident contracts

- [ ] 2. Implementar gateway, journal durable y ciclo de estado del incidente
  What to do / Must NOT do: En `apps/api/src/core/**` implementar gateway, journal y una interfaz `DurableIncidentWorkflow`; aportar adaptador Temporal y fixture local persistido con retry/backoff, errores no reintentables e idempotency keys. Conducir `received → investigating → proposed → awaiting_approval → executing → verifying → resolved|needs_human`. No llamar LLM ni ejecutar writes.
  Parallelization: Wave 1, Sesión A | Blocked by: 1 | Blocks: 10
  References (executor has NO interview context - be exhaustive): documento adjunto §2–3; Temporal workflow/retry guidance; `packages/contracts/**` creado en todo 1.
  Acceptance criteria (agent-executable): pruebas con Postgres efímero y fixture Temporal prueban creación, retry tras fallo transitorio, no-retry ante esquema inválido, webhook repetido, recuperación tras reinicio, transición inválida y journal ordenado; `pnpm --filter @sre/api test`.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/api test -- --testNamePattern=creates-incident`; failure `pnpm --filter @sre/api test -- --testNamePattern=deduplicates-webhook`; Evidence `.omo/evidence/task-2-agente-ia-sre-hackathon.json`.
  Commit: Y | feat(core): add durable incident gateway and journal

- [ ] 3. Construir catálogo/topología, ventana de cambios y almacenamiento de evidencia
  What to do / Must NOT do: Implementar catálogo Git versionado para propiedad/dependencias y consultas de despliegues/Git dentro de 60 min; persistir snapshots fechados y enlaces de evidencia. No afirmar causalidad ni mutar Git.
  Parallelization: Wave 1, Sesión A | Blocked by: 1 | Blocks: 10
  References (executor has NO interview context - be exhaustive): documento adjunto §1 y §3; fixture `payment-gateway` de todo 1.
  Acceptance criteria (agent-executable): fixture causal `abc1234` dentro de 60 min y cambio viejo fuera de ventana devuelven sólo el candidato vigente, dueño y dependencia afectada.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/api test -- --testNamePattern=recent-deployments`; failure `pnpm --filter @sre/api test -- --testNamePattern=excludes-stale-deploy`; Evidence `.omo/evidence/task-3-agente-ia-sre-hackathon.json`.
  Commit: Y | feat(context): add catalog and deployment correlation

- [ ] 4. Añadir observabilidad, redacción y trazabilidad OTel del núcleo
  What to do / Must NOT do: Implementar utilidades ABI de telemetría y sólo instrumentar gateway/core/redacción; cada dueño de componente emite sus propios eventos de policy, aprobación, ejecución y postcheck usando el ABI congelado. No almacenar payloads crudos ni tokens.
  Parallelization: Wave 1, Sesión A | Blocked by: 1 | Blocks: 10
  References (executor has NO interview context - be exhaustive): [OpenTelemetry events](https://opentelemetry.io/docs/specs/semconv/general/events/); documento adjunto §5.
  Acceptance criteria (agent-executable): test inspecciona trazas/eventos y confirma correlación, timestamp y ausencia de secretos de fixture.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/api test -- --testNamePattern=records-audit-events`; failure `pnpm --filter @sre/api test -- --testNamePattern=redacts-secret`; Evidence `.omo/evidence/task-4-agente-ia-sre-hackathon.json`.
  Commit: Y | feat(observability): add sanitized incident telemetry

- [ ] 5. Implementar gemelo digital, RAG y adaptadores MCP read-only
  What to do / Must NOT do: Crear fixture de escenarios bajo `packages/simulator/fixtures/**` con versión, procedencia, freshness y logical clock; implementar un servidor MCP protocol-level con catálogo registrado de `obs.query_metrics`, `obs.get_trace`, `k8s.read_pod_logs`, `k8s.get_deployment_status`, `git.list_recent_deployments`, `git.get_commit`; añadir búsqueda pgvector/full-text. No exponer shell ni capacidades mutantes.
  Parallelization: Wave 1, Sesión B | Blocked by: 1 | Blocks: 7, 10
  References (executor has NO interview context - be exhaustive): documento adjunto §2–3 y §5; [MCP Tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools).
  Acceptance criteria (agent-executable): un cliente MCP descubre sólo las seis tools read-only, no puede invocar una no declarada/mutante y cada tool valida esquema; búsqueda recupera antecedente citado sin sustituir evidencia viva.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/tools test`; failure `pnpm --filter @sre/tools test -- --testNamePattern=rejects-unallowlisted-tool`; Evidence `.omo/evidence/task-5-agente-ia-sre-hackathon.json`.
  Commit: Y | feat(intelligence): add simulated MCP evidence tools and RAG

- [ ] 6. Implementar motor de hipótesis falsificables y síntesis causal
  What to do / Must NOT do: Usar `LLM_PROVIDER=fixture` como default para demo, tests y replay reproducibles; permitir adaptador opcional `LLM_PROVIDER=openai`, `MODEL=gpt-5.6-sol` sólo cuando un operador suministra clave fuera de config/versionado; producir 2–3 hipótesis tipadas, confianza, evidencia requerida, prueba falsadora y estado mediante salida JSON validada. Etiquetar logs/RAG como datos opacos no confiables, separar instrucciones de evidencia, limitar la selección al catálogo MCP y enlazar `abc1234 → timeout/pool → 504` y blast radius. No permitir que texto LLM confirme causas, seleccione writes ni altere policy.
  Parallelization: Wave 1, Sesión B | Blocked by: 1, 5 | Blocks: 7, 10
  References (executor has NO interview context - be exhaustive): documento adjunto §3; contratos de todo 1; fixtures/tools de todo 5.
  Acceptance criteria (agent-executable): caso pool confirma causa con métrica+log+deploy y refuta hipótesis de red; evidencia faltante queda `inconclusive`; fixture provider reproduce el journal sin red/secret; adapter OpenAI usa únicamente `MODEL=gpt-5.6-sol` y nunca persiste clave/datos sensibles; prompt injection no selecciona tools extra, no cambia policy ni crea ActionPlan.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/analysis test -- --testNamePattern=confirms-pool-cause`; failure `pnpm --filter @sre/analysis test -- --testNamePattern=does-not-confirm-without-live-evidence`; Evidence `.omo/evidence/task-6-agente-ia-sre-hackathon.json`.
  Commit: Y | feat(analysis): add falsifiable incident reasoning

- [ ] 7. Construir política OPA, planes inmutables y broker de acciones
  What to do / Must NOT do: Definir reglas OPA para sandbox, aprobación L3 y catálogo L4: rollback GitOps L3 de `gitops/payment-gateway/deployment.yaml` desde `abc1234` a revisión previa; cleanup `/tmp` fixture; restart de `payment-gateway` pod fixture con señal memory-leak y precondición de réplica saludable; y scale temporal del deployment fixture 2→4→2 bajo umbral de requests. Cada acción tiene selector/efecto reversible/timeout/receipt `operationId,target,beforeRevision,afterRevision`; L3 rollback exige aprobación humana por incidente. L4 no usa aprobación humana por incidente: OPA la preautoriza únicamente si el ActionPlan digest coincide con el catálogo versionado, entorno sandbox, precondiciones y límites definidos; fuera de ese caso falla cerrado y escala. Persistir reserva atómica única `(incidentId, actionDigest)` con estados `reserved → external_write_started → receipt_recorded|failed`; el fake GitOps devuelve operationId/revision/target y la recuperación consulta ese operationId antes de repetir. Repetir preflight y emitir telemetría ABI. No aceptar aprobación libre ni bypass de UI/LLM.
  Parallelization: Wave 1, Sesión C | Blocked by: 1 | Blocks: 9, 10
  References (executor has NO interview context - be exhaustive): documento adjunto §4–5; [Kubernetes RBAC good practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/); contratos de todo 1.
  Acceptance criteria (agent-executable): OPA permite rollback L3 sólo con aprobación y L4 sólo con preautorización de catálogo/digest sandbox para los limpieza `/tmp`, restart y scale allowlisted; deniega target, digest, campos canónicos, issuer/rol, TTL, replay y evidencia insuficiente; tests cubren allow/deny/recovery para rollback, restart y scale; broker prueba submit paralelo y crash después de write antes de receipt, luego recupera por operationId sin segundo write y emite auditoría.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/policy test`; failure `pnpm --filter @sre/policy test -- --testNamePattern=denies-invalid-approval`; Evidence `.omo/evidence/task-7-agente-ia-sre-hackathon.json`.
  Commit: Y | feat(safety): enforce approval-bound remediation policy

- [ ] 8. Construir agente Slack contextual, tarjeta nativa y aprobación L3
  What to do / Must NOT do: En `apps/channel/**`, configurar CopilotKit Channels, `read_thread`, `incident_card` y aprobar/rechazar. La card muestra evidencia con origen `thread|tool|rag`, hipótesis, blast radius, acción/digest, ALLOW/DENY y SANDBOX; incorpora el mensaje de rollback previo fallido y explica cómo cambia la recomendación. No crear web/móvil ni leer otros canales.
  Parallelization: Wave 1, Sesión C | Blocked by: 1 | Blocks: 10, 13
  References: `hackathon-overview.md`; `using-sponsor-tools.md`; documento adjunto §4/6.
  Acceptance criteria: harness Channels prueba `read_thread`, render de `incident_card`, DENY sin digest y pérdida de recomendación al eliminar contexto del hilo.
  QA scenarios: happy `pnpm --filter @sre/channel test -- --testNamePattern="reads incident thread"`; failure `pnpm --filter @sre/channel test -- --testNamePattern="blocks action without digest"`; Evidence `.omo/evidence/task-8-agente-ia-sre-hackathon.json`.
  Commit: Y | feat(slack): add contextual incident channel
- [ ] 9. Añadir postcheck, escalamiento y generador de postmortem desde journal
  What to do / Must NOT do: Implementar observación configurable de SLO, `resolved` sólo con métricas saludables, `needs_human_intervention` ante timeout/fallo y eventos ABI de postcheck; generar postmortem desde eventos persistidos. No iniciar otra mutación automáticamente.
  Parallelization: Wave 1, Sesión C | Blocked by: 1, 7 | Blocks: 10
  References (executor has NO interview context - be exhaustive): documento adjunto §3, §4 y §6; contratos de todo 1.
  Acceptance criteria (agent-executable): fixture saludable concluye resolved y postmortem con timestamps; fixture rojo tras rollback escala y prueba que contador de writes queda en uno.
  QA scenarios (name the exact tool + invocation): happy `pnpm --filter @sre/action-broker test -- --testNamePattern=verifies-recovery`; failure `pnpm --filter @sre/action-broker test -- --testNamePattern=escalates-after-failed-mitigation`; Evidence `.omo/evidence/task-9-agente-ia-sre-hackathon.json`.
  Commit: Y | feat(recovery): add postcheck escalation and postmortems

- [ ] 10. Integrar flujo E2E, adaptadores y tres PRs de trabajo
  What to do / Must NOT do: En `codex/sre-integration`, conectar gateway, herramientas, motor, policy, broker, UI y postcheck; asegurar que los tres PRs partan del SHA contractual y se fusionen sin conflictos de propiedad. No refactorizar internals de las tres ramas salvo corrección mínima de interfaz documentada.
  Parallelization: Wave 2 | Blocked by: 2–9 | Blocks: 11–12
  References (executor has NO interview context - be exhaustive): matriz de ejecución de este plan; contratos de todo 1; PRs `codex/sre-core`, `codex/sre-intelligence`, `codex/sre-slack-safety`.
  Acceptance criteria (agent-executable): una alerta completa finaliza con causalidad, acción propuesta, aprobación, un recibo GitOps y postcheck; verificación de integración contra las tres implementaciones.
  QA scenarios (name the exact tool + invocation): happy `pnpm test:e2e -- --grep "504 causal rollback"`; failure `pnpm test:e2e -- --grep "network hypothesis refuted"`; Evidence `.omo/evidence/task-10-agente-ia-sre-hackathon.json`.
  Commit: Y | feat(integration): compose AI SRE incident workflow

- [ ] 11. Ejecutar suite de seguridad adversarial y deduplicación
  What to do / Must NOT do: Automatizar inyección de prompt malicioso en log/RAG, herramientas no autorizadas, alerta duplicada, doble aprobación, aprobación expirada, observabilidad caída y mitigación ineficaz. No marcar como éxito sólo porque la UI dibuja un mensaje.
  Parallelization: Wave 2 | Blocked by: 2–10 | Blocks: F1–F4
  References (executor has NO interview context - be exhaustive): documento adjunto §4; MCP Tools security considerations; OPA/broker de todo 7.
  Acceptance criteria (agent-executable): evidencia afirma cero writes para cada DENY, un único recibo para duplicados y `needs_human_intervention` para outage/fallo; cada assertion lee journal y contador del broker.
  QA scenarios (name the exact tool + invocation): happy `pnpm demo:verify --scenario happy`; failure `pnpm demo:verify --scenario prompt-injection --scenario duplicate --scenario observability-outage --scenario failed-mitigation`; Evidence `.omo/evidence/task-11-agente-ia-sre-hackathon.json`.
  Commit: Y | test(safety): cover hostile incident scenarios

- [ ] 12. Empaquetar demo reproducible y documentación de operación
  What to do / Must NOT do: Crear compose/devcontainer, seeds, implementación de `scripts/demo/**` invocada por los entrypoints congelados de Wave 0, arquitectura, runbook de demo, publicar el threat model iniciado en todo 1/7 y métricas de evaluación del corpus; documentar versiones/prerrequisitos Docker/Node/pnpm/Postgres/OPA/Playwright y enlazar dashboard/journal/postmortem. No incluir secretos, pasos manuales ocultos ni afirmaciones de integración productiva.
  Parallelization: Wave 2 | Blocked by: 2–11 | Blocks: F1–F4
  References (executor has NO interview context - be exhaustive): documento adjunto §5–6; artefactos de todos 1–11.
  Acceptance criteria (agent-executable): entorno limpio instala versiones fijadas, inicia dependencias y ejecuta `pnpm bootstrap && pnpm demo:seed && pnpm demo:run --offline && pnpm demo:verify`; documentación coincide con artefactos y reporta sandbox/reloj lógico.
  QA scenarios (name the exact tool + invocation): happy `pnpm demo:run`; failure `pnpm demo:run --offline --scenario missing-metrics`; Evidence `.omo/evidence/task-12-agente-ia-sre-hackathon.log`.
  Commit: Y | docs(demo): package reproducible AI SRE showcase

- [ ] 13. Preparar evidencia de elegibilidad, rúbrica y entrega de la hackathon
  What to do / Must NOT do: En `docs/submission/**` y `docs/demo/**`, preparar título ThreadSRE, descripción (SRE de guardia, hilo Slack, contexto indispensable: rollback previo), y una matriz explícita de los cuatro criterios: Core Requirements & Functionality→transcript/card/receipt; Innovation & Theme Alignment→explicación del contexto de hilo; Technical Execution & Integration→Slack/OpenAI/Channel y error/deny; Usefulness & Agentic Experience→acción explicable y control L3. Registrar elegibilidad: build nuevo durante el evento, core construido durante el evento, piezas heredadas separadas, sin resubmission; entregables: repo público, quickstart, vídeo 2 min, post social y campos URL. Validar Slack/OpenAI live con `.env` sólo si existen credenciales. No publicar, enviar, inventar timestamps ni asumir ciudad/fecha límite.
  Parallelization: Wave 2 | Blocked by: 8, 10–12 | Blocks: F1–F4
  References: `docs/hackathon-source/hackathon-overview.md`; `docs/hackathon-source/hackathon-rules.md`; `docs/hackathon-source/using-sponsor-tools.md`; fuentes originales `C:/Users/danie/Downloads/*.md`.
  Acceptance criteria: `pnpm submission:verify` falla individualmente si falta cualquiera de los cuatro criterios con su evidencia, cada regla de elegibilidad, repo/quickstart/vídeo/post/URL, disclosure heredado-evento, `pnpm dev:slack`, variables sin valores o placeholders; sin secrets marca `account-dependent` y offline pasa.
  QA scenarios: happy `pnpm submission:verify`; failure `pnpm submission:verify --fixture missing-context-explanation`; Evidence `.omo/evidence/task-13-agente-ia-sre-hackathon.json`.
  Commit: Y | docs(submission): prepare hackathon evidence
## Final verification wave

- [ ] F1. Plan compliance audit
  What to do / Must NOT do: Verificar que cada Must have y Must NOT have trace a uno o más todos y que todo archivo esté asignado a una única rama. No aceptar cobertura por descripción oral.
  Acceptance criteria: auditoría genera matriz requisito→todo→evidencia, confirma trece filas de todo y cuatro final-verifier rows, incluyendo evidencia de elegibilidad/rúbrica de todo 13, y falla por path overlap, archivo sin dueño o SHA contractual cambiado.
  QA scenarios: `node scripts/audit-plan.mjs .omo/plans/agente-ia-sre-hackathon.md`; fallo inducido con referencia faltante; Evidence `.omo/evidence/f1-plan-compliance.json`.
  Commit: N | n/a

- [ ] F2. Code quality review
  What to do / Must NOT do: Ejecutar lint, typecheck, tests y revisión de límites de módulos; rechazar `any`, secretos, accesos de escritura no mediados y duplicación de contratos.
  Acceptance criteria: `pnpm lint && pnpm typecheck && pnpm test` con salida cero y reporte estático.
  QA scenarios: happy comando completo; failure `pnpm --filter @sre/policy test -- --testNamePattern=denies-write-bypass`; Evidence `.omo/evidence/f2-quality.log`.
  Commit: N | n/a

- [ ] F3. Automated browser QA
  What to do / Must NOT do: Ejecutar la demo en harness de Slack/Channels, capturar alerta→evidencia→aprobación→rollback→recuperación y los estados DENY/escalación, incluyendo badge SANDBOX. No sustituir assertions visuales por grep.
  Acceptance criteria: harness Channels guarda transcript/capturas y journal verificable para happy, DENY, acción aprobada, badge SANDBOX y failed mitigation.
  QA scenarios: `pnpm --filter @sre/channel test -- --testNamePattern="incident card"`; failure `pnpm --filter @sre/channel test -- --testNamePattern="needs human intervention"`; Evidence `.omo/evidence/f3-manual-qa/`.
  Commit: N | n/a

- [ ] F4. Scope fidelity
  What to do / Must NOT do: Comparar entrega contra el documento adjunto y comprobar que no hay producción, autonomía general, tool arbitraria ni plataforma duplicada. No declarar L4 productivo.
  Acceptance criteria: checklist firmado por script inspecciona configuración/fixtures y todos los guardrails pasan.
  QA scenarios: `pnpm demo:verify --scenario scope-guardrails`; failure `pnpm demo:verify --scenario production-target`; Evidence `.omo/evidence/f4-scope.json`.
  Commit: N | n/a

## Commit strategy

- Preflight en `codex/sre-foundation`: `chore(contracts): scaffold workspace and freeze incident contracts` se fusiona primero a `develop`; después nacen `codex/sre-core`, `codex/sre-intelligence` y `codex/sre-slack-safety` desde ese SHA.
- Tres PRs de Wave 1, siempre desde worktrees aislados, sin commits cruzados: `codex/sre-core`, `codex/sre-intelligence` y `codex/sre-slack-safety`. Cada PR declara el SHA de contrato y sólo toca sus rutas propietarias.
- El integrador rebasa sobre `origin/develop` antes de abrir `codex/sre-integration`; su PR incluye sólo composición, E2E y documentación de integración.
- No hacer rebase de una rama compartida ni force-push. Fusionar PRs con checks verdes y conservar commits atómicos de feature + prueba directa.

## Success criteria

- En Slack, `read_thread` modifica la investigación: el agente cita el rollback previo fallido y muestra una `incident_card` nativa con resultado observable.
- La demo live usa OpenAI + CopilotKit Channels cuando hay credenciales; todas las pruebas se ejecutan offline sin secretos.
- El rollback narrativo no sucede sin aprobación L3 válida; L4 sólo ejecuta cleanup/restart/scale allowlisted en sandbox y falla cerrado.
- Se preparan los cuatro criterios oficiales y entregables con disclosure veraz; no se publica ni se asume el deadline local.
- Las 13 tareas y 4 verificaciones finales pasan sus checks y las tres ramas se integran sin overlap.