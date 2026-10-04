"use client";

import { motion } from "framer-motion";
import { Check, Crown } from "lucide-react";
import { useState } from "react";
import { site } from "@/lib/site";
import { Reveal, SectionTitle } from "./Reveal";

const free = ["Letter Land and Small Letter Cove (12 levels)", "Capital and small letters, stroke by stroke", "Pencil's voice, stars and stickers", "No ads"];
const plus = ["All 6 worlds and 36 levels", "Phonics, words, sentences and stories", "Every boss to wake up, and the certificate", "No ads"];

export function Pricing() {
  const [yearly, setYearly] = useState(true);
  const { plus: p } = site;

  return (
    <section id="pricing" className="relative px-5 py-24 sm:px-8 sm:py-28">
      <SectionTitle label="Pricing" title={<>Start free. Unlock the whole adventure.</>}>
        The first two worlds are free. Likho Plus opens all {site.course.levels} levels, with a {p.trialDays}-day free trial.
      </SectionTitle>

      <div className="mx-auto mt-14 grid max-w-[920px] gap-6 md:grid-cols-2">
        <Reveal className="card flex flex-col p-8">
          <h3 className="font-display text-3xl font-extrabold text-ink">Free</h3>
          <p className="mt-1 font-semibold text-ink-soft">Everything to get started</p>
          <p className="mt-6 font-display text-5xl font-extrabold text-ink">Rs 0</p>
          <ul className="mt-6 flex-1 space-y-3">
            {free.map((f) => (
              <li key={f} className="flex gap-3 font-semibold text-ink">
                <Check className="mt-0.5 size-5 shrink-0 text-leaf" strokeWidth={3} /> {f}
              </li>
            ))}
          </ul>
          <a href="#download" className="mt-8 rounded-2xl border-2 border-ink/10 py-3.5 text-center font-display text-lg font-extrabold text-ink transition hover:bg-cream">
            Get started
          </a>
        </Reveal>

        <Reveal delay={0.1} className="relative flex flex-col overflow-hidden rounded-[28px] bg-[linear-gradient(150deg,#8f72ec,#5b3bd0)] p-8 text-white shadow-[0_30px_60px_-25px_rgba(91,59,208,.7)]">
          <div className="absolute -top-16 -right-16 size-56 rounded-full bg-white/10" />
          <div className="relative flex items-center justify-between">
            <h3 className="flex items-center gap-2 font-display text-3xl font-extrabold">
              <Crown className="size-7 text-sun" strokeWidth={2.4} /> Likho Plus
            </h3>
          </div>
          <p className="relative mt-1 font-semibold text-white/80">The full course, for the whole family</p>

          <div className="relative mt-5 inline-flex self-start rounded-full bg-white/15 p-1" role="tablist" aria-label="Billing period">
            {[
              { k: true, label: "Yearly" },
              { k: false, label: "Monthly" },
            ].map((o) => (
              <button
                key={o.label}
                type="button"
                role="tab"
                aria-selected={yearly === o.k}
                onClick={() => setYearly(o.k)}
                className="relative rounded-full px-4 py-1.5 text-sm font-extrabold"
              >
                {yearly === o.k && <motion.span layoutId="billing" className="absolute inset-0 rounded-full bg-white" transition={{ type: "spring", stiffness: 380, damping: 30 }} />}
                <span className={`relative ${yearly === o.k ? "text-grape-deep" : "text-white"}`}>{o.label}</span>
              </button>
            ))}
          </div>

          <div className="relative mt-5 flex items-end gap-2">
            <motion.p key={String(yearly)} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="font-display text-5xl font-extrabold">
              {yearly ? p.yearly : p.monthly}
            </motion.p>
            <span className="mb-2 font-bold text-white/80">/ {yearly ? "year" : "month"}</span>
          </div>
          <p className="relative mt-1 h-6 text-sm font-bold text-sun">{yearly ? `That's about ${p.yearlyPerMonth} a month. Save ${p.save}.` : "Billed every month"}</p>

          <ul className="relative mt-5 flex-1 space-y-3">
            {plus.map((f) => (
              <li key={f} className="flex gap-3 font-semibold">
                <Check className="mt-0.5 size-5 shrink-0 text-sun" strokeWidth={3} /> {f}
              </li>
            ))}
          </ul>
          <a href="#download" className="btn-3d relative mt-8 rounded-2xl bg-sun py-3.5 text-center font-display text-lg font-extrabold text-ink">
            Start {p.trialDays}-day free trial
          </a>
        </Reveal>
      </div>
      <p className="mx-auto mt-6 max-w-xl text-center text-sm font-semibold text-ink-soft">
        Prices in Pakistani rupees. Billed through the app store; cancel anytime from your store subscriptions.
      </p>
    </section>
  );
}
