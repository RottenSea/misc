// Reading the Windhawk mod's source, which the Windows Animation Disabler page is built from.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { describeValue, parseMod } from "../src/scripts/windhawk-mod.ts";

const MOD = "windows-animation-disabler";
const source = readFileSync(
  new URL(`../public/${MOD}/${MOD}.wh.cpp`, import.meta.url),
  "utf8"
);
const mod = parseMod(source);

test("the file is named after the mod's id", () => {
  assert.deepEqual(mod.metadata.id, [MOD]);
});

test("keeps every value of a repeated metadata key", () => {
  assert.deepEqual(mod.metadata.include, [
    "explorer.exe",
    "StartMenuExperienceHost.exe",
    "ShellExperienceHost.exe",
    "ShellHost.exe",
    "SearchHost.exe"
  ]);
  assert.equal(mod.metadata.version.length, 1);
});

test("reads the readme without the comment markers", () => {
  assert.match(mod.readme, /^# Windows Animation Disabler\n/);
  assert.doesNotMatch(mod.readme, /\*\/|\/\*/);
});

test("reads groups, their options and folded descriptions", () => {
  const taskbar = mod.settings.find(({ key }) => key === "taskbar");
  assert.equal(taskbar.name, "Taskbar");
  assert.equal(taskbar.value, undefined);
  const [first] = taskbar.children;
  assert.equal(first.key, "disableAnimations");
  assert.equal(first.value, "true");
  assert.equal(first.name, "Disable taskbar and Task View animations");
  assert.match(
    first.description,
    /^Turns off the taskbar's own animations: opening/
  );
  assert.doesNotMatch(first.description, /\n| {2}/);
});

test("reads a group whose options have no description", () => {
  const flyouts = mod.settings.find(({ key }) => key === "shellFlyouts");
  assert.deepEqual(
    flyouts.children.map(({ key, value }) => [key, value]),
    [
      ["start", "true"],
      ["search", "true"],
      ["quickSettings", "true"],
      ["notificationCenter", "true"]
    ]
  );
});

test("reads a small settings block", () => {
  const small = `// ==WindhawkMod==
// @id a
// ==/WindhawkMod==
// ==WindhawkModReadme==
/*
# A
*/
// ==/WindhawkModReadme==
// ==WindhawkModSettings==
/*
- delay: 5
  $name: "Delay"
  $description: >-
    Two
    lines
- off: false
*/
// ==/WindhawkModSettings==
`;
  assert.deepEqual(parseMod(small).settings, [
    {
      key: "delay",
      value: "5",
      name: "Delay",
      description: "Two lines",
      children: []
    },
    { key: "off", value: "false", children: [] }
  ]);
});

test("shows switches as On and Off", () => {
  assert.equal(describeValue("true"), "On");
  assert.equal(describeValue("false"), "Off");
  assert.equal(describeValue("1"), "1");
});
