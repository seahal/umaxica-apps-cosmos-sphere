import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const [, , repository] = process.argv;
if (!repository) {
  throw new Error("Repository path is required");
}
const root = resolve(repository);
const directory = mkdtempSync(join(tmpdir(), "sphere-openapi-verify-"));
try {
  for (const api of ["app", "com", "org"]) {
    const output = join(directory, `openapi.${api}.yml`);
    execFileSync(
      join(root, "node_modules/.bin/redocly"),
      ["bundle", join(root, "openapi", `${api}.yml`), "--output", output],
      { cwd: root, stdio: "pipe" },
    );
    const expected = readFileSync(join(root, "openapi/bundled", `openapi.${api}.yml`));
    if (!expected.equals(readFileSync(output))) {
      throw new Error(`OpenAPI ${api} bundle is stale`);
    }
  }
  process.stdout.write("All three current bundles match isolated regeneration.\n");
} finally {
  rmSync(directory, { recursive: true, force: true });
}
