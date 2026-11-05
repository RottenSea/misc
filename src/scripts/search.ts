// Search over the demo list: every word of the query has to appear in a demo's name or summary.
import type { Demo } from "../demos.ts";

export interface Result {
  title: string;
  href: string;
  /** The summary, with each matching word in <mark>. */
  excerpt: string;
}

/** Escapes every character that is not a letter or digit, so the query matches as text. */
const escapeRegExp = (text: string) =>
  [...text]
    .map((char) => (/[\p{L}\p{N}]/u.test(char) ? char : `\\${char}`))
    .join("");

/** Every demo when the query is empty, else the ones that contain all of its words. */
export function search(
  demos: readonly Demo[],
  query: string,
  base: string
): Result[] {
  const words = query.toLowerCase().split(/\s+/).filter(Boolean);
  const found = demos.filter(({ name, summary }) => {
    const text = `${name} ${summary}`.toLowerCase();
    return words.every((word) => text.includes(word));
  });
  const pattern = words.length
    ? new RegExp(`(${words.map(escapeRegExp).join("|")})`, "gi")
    : null;
  return found.map(({ name, path, summary }) => ({
    title: name,
    href: `${base}${path}`,
    excerpt: pattern ? summary.replace(pattern, "<mark>$1</mark>") : summary
  }));
}
