# misc

Small demos and tools, published at <https://rottensea.github.io/misc/>.

Each demo is one page in `src/pages/`, with an entry in the list on `src/pages/index.astro`. The site is built with Astro and uses the personal website's design system. Pushing to `main` deploys it on GitHub Pages.

A page's static files sit in `public/<page>/`. The Windows Animation Disabler page offers its Windhawk mod for download from there, and builds its text and settings list from that same source file, so to update the mod, replace the file.

```sh
pnpm install
pnpm dev     # http://localhost:4176/misc/
pnpm check   # Biome and astro check
pnpm test    # node --test
```
