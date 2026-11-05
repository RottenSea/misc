import { defineConfig } from "astro/config";

export default defineConfig({
  // A project site on GitHub Pages, so every page sits under /misc/.
  site: "https://rottensea.github.io",
  base: "/misc",
  // The CSS goes into the page, so the first paint needs only the HTML.
  build: { inlineStylesheets: "always" },
  // The personal website's sites use 4173 to 4175, the design-system docs 4321 and 4322.
  server: { port: 4176 }
});
