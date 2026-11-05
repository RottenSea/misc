// Searching the demo list.
import assert from "node:assert/strict";
import { test } from "node:test";
import { search } from "../src/scripts/search.ts";

const DEMOS = [
  { name: "Calculator", path: "calculator/", summary: "Adds and divides." },
  {
    name: "Working mark",
    path: "working-mark/",
    summary: "States with a loop."
  }
];

test("lists every demo for an empty query", () => {
  assert.deepEqual(
    search(DEMOS, "  ", "/misc/").map(({ title }) => title),
    ["Calculator", "Working mark"]
  );
});

test("finds a demo by its name or summary, in any case", () => {
  assert.deepEqual(
    search(DEMOS, "CALC", "/misc/").map(({ href }) => href),
    ["/misc/calculator/"]
  );
  assert.deepEqual(
    search(DEMOS, "loop", "/misc/").map(({ title }) => title),
    ["Working mark"]
  );
});

test("needs every word to match", () => {
  assert.equal(search(DEMOS, "working divides", "/misc/").length, 0);
});

test("marks the matching words in the summary", () => {
  assert.equal(
    search(DEMOS, "adds", "/misc/")[0].excerpt,
    "<mark>Adds</mark> and divides."
  );
});

test("treats regular-expression characters as text", () => {
  assert.equal(search(DEMOS, "(", "/misc/").length, 0);
});
