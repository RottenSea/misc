// Reads the changes the two Windows setup scripts apply, from the `Register-SetupItem` calls in
// their folders. Each call keeps its parameters on one line, so a line is enough to read one.

export interface SetupItem {
  id: string;
  title: string;
  description: string;
}

export interface SetupScript {
  /** The file to run, such as `1-Offline.ps1`. */
  file: string;
  /** The folder it loads its changes from. */
  folder: string;
  items: SetupItem[];
}

/** The scripts in the order they are run. Each loads every file in its folder. */
export const SCRIPTS = [
  { file: "1-Offline.ps1", folder: "offline" },
  { file: "2-Online.ps1", folder: "online" }
];

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
 * Each script with its changes, in the order it applies them: its folder's files sorted by name,
 * then the order they're registered in. A change outside both folders would never run, so it
 * throws.
 */
export function parseSetup(files: Record<string, string>): SetupScript[] {
  const scripts: SetupScript[] = SCRIPTS.map((script) => ({
    ...script,
    items: []
  }));
  for (const path of Object.keys(files).sort()) {
    const script = scripts.find(({ folder }) => path.startsWith(`${folder}/`));
    for (const line of files[path].split(/\r?\n/)) {
      if (!line.startsWith("Register-SetupItem ")) continue;
      const { values } = parameters(line);
      const id = required(values, "Id", line);
      if (!script) throw new Error(`${id} in ${path} is in no script's folder`);
      script.items.push({
        id,
        title: required(values, "Title", line),
        description: required(values, "Description", line)
      });
    }
  }
  return scripts;
}
