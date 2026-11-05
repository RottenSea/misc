// The calculator's state and keys, without the page: each key takes a state and returns the next.

export type Operator = "+" | "-" | "×" | "÷";

export interface State {
  /** What the display shows, as typed or formatted. */
  display: string;
  /** The left operand, kept while an operator waits for the right one. */
  stored: number | null;
  operator: Operator | null;
  /** The next digit starts a new number instead of extending the display. */
  fresh: boolean;
  /** The last operation, so pressing = again repeats it. */
  repeat: { operator: Operator; operand: number } | null;
  error: boolean;
}

/** Digits the display takes before it stops accepting more. */
export const MAX_DIGITS = 12;

export const initial: State = {
  display: "0",
  stored: null,
  operator: null,
  fresh: true,
  repeat: null,
  error: false
};

/**
 * Rounds to 12 significant digits, so 0.1 + 0.2 shows 0.3 rather than the binary leftover. Very
 * large or very small results switch to exponent form.
 */
export function format(value: number): string {
  if (!Number.isFinite(value)) return "Error";
  if (value === 0) return "0";
  const size = Math.abs(value);
  if (size >= 10 ** MAX_DIGITS || size < 1e-9) {
    const [mantissa, exponent] = value.toExponential(6).split("e");
    return `${trimZeros(mantissa)}e${exponent}`;
  }
  return String(Number(value.toPrecision(MAX_DIGITS)));
}

function trimZeros(number: string): string {
  return number.includes(".") ? number.replace(/\.?0+$/, "") : number;
}

export function calculate(
  left: number,
  operator: Operator,
  right: number
): number {
  switch (operator) {
    case "+":
      return left + right;
    case "-":
      return left - right;
    case "×":
      return left * right;
    case "÷":
      return right === 0 ? Number.NaN : left / right;
  }
}

function value(state: State): number {
  return Number(state.display);
}

/** Shows a result, or the error state when there is no number to show. */
function show(state: State, result: number): State {
  const display = format(result);
  if (display === "Error") return { ...initial, display, error: true };
  return { ...state, display, fresh: true };
}

export function digit(state: State, key: string): State {
  const current = state.error ? initial : state;
  if (current.fresh) return { ...current, display: key, fresh: false };
  if (current.display.replace(/[-.]/g, "").length >= MAX_DIGITS) return current;
  const display =
    current.display === "0"
      ? key
      : current.display === "-0"
        ? `-${key}`
        : current.display + key;
  return { ...current, display };
}

export function point(state: State): State {
  const current = state.error ? initial : state;
  if (current.fresh) return { ...current, display: "0.", fresh: false };
  if (current.display.includes(".")) return current;
  return { ...current, display: `${current.display}.` };
}

export function operator(state: State, next: Operator): State {
  if (state.error) return state;
  // A second operator in a row only replaces the first.
  if (state.operator && state.fresh) return { ...state, operator: next };
  if (state.operator && state.stored !== null) {
    const result = show(
      state,
      calculate(state.stored, state.operator, value(state))
    );
    if (result.error) return result;
    return { ...result, stored: value(result), operator: next, repeat: null };
  }
  return {
    ...state,
    stored: value(state),
    operator: next,
    fresh: true,
    repeat: null
  };
}

export function equals(state: State): State {
  if (state.error) return state;
  if (state.operator && state.stored !== null) {
    const operand = value(state);
    const result = show(
      state,
      calculate(state.stored, state.operator, operand)
    );
    if (result.error) return result;
    return {
      ...result,
      stored: null,
      operator: null,
      repeat: { operator: state.operator, operand }
    };
  }
  if (state.repeat)
    return show(
      state,
      calculate(value(state), state.repeat.operator, state.repeat.operand)
    );
  return { ...state, fresh: true };
}

/** Divides the number on the display by 100. */
export function percent(state: State): State {
  if (state.error) return state;
  return show(state, value(state) / 100);
}

export function negate(state: State): State {
  if (state.error) return state;
  // Before a new number, the sign goes on a new 0 so the user can type a negative number.
  if (state.fresh && (state.operator || state.display === "0"))
    return { ...state, display: "-0", fresh: false };
  const display = state.display.startsWith("-")
    ? state.display.slice(1)
    : `-${state.display}`;
  return { ...state, display };
}

export function clear(): State {
  return initial;
}

export function backspace(state: State): State {
  if (state.error) return initial;
  if (state.fresh) return state;
  const display = state.display.slice(0, -1);
  if (display === "" || display === "-")
    return { ...state, display: "0", fresh: true };
  return { ...state, display };
}

/** The line above the display: the left operand and the waiting operator. */
export function expression(state: State): string {
  if (state.operator === null || state.stored === null) return "";
  return `${format(state.stored)} ${state.operator}`;
}

export type Key =
  | { type: "digit"; value: string }
  | { type: "point" }
  | { type: "operator"; value: Operator }
  | { type: "equals" }
  | { type: "percent" }
  | { type: "negate" }
  | { type: "clear" }
  | { type: "backspace" };

export function press(state: State, key: Key): State {
  switch (key.type) {
    case "digit":
      return digit(state, key.value);
    case "point":
      return point(state);
    case "operator":
      return operator(state, key.value);
    case "equals":
      return equals(state);
    case "percent":
      return percent(state);
    case "negate":
      return negate(state);
    case "clear":
      return clear();
    case "backspace":
      return backspace(state);
  }
}

const KEYBOARD: Record<string, Key> = {
  ".": { type: "point" },
  ",": { type: "point" },
  "+": { type: "operator", value: "+" },
  "-": { type: "operator", value: "-" },
  "*": { type: "operator", value: "×" },
  x: { type: "operator", value: "×" },
  "/": { type: "operator", value: "÷" },
  "=": { type: "equals" },
  Enter: { type: "equals" },
  "%": { type: "percent" },
  Escape: { type: "clear" },
  Delete: { type: "clear" },
  Backspace: { type: "backspace" }
};

/** The calculator key for a keyboard key, or null when it has none. */
export function keyFor(name: string): Key | null {
  if (/^[0-9]$/.test(name)) return { type: "digit", value: name };
  return KEYBOARD[name] ?? null;
}
