import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

const workspace = new URL("../../", import.meta.url);
const audit = new URL("./audit-plan.mjs", import.meta.url);
const plan = new URL("../../.omo/plans/agente-ia-sre-datadog.md", import.meta.url);
const manifest = new URL("./ownership-manifest.json", import.meta.url);

function invoke(manifestPath) {
  return execFileSync(process.execPath, [audit, plan, "--manifest", manifestPath], {
    cwd: workspace,
    encoding: "utf8"
  });
}

test("audit emits a compliance matrix for the plan", () => {
  const result = JSON.parse(invoke(manifest));
  assert.equal(result.status, "pass");
  assert.equal(result.todos.length, 16);
});

test("audit rejects ownership of a protected harness path", () => {
  const temporary = mkdtempSync(join(tmpdir(), "sre-audit-"));
  const candidate = join(temporary, "manifest.json");
  const altered = JSON.parse(readFileSync(manifest, "utf8"));
  altered.sessions[0].paths.push("README.md");
  writeFileSync(candidate, JSON.stringify(altered));

  try {
    assert.throws(() => invoke(candidate));
  } finally {
    rmSync(temporary, { force: true, recursive: true });
  }
});
