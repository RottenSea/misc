// Reads the groups and changes the Windows setup script registers, from the
// `Register-SetupGroup` and `Register-SetupItem` calls in its files. Each call keeps its
// parameters on one line, so a line is enough to read one.

export interface SetupItem {
  id: string;
  group: string;
  title: string;
  description: string;
  /** Runs in the elevated window. */
  admin: boolean;
}

export interface SetupGroup {
  id: string;
  title: string;
  description: string;
  /** Applied unless the reader says no; the other groups are asked about. */
  byDefault: boolean;
  items: SetupItem[];
}

/** The `-Name 'value'` and bare `-Switch` parameters of one call. */
function parameters(line: string): {
  values: Record<string, string>;
  switches: Set<string>;
} {
  const values: Record<string, string> = {};
  const switches = new Set<string>();
  for (const match of line.matchAll(/-(\w+)(?:\s+'((?:[^']|'')*)')?/g)) {
    if (match[2] === undefined) switches.add(match[1]);
    // PowerShell writes a quote inside a single-quoted string as two.
    else values[match[1]] = match[2].replaceAll("''", "'");
  }
  return { values, switches };
}

function required(
  values: Record<string, string>,
  name: string,
  line: string
): string {
  const value = values[name];
  if (value === undefined) throw new Error(`No -${name} in: ${line}`);
  return value;
}

/**
 * The groups in the order of their files, sorted by path as the script loads them, each with its
 * changes in the order they're registered.
 */
export function parseSetup(files: Record<string, string>): SetupGroup[] {
  const groups: SetupGroup[] = [];
  const items: SetupItem[] = [];
  for (const path of Object.keys(files).sort()) {
    for (const line of files[path].split(/\r?\n/)) {
      if (line.startsWith("Register-SetupGroup ")) {
        const { values, switches } = parameters(line);
        groups.push({
          id: required(values, "Id", line),
          title: required(values, "Title", line),
          description: required(values, "Description", line),
          byDefault: switches.has("Default"),
          items: []
        });
      } else if (line.startsWith("Register-SetupItem ")) {
        const { values, switches } = parameters(line);
        items.push({
          id: required(values, "Id", line),
          group: required(values, "Group", line),
          title: required(values, "Title", line),
          description: required(values, "Description", line),
          admin: switches.has("Admin")
        });
      }
    }
  }
  for (const item of items) {
    const group = groups.find(({ id }) => id === item.group);
    if (!group)
      throw new Error(`${item.id} is in an unknown group, ${item.group}`);
    group.items.push(item);
  }
  return groups;
}
