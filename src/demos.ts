// The demos, one entry per page in src/pages/: the list on the home page reads it.

export interface Demo {
  name: string;
  /** The page's path under the site's base, with a trailing slash. */
  path: string;
  summary: string;
}

export const DEMOS: Demo[] = [
  {
    name: "Calculator",
    path: "calculator/",
    summary: "A basic calculator that takes keyboard input."
  },
  {
    name: "Working mark",
    path: "working-mark/",
    summary: "Six working states, each with an entrance, a loop and an exit."
  },
  {
    name: "Windows Animation Disabler",
    path: "windows-animation-disabler/",
    summary:
      "A Windhawk mod that turns off chosen taskbar and shell animations in Windows 11."
  }
];
