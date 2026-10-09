import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // A plain folder of HTML (out/) that the server's nginx serves: no Node
  // server in production (see deploy/README.md).
  output: "export",
  trailingSlash: true,
  // pictures are already sized; a static site has no image optimizer
  images: { unoptimized: true },
};

export default nextConfig;
