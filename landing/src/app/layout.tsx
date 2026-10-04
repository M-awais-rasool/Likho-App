import type { Metadata, Viewport } from "next";
import { Andika, Baloo_2, Nunito } from "next/font/google";
import { MotionProvider } from "@/components/MotionProvider";
import { site } from "@/lib/site";
import "./globals.css";

// The app's fonts: Baloo 2 for headings, Nunito for text, Andika for letters.
const baloo = Baloo_2({ subsets: ["latin"], variable: "--font-baloo", display: "swap" });
const nunito = Nunito({ subsets: ["latin"], variable: "--font-nunito", display: "swap" });
const andika = Andika({ subsets: ["latin"], weight: ["400", "700"], variable: "--font-andika", display: "swap" });

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: { default: `${site.title} | Handwriting app for children`, template: `%s | ${site.name}` },
  description: site.description,
  applicationName: site.name,
  keywords: [
    "handwriting app for kids",
    "ABC tracing",
    "letter tracing for kids",
    "learn to write",
    "capital and small letters",
    "phonics for kids",
    "kids learning game",
    "English writing for children",
  ],
  openGraph: {
    type: "website",
    siteName: site.name,
    title: `${site.name}: ${site.tagline}`,
    description: site.description,
    url: "/",
  },
  twitter: { card: "summary_large_image", title: `${site.name}: ${site.tagline}`, description: site.description },
  alternates: { canonical: "/" },
};

export const viewport: Viewport = { themeColor: "#fff8ec" };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${baloo.variable} ${nunito.variable} ${andika.variable}`}>
      <body>
        <MotionProvider>{children}</MotionProvider>
      </body>
    </html>
  );
}
