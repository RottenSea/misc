// Working mark's frames: which sprite and which frame of it shows at a given time.

export const ACTIONS = [
  "think",
  "write",
  "code",
  "read",
  "search",
  "compose"
] as const;
export const PHASES = ["in", "loop", "out"] as const;

export type Action = (typeof ACTIONS)[number];
export type Phase = (typeof PHASES)[number];

/** One sprite strip played once: an action in one phase. */
export interface Step {
  action: Action;
  phase: Phase;
}

/** Each frame shows for a thirtieth of a second. */
export const FRAME_MS = 1000 / 30;

/** How many frames each strip in public/working-mark/ holds, stacked top to bottom. */
export const FRAMES: Record<Action, Record<Phase, number>> = {
  think: { in: 16, loop: 110, out: 15 },
  write: { in: 31, loop: 60, out: 14 },
  code: { in: 16, loop: 75, out: 9 },
  read: { in: 21, loop: 60, out: 19 },
  search: { in: 16, loop: 20, out: 14 },
  compose: { in: 16, loop: 62, out: 12 }
};

export function frames(step: Step): number {
  return FRAMES[step.action][step.phase];
}

/** The strip's file name, without the folder. */
export function sprite(step: Step): string {
  return `${step.action}_${step.phase}.webp`;
}

/** The steps played over and over, one after another, and where they are `elapsed` ms in. */
export function frameAt(
  steps: readonly Step[],
  elapsed: number
): { step: Step; frame: number } {
  const total = steps.reduce((sum, step) => sum + frames(step), 0);
  let left = Math.floor(Math.max(0, elapsed) / FRAME_MS) % total;
  for (const step of steps) {
    const count = frames(step);
    if (left < count) return { step, frame: left };
    left -= count;
  }
  // Not reached: left is always below the total.
  return { step: steps[0], frame: 0 };
}

/** The frame shown when motion is reduced: the end of the first step, so the mark has arrived. */
export function stillFrame(steps: readonly Step[]): {
  step: Step;
  frame: number;
} {
  const step = steps[0];
  return { step, frame: frames(step) - 1 };
}

/** One action's phases in the given order, such as in, loop, loop, out. */
export function sequence(action: Action, phases: readonly Phase[]): Step[] {
  return phases.map((phase) => ({ action, phase }));
}

/** Every action entering, looping once and leaving, one after another. */
export const CYCLE: Step[] = ACTIONS.flatMap((action) =>
  sequence(action, PHASES)
);
