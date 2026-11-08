// Reading the Windows setup scripts, which the Windows setup page is built from, and the zip it's
// offered in.
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { test } from "node:test";
import { inflateRawSync } from "node:zlib";
import { parseSetup } from "../src/scripts/windows-setup.ts";
import { crc32, zip } from "../src/scripts/zip.ts";

const root = new URL("../src/windows-setup/", import.meta.url);
const files = Object.fromEntries(
  readdirSync(root, { recursive: true })
    .map((path) => path.replaceAll("\\", "/"))
    .filter((path) => /\.(ps1|txt)$/.test(path))
    .map((path) => [path, readFileSync(new URL(path, root), "utf8")])
);
const scripts = parseSetup(files);
const ids = (file) =>
  scripts.find((script) => script.file === file).items.map(({ id }) => id);

test("reads the two scripts in the order they are run", () => {
  assert.deepEqual(
    scripts.map(({ file }) => file),
    ["1-Offline.ps1", "2-Online.ps1"]
  );
  for (const { file } of scripts) assert.ok(files[file], file);
});

test("turns off UAC first, before going online", () => {
  assert.equal(ids("1-Offline.ps1")[0], "uac");
  assert.ok(!ids("2-Online.ps1").includes("uac"));
});

test("keeps the developer environment for after going online", () => {
  assert.deepEqual(ids("2-Online.ps1"), [
    "scoop",
    "node",
    "git-long-paths",
    "pi-agent",
    "github-login"
  ]);
  assert.ok(!ids("1-Offline.ps1").includes("classic-outlook"));
});

test("every change has a unique id and text to show", () => {
  const items = scripts.flatMap(({ items }) => items);
  assert.equal(new Set(items.map(({ id }) => id)).size, items.length);
  for (const item of items) {
    assert.ok(item.title.length > 0, item.id);
    assert.ok(item.description.length > 0, item.id);
  }
});

test("turns a doubled quote back into one", () => {
  const [offline] = parseSetup({
    "offline/a.ps1":
      "Register-SetupItem -Id 'i' -Title 'Don''t' -Description 'It''s here.' -Action {"
  });
  assert.equal(offline.items[0].title, "Don't");
  assert.equal(offline.items[0].description, "It's here.");
});

test("rejects a change in no script's folder", () => {
  assert.throws(() =>
    parseSetup({
      "items/a.ps1":
        "Register-SetupItem -Id 'i' -Title 't' -Description 'd' -Action {"
    })
  );
});

test("crc32 matches the standard check value", () => {
  assert.equal(crc32(new TextEncoder().encode("123456789")), 0xcbf43926);
});

test("a zip entry inflates back to its data", () => {
  const data = new TextEncoder().encode("Write-Host 'hello'\r\n".repeat(20));
  const archive = zip([{ name: "windows-setup/1-Offline.ps1", data }]);
  const view = new DataView(archive.buffer);
  assert.equal(view.getUint32(0, true), 0x04034b50);
  const nameLength = view.getUint16(26, true);
  const size = view.getUint32(18, true);
  const start = 30 + nameLength;
  const inflated = inflateRawSync(archive.subarray(start, start + size));
  assert.deepEqual(new Uint8Array(inflated), data);
  // The end record counts one entry.
  const end = new DataView(archive.buffer, archive.length - 22);
  assert.equal(end.getUint32(0, true), 0x06054b50);
  assert.equal(end.getUint16(10, true), 1);
});
