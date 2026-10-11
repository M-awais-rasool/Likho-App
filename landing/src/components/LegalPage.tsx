import Link from "next/link";
import { site } from "@/lib/site";
import { Footer } from "./Footer";
import { Navbar } from "./Navbar";

/** Layout for the privacy, terms and account deletion pages. */
export function LegalPage({ title, intro, children }: { title: string; intro?: React.ReactNode; children: React.ReactNode }) {
  return (
    <>
      <Navbar />
      <main className="px-5 pt-32 pb-16 sm:px-8">
        <article className="card mx-auto max-w-[820px] p-7 sm:p-12">
          <Link href="/" className="text-sm font-extrabold text-sky-deep hover:underline">
            ← Back to Likho
          </Link>
          <h1 className="mt-4 font-display text-4xl leading-tight font-extrabold text-ink sm:text-5xl">{title}</h1>
          <p className="mt-2 text-sm font-bold text-ink-soft">Last updated: {site.updated}</p>
          {intro && <div className="mt-6 text-lg leading-relaxed font-semibold text-ink-soft">{intro}</div>}
          <div className="legal mt-8 space-y-8">{children}</div>
        </article>
      </main>
      <Footer />
    </>
  );
}

export function LegalSection({ title, id, children }: { title: string; id?: string; children: React.ReactNode }) {
  return (
    <section id={id} className="scroll-mt-28">
      <h2 className="font-display text-2xl font-extrabold text-ink">{title}</h2>
      <div className="mt-3 space-y-3 text-[16.5px] leading-relaxed font-semibold text-ink-soft [&_a]:font-extrabold [&_a]:text-sky-deep [&_a]:underline [&_li]:ml-5 [&_li]:list-disc [&_strong]:text-ink [&_ul]:space-y-2">
        {children}
      </div>
    </section>
  );
}
