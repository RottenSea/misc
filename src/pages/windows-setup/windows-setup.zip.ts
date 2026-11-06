// The download: every file of the script under a windows-setup/ folder, with Windows line endings.
import type { APIRoute } from "astro";
import { FILES } from "../../scripts/windows-setup-files.ts";
import { zip } from "../../scripts/zip.ts";

export const GET: APIRoute = () => {
  const encoder = new TextEncoder();
  const archive = zip(
    Object.keys(FILES)
      .sort()
      .map((name) => ({
        name: `windows-setup/${name}`,
        data: encoder.encode(FILES[name].replace(/\r?\n/g, "\r\n"))
      }))
  );
  return new Response(archive, {
    headers: { "Content-Type": "application/zip" }
  });
};
