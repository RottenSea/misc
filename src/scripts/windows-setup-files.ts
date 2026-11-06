// The Windows setup script's files, keyed by their path inside src/windows-setup/. Both the page
// and the zip are built from them, so the page lists exactly what the download contains.

const raw: Record<string, string> = import.meta.glob("../windows-setup/**/*", {
  query: "?raw",
  import: "default",
  eager: true
});

export const FILES: Record<string, string> = Object.fromEntries(
  Object.entries(raw).map(([path, text]) => [
    path.replace("../windows-setup/", ""),
    text
  ])
);
