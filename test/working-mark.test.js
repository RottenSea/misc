// Which frame Working mark shows at a given time.
import assert from "node:assert/strict";
import { readdirSync } from "node:fs";
import { test } from "node:test";
import {
  ACTIONS,
  CYCLE,
  FRAME_MS,
  frameAt,
  PHASES,
  sequence,
  sprite,
  stillFrame
} from "../src/scripts/working-mark.ts";

const at = (frame) => frame * FRAME_MS + FRAME_MS / 2;

test("every strip has a sprite in public/working-mark/", () => {
  const files = new Set(
    readdirSync(new URL("../public/working-mark/", import.meta.url))
  );
  for (const action of ACTIONS) {
    for (const phase of PHASES) assert.ok(files.has(sprite({ action, phase })));
  }
});

test("plays one strip over and over", () => {
  const loop = sequence("search", ["loop"]);
  assert.deepEqual(frameAt(loop, at(0)).frame, 0);
  assert.deepEqual(frameAt(loop, at(19)).frame, 19);
  assert.deepEqual(frameAt(loop, at(20)).frame, 0);
});

test("moves on to the next step after the last frame", () => {
  const steps = sequence("code", ["in", "loop", "loop", "out"]);
  assert.deepEqual(frameAt(steps, at(15)), { step: steps[0], frame: 15 });
  assert.deepEqual(frameAt(steps, at(16)), { step: steps[1], frame: 0 });
  assert.deepEqual(frameAt(steps, at(16 + 75)), { step: steps[2], frame: 0 });
  assert.deepEqual(frameAt(steps, at(16 + 150 + 8)), {
    step: steps[3],
    frame: 8
  });
  assert.deepEqual(frameAt(steps, at(16 + 150 + 9)), {
    step: steps[0],
    frame: 0
  });
});

test("the cycle goes through every action in, loop and out", () => {
  assert.equal(CYCLE.length, 18);
  const thinking = 16 + 110 + 15;
  assert.deepEqual(frameAt(CYCLE, at(thinking)), {
    step: { action: "write", phase: "in" },
    frame: 0
  });
});

test("the still frame is the end of the first step", () => {
  assert.deepEqual(stillFrame(sequence("read", ["in"])).frame, 20);
});
