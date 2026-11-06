// Reading the Windows setup script, which the Windows setup page is built from, and the zip it's
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
const groups = parseSetup(files);

test("reads the groups in the order the script loads them", () => {
  assert.deepEqual(
    groups.map(({ id }) => id),
    ["settings", "optimizations", "dev"]
  );
});

test("applies the guide's groups by default, not the developer environment", () => {
  assert.deepEqual(
    groups.map(({ byDefault }) => byDefault),
    [true, true, false]
  );
});

test("every change has a unique id and text to show", () => {
  const items = groups.flatMap(({ items }) => items);
  assert.equal(new Set(items.map(({ id }) => id)).size, items.length);
  for (const item of items) {
    assert.ok(item.title.length > 0, item.id);
    assert.ok(item.description.length > 0, item.id);
  }
});

test("marks the changes that need the admin window", () => {
  const settings = groups[0].items;
  assert.equal(settings.find(({ id }) => id === "long-paths")?.admin, true);
  assert.equal(
    settings.find(({ id }) => id === "mouse-acceleration")?.admin,
    false
  );
});

test("turns a doubled quote back into one", () => {
  const [group] = parseSetup({
    "a.ps1": [
      "Register-SetupGroup -Id 'g' -Title 'G' -Description 'It''s here.' -Default",
      "Register-SetupItem -Id 'i' -Group 'g' -Title 'Don''t' -Description 'x' -Action {"
    ].join("\n")
  });
  assert.equal(group.description, "It's here.");
  assert.equal(group.items[0].title, "Don't");
});

test("rejects a change in a group that doesn't exist", () => {
  assert.throws(() =>
    parseSetup({
      "a.ps1":
        "Register-SetupItem -Id 'i' -Group 'none' -Title 't' -Description 'd' -Action {"
    })
  );
});

test("crc32 matches the standard check value", () => {
  assert.equal(crc32(new TextEncoder().encode("123456789")), 0xcbf43926);
});

test("a zip entry inflates back to its data", () => {
  const data = new TextEncoder().encode("Write-Host 'hello'\r\n".repeat(20));
  const archive = zip([{ name: "windows-setup/Setup.ps1", data }]);
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
