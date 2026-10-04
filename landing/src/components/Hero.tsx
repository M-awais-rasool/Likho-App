"use client";

import { motion } from "framer-motion";
import { Sparkles, Star, Volume2, WifiOff, BadgeCheck } from "lucide-react";
import Image from "next/image";
import { site } from "@/lib/site";
import { PhoneDemo } from "./PhoneDemo";

const ease = [0.22, 1, 0.36, 1] as const;

/** Big soft letters drifting behind the hero. */
const drifting = [
  { ch: "A", x: "6%", y: "18%", size: 120, color: "#ffc83d", delay: 0 },
  { ch: "b", x: "44%", y: "8%", size: 84, color: "#4d9de0", delay: 1.2 },
  { ch: "c", x: "3%", y: "72%", size: 96, color: "#3bb273", delay: 0.6 },
  { ch: "R", x: "90%", y: "12%", size: 100, color: "#ff8a5b", delay: 1.8 },
  { ch: "e", x: "93%", y: "70%", size: 80, color: "#9b7fe6", delay: 0.9 },
];

export function Hero() {
  return (
    <section className="relative overflow-hidden pt-[110px] pb-20 sm:pt-[130px] lg:pb-28">
      {/* warm glows and drifting letters */}
      <div className="pointer-events-none absolute -top-40 left-1/2 h-[720px] w-[1100px] -translate-x-1/2 rounded-full bg-[radial-gradient(circle,rgba(255,200,61,.30)_0%,rgba(255,200,61,0)_62%)]" />
      <div className="pointer-events-none absolute top-40 -right-40 h-[560px] w-[560px] rounded-full bg-[radial-gradient(circle,rgba(155,127,230,.20)_0%,rgba(155,127,230,0)_65%)]" />
      <div className="pointer-events-none absolute -bottom-40 -left-40 h-[520px] w-[520px] rounded-full bg-[radial-gradient(circle,rgba(77,157,224,.16)_0%,rgba(77,157,224,0)_65%)]" />
      {drifting.map((d) => (
        <span
          key={d.ch}
          aria-hidden
          className="pointer-events-none absolute hidden animate-float-slow font-letter font-bold select-none md:block"
          style={{ left: d.x, top: d.y, fontSize: d.size, color: d.color, opacity: 0.16, animationDelay: `${d.delay}s` }}
        >
          {d.ch}
        </span>
      ))}

      <div className="relative mx-auto grid max-w-[1200px] items-center gap-14 px-5 sm:px-8 lg:grid-cols-[1.08fr_.92fr]">
        <div>
          <motion.span
            initial={{ opacity: 0, y: 14 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease }}
            className="inline-flex items-center gap-2 rounded-full bg-white px-4 py-2 text-[13px] font-extrabold tracking-wide text-ink shadow-sm"
          >
            <Sparkles className="size-4 text-sun-deep" /> English handwriting for kids aged {site.course.ages}
          </motion.span>

          <motion.h1
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease, delay: 0.08 }}
            className="mt-6 font-display text-[54px] leading-[0.98] font-extrabold tracking-tight text-ink sm:text-[72px] lg:text-[84px]"
          >
            Little hands,
            <br />
            <span className="relative inline-block text-sky">
              big letters
              <svg viewBox="0 0 300 24" className="absolute -bottom-3 left-0 w-full" aria-hidden>
                <motion.path
                  d="M4 16 C 60 4, 120 22, 180 12 S 270 6, 296 14"
                  fill="none"
                  stroke="#ffc83d"
                  strokeWidth="9"
                  strokeLinecap="round"
                  initial={{ pathLength: 0 }}
                  animate={{ pathLength: 1 }}
                  transition={{ duration: 1.1, ease, delay: 0.7 }}
                />
              </svg>
            </span>
            <span className="text-coral">.</span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease, delay: 0.2 }}
            className="mt-8 max-w-[520px] text-[19px] leading-[1.65] font-semibold text-ink-soft"
          >
            Likho turns handwriting practice into a happy adventure. With <b className="text-ink">Pencil</b>, a cheerful talking pencil, your
            child traces capital and small letters stroke by stroke, then moves on to phonics, words, sentences and short stories.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease, delay: 0.32 }}
            className="mt-9 flex flex-wrap items-center gap-4"
          >
            <a href="#download" className="btn-3d rounded-2xl bg-sun px-8 py-4 font-display text-[19px] font-extrabold text-ink">
              Start writing with Pencil
            </a>
            <a
              href="#how"
              className="rounded-2xl border-2 border-ink/10 bg-white/60 px-7 py-[14px] font-display text-[18px] font-extrabold text-ink transition hover:bg-white"
            >
              See how it works
            </a>
          </motion.div>

          <motion.ul
            initial="hidden"
            animate="show"
            variants={{ hidden: {}, show: { transition: { staggerChildren: 0.08, delayChildren: 0.5 } } }}
            className="mt-9 flex flex-wrap gap-x-6 gap-y-3 text-[15px] font-bold text-ink"
          >
            {[
              { icon: BadgeCheck, text: "No ads, ever", color: "text-leaf" },
              { icon: Volume2, text: "Pencil reads aloud", color: "text-sky" },
              { icon: WifiOff, text: "Works offline", color: "text-grape" },
            ].map(({ icon: Icon, text, color }) => (
              <motion.li key={text} variants={{ hidden: { opacity: 0, y: 8 }, show: { opacity: 1, y: 0 } }} className="flex items-center gap-2">
                <Icon className={`size-5 ${color}`} strokeWidth={2.6} /> {text}
              </motion.li>
            ))}
          </motion.ul>
        </div>

        {/* the phone, Pencil beside it, and little cards floating around */}
        <motion.div
          initial={{ opacity: 0, y: 40, scale: 0.96 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ duration: 1, ease, delay: 0.15 }}
          className="relative mx-auto w-full max-w-[460px] pb-6"
        >
          <div className="absolute inset-x-10 top-16 bottom-10 rounded-full bg-[radial-gradient(circle,rgba(255,200,61,.45),rgba(255,200,61,0)_70%)] blur-2xl" />
          <div className="relative animate-float">
            <PhoneDemo />
          </div>

          <div className="absolute -bottom-2 -left-4 w-[150px] sm:-left-14 sm:w-[190px]">
            <div className="animate-bob">
              <Image src="/pencil/wave.webp" alt="Pencil, Likho's mascot, waving hello" width={669} height={816} className="h-auto w-full drop-shadow-xl" preload />
            </div>
          </div>

          <motion.div
            initial={{ opacity: 0, x: 30 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 1.2, duration: 0.7, ease }}
            className="absolute top-10 -right-2 hidden animate-float rounded-2xl bg-white px-4 py-3 shadow-xl sm:-right-10 sm:block"
            style={{ animationDelay: "1s" }}
          >
            <div className="flex gap-0.5">
              {[0, 1, 2].map((i) => (
                <Star key={i} className="size-5 fill-sun text-sun-deep" />
              ))}
            </div>
            <p className="mt-1 font-display text-[15px] leading-none font-extrabold text-ink">Level complete!</p>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 30 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 1.5, duration: 0.7, ease }}
            className="absolute right-0 bottom-28 hidden animate-float-slow items-center gap-2 rounded-2xl bg-white px-3 py-2.5 shadow-xl sm:-right-12 sm:flex"
          >
            <Image src="/pictures/rainbow.webp" alt="" width={64} height={64} className="size-9" />
            <div>
              <p className="font-display text-[14px] leading-none font-extrabold text-ink">6 worlds</p>
              <p className="text-[12px] font-bold text-ink-soft">36 levels to explore</p>
            </div>
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}
