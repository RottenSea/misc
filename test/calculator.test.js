// The calculator's keys, pressed in order from a cleared state.
import assert from "node:assert/strict";
import { test } from "node:test";
import {
  expression,
  format,
  initial,
  keyFor,
  press
} from "../src/scripts/calculator.ts";

/** Presses each character as its keyboard key and returns the final state. */
function type(keys) {
  let state = initial;
  for (const name of keys.match(/Backspace|Escape|Enter|n|./g)) {
    const key = name === "n" ? { type: "negate" } : keyFor(name);
    assert.ok(key, `no key for ${name}`);
    state = press(state, key);
  }
  return state;
}

test("adds, subtracts, multiplies and divides", () => {
  assert.equal(type("12+30=").display, "42");
  assert.equal(type("5-8=").display, "-3");
  assert.equal(type("6*7=").display, "42");
  assert.equal(type("1/4=").display, "0.25");
});

test("shows 0.1 + 0.2 as 0.3", () => {
  assert.equal(type("0.1+0.2=").display, "0.3");
  assert.equal(type("1.1*3=").display, "3.3");
  assert.equal(type("1/3=").display, "0.333333333333");
});

test("chains operators from left to right", () => {
  const state = type("2+3*");
  assert.equal(state.display, "5");
  assert.equal(expression(state), "5 ×");
  assert.equal(type("2+3*4=").display, "20");
});

test("a second operator replaces the first", () => {
  assert.equal(type("9+-4=").display, "5");
});

test("pressing = again repeats the last operation", () => {
  assert.equal(type("2+3===").display, "11");
});

test("divides by 100 with %", () => {
  assert.equal(type("50%").display, "0.5");
});

test("changes the sign", () => {
  assert.equal(type("5n").display, "-5");
  assert.equal(type("5nn").display, "5");
  assert.equal(type("n5").display, "-5");
  assert.equal(type("3*n2=").display, "-6");
});

test("keeps one decimal point", () => {
  assert.equal(type(".5").display, "0.5");
  assert.equal(type("1..2").display, "1.2");
});

test("deletes the last digit with Backspace", () => {
  assert.equal(type("123Backspace").display, "12");
  assert.equal(type("1Backspace").display, "0");
  assert.equal(type("12+3=Backspace").display, "15");
});

test("clears everything with Escape", () => {
  assert.deepEqual(type("12+3Escape"), initial);
});

test("shows an error for division by zero and starts over on the next digit", () => {
  assert.equal(type("5/0=").display, "Error");
  assert.equal(type("5/0=7").display, "7");
});

test("stops at 12 digits", () => {
  assert.equal(type("1234567890123").display, "123456789012");
});

test("switches very large and very small results to exponent form", () => {
  assert.equal(format(123456789012 * 1000), "1.234568e+14");
  assert.equal(format(1e-12), "1e-12");
  assert.equal(format(-0), "0");
});

test("ignores keys it has no use for", () => {
  assert.equal(keyFor("a"), null);
  assert.equal(keyFor("Shift"), null);
});
