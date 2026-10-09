import type { MetadataRoute } from "next";
import { site } from "@/lib/site";

// written once at build time (the site is a static export)
export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  return ["", "/privacy", "/terms", "/delete-account"].map((path) => ({
    url: `${site.url}${path}`,
    changeFrequency: path ? "yearly" : "monthly",
    priority: path ? 0.4 : 1,
  }));
}
