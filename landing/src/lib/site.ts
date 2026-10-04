// Everything about Likho that the site states, in one place. The course
// numbers and prices match the app (backend/content and the app's paywall).

export const site = {
  name: "Likho",
  title: "Likho: ABC Writing for Kids",
  tagline: "Little hands, big letters.",
  description:
    "Likho turns handwriting practice into a happy adventure. With Pencil, a cheerful talking pencil, children aged 5 to 8 trace capital and small letters, then learn phonics, words, sentences and short stories.",

  /** Public address of this site, for links in shared previews (set NEXT_PUBLIC_SITE_URL when deploying). */
  url: process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000",

  // TODO(owner): fill these in before going live.
  /** Who publishes the app (your name, or your business once registered). */
  developer: "Likho",
  /** Where parents can write to you; also used on the privacy and deletion pages. */
  email: "hello@example.com",
  /** Store pages; null shows "Coming soon". */
  playStoreUrl: null as string | null,
  appStoreUrl: null as string | null,
  /** When the legal pages last changed. */
  updated: "3 October 2026",

  course: { worlds: 6, levels: 36, activities: 182, freeLevels: 12, ages: "5–8" },
  plus: { monthly: "Rs 799", yearly: "Rs 4,999", yearlyPerMonth: "Rs 416", trialDays: 7, save: "48%" },
} as const;

export const nav = [
  { href: "/#how", label: "How it works" },
  { href: "/#worlds", label: "Worlds" },
  { href: "/#pencil", label: "Meet Pencil" },
  { href: "/#parents", label: "For parents" },
  { href: "/#pricing", label: "Pricing" },
  { href: "/#faq", label: "FAQ" },
] as const;
