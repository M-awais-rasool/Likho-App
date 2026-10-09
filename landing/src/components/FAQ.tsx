"use client";

import { AnimatePresence, motion } from "framer-motion";
import { Plus } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { site } from "@/lib/site";
import { Reveal, SectionTitle } from "./Reveal";

const faqs: { q: string; a: React.ReactNode }[] = [
  { q: "Who is Likho for?", a: `Children aged ${site.course.ages}, roughly KG to Class 3, who are learning to read and write English letters.` },
  { q: "My child can't read yet. Can they still play?", a: "Yes. Pencil reads every instruction out loud, and the numbered dot and the line show what to do next." },
  {
    q: "How does the tracing work?",
    a: "Each letter is written stroke by stroke, in the right order and direction. Ink only appears while the finger follows the line, so the letter always comes out right, and Pencil helps after a slip.",
  },
  { q: "Is it safe for children?", a: "There are no ads and no chat. Settings and the parent area sit behind a parent gate, so little fingers stay in the game." },
  { q: "Does it work without internet?", a: "Yes. Once the course has been downloaded, your child can keep practising offline. Progress is saved when you are back online." },
  { q: "How many children can use it?", a: "Up to 4 child profiles per family, each with their own progress, stars and Pencil." },
  {
    q: "What's free, and what's in Likho Plus?",
    a: `${site.course.freeWorld}, with all 26 capital letters (${site.course.freeLevels} levels), is free. Likho Plus unlocks all ${site.course.worlds} worlds and ${site.course.levels} levels, with a ${site.plus.trialDays}-day free trial. You can cancel anytime from your store subscriptions.`,
  },
  { q: "What does “Likho” mean?", a: "It means “write!” in Urdu." },
  {
    q: "What information do you collect?",
    a: (
      <>
        Only what&apos;s needed to run Likho and save progress. Read the{" "}
        <Link href="/privacy" className="font-extrabold text-sky-deep underline underline-offset-2">
          privacy policy
        </Link>{" "}
        for the details.
      </>
    ),
  },
];

export function FAQ() {
  const [open, setOpen] = useState<number | null>(0);
  return (
    <section id="faq" className="relative px-5 py-24 sm:px-8 sm:py-28">
      <SectionTitle label="FAQ" title="Questions parents ask" />
      <div className="mx-auto mt-12 max-w-[780px] space-y-3">
        {faqs.map((f, i) => {
          const isOpen = open === i;
          return (
            <Reveal key={f.q} delay={Math.min(i, 5) * 0.04}>
              <div className={`rounded-3xl bg-white transition-shadow ${isOpen ? "shadow-lg" : "shadow-sm"}`}>
                <button
                  type="button"
                  onClick={() => setOpen(isOpen ? null : i)}
                  aria-expanded={isOpen}
                  className="flex w-full items-center justify-between gap-4 px-6 py-5 text-left"
                >
                  <span className="font-display text-[19px] leading-snug font-extrabold text-ink">{f.q}</span>
                  <motion.span animate={{ rotate: isOpen ? 45 : 0 }} className="grid size-9 shrink-0 place-items-center rounded-full bg-cream text-ink">
                    <Plus className="size-5" strokeWidth={3} />
                  </motion.span>
                </button>
                <AnimatePresence initial={false}>
                  {isOpen && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: "auto", opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
                      className="overflow-hidden"
                    >
                      <p className="px-6 pb-6 text-[16px] leading-relaxed font-semibold text-ink-soft">{f.a}</p>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </Reveal>
          );
        })}
      </div>
    </section>
  );
}
