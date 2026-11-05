import logo from "@rottensea/ds-personal-website/assets/logo-colored.svg?raw";

/** The tab icon: the design system's logo as it is, as on the personal website. */
export const GET = () =>
  new Response(logo, { headers: { "Content-Type": "image/svg+xml" } });
