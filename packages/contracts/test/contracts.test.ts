import { describe, expect, it } from "vitest";

import {
  actionPlanSchema,
  digestActionPlan,
  normalizeDatadogWebhook,
  normalizeZabbixWebhook,
} from "../src/index.js";

const zabbixWebhook = {
  eventId: "9001",
  eventTime: "2026-09-12T12:00:00.000Z",
  host: "zabbix-cpu-simulator",
  itemKey: "system.cpu.util",
  itemValue: "96.2",
  severity: 4,
  triggerName: "High CPU utilization",
};

const datadogWebhook = {
  alertId: "dd-7001",
  alertQuery: "avg(last_5m):avg:system.cpu.user{host:zabbix-cpu-simulator} > 90",
  alertTransition: "Triggered",
  eventMessage: "CPU sustained above 90 percent",
  eventTitle: "CPU monitor alert",
  tags: ["host:zabbix-cpu-simulator", "service:zabbix"],
};

describe("frozen incident contracts", () => {
  it("round-trips Zabbix and Datadog webhooks to IncidentEnvelope v1", () => {
    const zabbix = normalizeZabbixWebhook(zabbixWebhook);
    const datadog = normalizeDatadogWebhook(datadogWebhook, "2026-09-12T12:00:00.000Z");

    expect(zabbix).toMatchObject({ source: "zabbix", severity: 5 });
    expect(datadog).toMatchObject({ source: "datadog", severity: 4 });
    expect(zabbix.dedupKey).toHaveLength(64);
    expect(datadog.dedupKey).toHaveLength(64);
  });

  it("rejects malformed webhook fixture", () => {
    expect(() => normalizeZabbixWebhook({ ...zabbixWebhook, severity: 9 })).toThrow();
  });

  it("creates a deterministic digest from canonical ActionPlan JSON", () => {
    const action = actionPlanSchema.parse({
      action: "simulator.stop-cpu-load",
      blastRadius: "single container zabbix-cpu-simulator",\n      command: "docker exec zabbix-cpu-simulator pkill -f 'stress-ng --cpu'",
      evidenceRefs: ["e-1"],
      expiresAt: "2026-09-12T12:10:00.000Z",
      policyVersion: "v1",
      preconditions: ["CPU alert is active"],
      proposedAt: "2026-09-12T12:00:00.000Z",
      rollback: "Reapply CPU load manually with scripts/set-cpu-load.sh.",
      target: "zabbix-cpu-simulator"
    });

    expect(digestActionPlan(action)).toBe(digestActionPlan({ ...action, evidenceRefs: ["e-1"] }));
  });
});
