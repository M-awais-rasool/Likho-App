# Likho website

The public site for Likho: the landing page, plus the privacy policy, the terms and the account
deletion page that Google Play and the App Store ask for. Built with Next.js 16 (App Router),
Tailwind CSS 4 and Framer Motion; every page is static.

## Run

```bash
npm install
npm run dev        # http://localhost:3000
```

`npm run build` makes the production build and `npm run lint` checks the code.

## Before going live

Fill in the placeholders in [`src/lib/site.ts`](src/lib/site.ts), the one place that holds what the
site says about Likho:

| field | now | set it to |
|---|---|---|
| `email` | `hello@example.com` | the address parents can write to (shown on the privacy and deletion pages) |
| `developer` | `Likho` | your name, or your business once it is registered |
| `playStoreUrl`, `appStoreUrl` | `null` ("Coming soon") | the store pages, once the app is live |
| `updated` | `3 October 2026` | the date whenever the privacy policy or terms change |

Course numbers and prices are in the same file; keep them in step with `backend/content` and the
app's paywall. Read the privacy policy and the terms once yourself before publishing: they describe
what the app does today (Google sign-in, the data it keeps, Likho Plus).

## Deploy (Vercel)

1. On vercel.com: **Add New → Project**, import this repository and set **Root Directory** to
   `landing`. Vercel detects Next.js by itself.
2. Add the environment variable `NEXT_PUBLIC_SITE_URL`, for example `https://likho.app`. Share
   previews, the sitemap and canonical links use it.
3. Deploy. To use your own domain, add it under **Settings → Domains**.

Then give Google Play `https://<your site>/privacy` as the privacy policy and
`https://<your site>/delete-account` as the account deletion link.

## Structure

```
landing/
├── src/app/          pages: / (landing), /privacy, /terms, /delete-account; sitemap, robots,
│                     icons and the share image (opengraph-image.png)
├── src/components/   one file per landing section (Hero, HowItWorks, Worlds, MeetPencil, …),
│                     plus PhoneDemo and TracingPad, the animated tracing demo
├── src/lib/          site.ts (facts and links), glyphs.ts (the course's letter strokes)
└── public/           pencil/ (mascot art), pictures/ (course pictures), brand/ (app icon)
```

Where the pictures come from:
- `public/pencil/`: Pencil drawn by the app's own painter (`app/lib/mascot/mascot_painter.dart`),
  trimmed and saved as WebP.
- `public/pictures/`: the course pictures from `app/assets/illustrations/` (Microsoft Fluent Emoji,
  MIT licence), 192 px WebP.
- `public/brand/icon.webp`, `src/app/icon.png`, `apple-icon.png` and `favicon.ico`: from
  `design/app-icon/likho-icon-1024.png`. The share image (`src/app/opengraph-image.png`) puts that
  icon next to Pencil, in the app's fonts.
- `src/lib/glyphs.ts`: copied from `backend/content/courses/english-handwriting/glyphs.json`, so the
  demo traces letters exactly as the app does.

Animations follow the visitor's "reduce motion" setting.
