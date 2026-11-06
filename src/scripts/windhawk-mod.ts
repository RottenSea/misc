// Reads a Windhawk mod's source: the metadata header, the readme and the settings, each in its own
// comment block, as described at https://github.com/ramensoftware/windhawk/wiki/Creating-a-new-mod.

export interface ModSource {
  /** Each `// @key value` line of the header. Keys such as `include` repeat, so every value is kept. */
  metadata: Record<string, string[]>;
  /** The readme's Markdown. */
  readme: string;
  settings: Setting[];
}

/** One entry of the settings block: an option with a default, or a group of options. */
export interface Setting {
  key: string;
  /** The default value as written; absent for a group. */
  value?: string;
  name?: string;
  description?: string;
  children: Setting[];
}

/** The text between `// ==Name==` and `// ==/Name==`, with the `/* ... *\/` around it removed. */
function block(source: string, name: string): string {
  const match = new RegExp(
    `// ==${name}==\\r?\\n([\\s\\S]*?)// ==/${name}==`
  ).exec(source);
  if (!match) throw new Error(`The mod has no ${name} block`);
  return match[1].replace(/^\/\*\r?\n?/, "").replace(/\*\/\s*$/, "");
}

function parseMetadata(text: string): Record<string, string[]> {
  const metadata: Record<string, string[]> = {};
  for (const line of text.split(/\r?\n/)) {
    const match = /^\/\/\s*@(\S+)\s+(.*?)\s*$/.exec(line);
    if (!match) continue;
    const values = metadata[match[1]] ?? [];
    values.push(match[2]);
    metadata[match[1]] = values;
  }
  return metadata;
}

const indentOf = (line: string) => line.length - line.trimStart().length;

/**
 * The settings block is YAML, but mods only use a small part of it: list items of `key: value`,
 * nested lists for groups, `$name` and `$description`, and folded (`>-`) text.
 */
function parseSettings(text: string): Setting[] {
  const lines = text
    .split(/\r?\n/)
    .filter((line) => line.trim() !== "" && !line.trim().startsWith("#"));
  let at = 0;

  // A value after "key:". Folded text runs on over the lines indented deeper than its key.
  const scalar = (rest: string, keyIndent: number): string => {
    const value = rest.trim();
    if (!/^[>|][-+]?$/.test(value))
      return value.replace(/^(["'])(.*)\1$/, "$2");
    const parts: string[] = [];
    while (at < lines.length && indentOf(lines[at]) > keyIndent)
      parts.push(lines[at++].trim());
    return parts.join(value.startsWith(">") ? " " : "\n");
  };

  const items = (indent: number): Setting[] => {
    const found: Setting[] = [];
    while (
      at < lines.length &&
      indentOf(lines[at]) === indent &&
      lines[at].trimStart().startsWith("- ")
    ) {
      const head = /^([^:]+):\s*(.*)$/.exec(lines[at++].trimStart().slice(2));
      if (!head) continue;
      const inner = indent + 2;
      const setting: Setting = { key: head[1].trim(), children: [] };
      if (head[2].trim() !== "") setting.value = scalar(head[2], inner);
      while (at < lines.length && indentOf(lines[at]) >= inner) {
        const line = lines[at].trimStart();
        if (indentOf(lines[at]) === inner && line.startsWith("- ")) {
          setting.children.push(...items(inner));
          continue;
        }
        at++;
        const property = /^\$(\w+):\s*(.*)$/.exec(line);
        if (!property) continue;
        const value = scalar(property[2], inner);
        if (property[1] === "name") setting.name = value;
        if (property[1] === "description") setting.description = value;
      }
      found.push(setting);
    }
    return found;
  };

  return items(lines.length ? indentOf(lines[0]) : 0);
}

export function parseMod(source: string): ModSource {
  return {
    metadata: parseMetadata(block(source, "WindhawkMod")),
    readme: block(source, "WindhawkModReadme").trim(),
    settings: parseSettings(block(source, "WindhawkModSettings"))
  };
}

/** A default value as the settings page would show it. */
export function describeValue(value: string): string {
  if (value === "true") return "On";
  if (value === "false") return "Off";
  return value;
}
