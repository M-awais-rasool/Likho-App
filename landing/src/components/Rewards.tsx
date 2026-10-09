"use client";

import { motion } from "framer-motion";
import { Award, Star } from "lucide-react";
import Image from "next/image";
import { site } from "@/lib/site";
import { Reveal, SectionTitle } from "./Reveal";

const stickers = ["cat", "sun", "kite", "balloon", "butterfly", "cake", "frog", "star", "duck", "flower"];
const outfits = ["crown", "party-hat", "wizard-hat", "star-glasses", "headphones", "cap"];
const pictures = ["apple", "cat", "sun", "rainbow", "balloon", "kite", "storybook", "moon", "bus", "fish", "butterfly", "star", "flower", "dog", "bee"];
const pictures2 = ["robot", "hat", "cup", "egg", "tree", "owl", "frog", "duck", "lion", "cake", "umbrella", "pencil", "planet", "train", "chick"];

export function Rewards() {
  return (
    <section className="relative overflow-hidden px-5 py-24 sm:px-8 sm:py-28">
      <SectionTitle label="Rewards" title={<>Every letter earns a little celebration</>}>
        Stars, stickers and outfits keep the motivation going. All earned by practising, never bought with money.
      </SectionTitle>

      <div className="mx-auto mt-14 grid max-w-[1100px] gap-5 md:grid-cols-6">
        {/* stars */}
        <Reveal className="card relative overflow-hidden p-7 md:col-span-3">
          <h3 className="font-display text-2xl font-extrabold text-ink">Up to 3 stars in every level</h3>
          <p className="mt-2 font-semibold text-ink-soft">Careful writing earns more stars. The stars buy outfits for Pencil.</p>
          <div className="mt-6 flex items-end justify-center gap-3">
            {[0, 1, 2].map((i) => (
              <motion.div
                key={i}
                initial={{ scale: 0, rotate: -40 }}
                whileInView={{ scale: 1, rotate: 0 }}
                viewport={{ once: true }}
                transition={{ type: "spring", stiffness: 260, damping: 14, delay: 0.2 + i * 0.25 }}
                className={i === 1 ? "-translate-y-4" : ""}
              >
                <Star className={`${i === 1 ? "size-24" : "size-20"} fill-sun text-sun-deep drop-shadow-lg`} strokeWidth={1.6} />
              </motion.div>
            ))}
          </div>
        </Reveal>

        {/* outfits */}
        <Reveal delay={0.08} className="card p-7 md:col-span-3">
          <h3 className="font-display text-2xl font-extrabold text-ink">Dress Pencil up</h3>
          <p className="mt-2 font-semibold text-ink-soft">A crown, a party hat, star glasses and more for Pencil&apos;s room.</p>
          <div className="mt-5 grid grid-cols-3 gap-2 sm:grid-cols-6 md:grid-cols-3">
            {outfits.map((o, i) => (
              <motion.div
                key={o}
                initial={{ opacity: 0, y: 16 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: i * 0.08 }}
                className="rounded-2xl bg-cream p-2 transition-transform hover:-translate-y-1 hover:rotate-2"
              >
                <Image src={`/pencil/outfit-${o}.webp`} alt={`Pencil wearing a ${o.replace("-", " ")}`} width={383} height={600} className="mx-auto h-24 w-auto" />
              </motion.div>
            ))}
          </div>
        </Reveal>

        {/* stickers */}
        <Reveal className="card p-7 md:col-span-4">
          <h3 className="font-display text-2xl font-extrabold text-ink">A sticker book to fill</h3>
          <p className="mt-2 font-semibold text-ink-soft">Each finished level adds a sticker to your child&apos;s own book.</p>
          <div className="mt-5 grid grid-cols-5 gap-2.5 sm:gap-3">
            {stickers.map((s, i) => (
              <motion.div
                key={s}
                initial={{ opacity: 0, scale: 0.5, rotate: -20 }}
                whileInView={{ opacity: 1, scale: 1, rotate: (i % 3) * 6 - 6 }}
                viewport={{ once: true }}
                transition={{ type: "spring", stiffness: 220, damping: 15, delay: i * 0.06 }}
                className="grid aspect-square place-items-center rounded-2xl border-2 border-dashed border-ink/10 bg-white p-1.5 shadow-sm"
              >
                <Image src={`/pictures/${s}.webp`} alt="" width={96} height={96} className="h-auto w-full" />
              </motion.div>
            ))}
          </div>
        </Reveal>

        {/* certificate */}
        <Reveal delay={0.08} className="card relative overflow-hidden bg-[linear-gradient(140deg,#fff3cf,#ffffff)] p-7 md:col-span-2">
          <Award className="size-10 text-sun-deep" strokeWidth={2.2} />
          <h3 className="mt-3 font-display text-2xl font-extrabold text-ink">A certificate at the end</h3>
          <p className="relative z-10 mt-2 pb-16 font-semibold text-ink-soft">Finish all {site.course.levels} levels and Pencil hands over a certificate with your child&apos;s name.</p>
          <Image src="/pencil/happy.webp" alt="" width={679} height={799} className="absolute right-3 -bottom-5 w-20 rotate-6" />
        </Reveal>
      </div>

      {/* the course's pictures */}
      <Reveal className="mt-24 text-center">
        <h3 className="font-display text-3xl font-extrabold text-ink sm:text-4xl">A picture for every word</h3>
        <p className="mx-auto mt-3 max-w-xl text-[17px] font-semibold text-ink-soft">Bright, friendly pictures help children connect each letter and word to its meaning.</p>
      </Reveal>
      <div className="relative mt-10 space-y-4 [mask-image:linear-gradient(90deg,transparent,#000_8%,#000_92%,transparent)]">
        {[pictures, pictures2].map((row, r) => (
          <div key={r} className={`flex w-max gap-4 ${r ? "animate-marquee-reverse" : "animate-marquee"}`}>
            {[...row, ...row].map((p, i) => (
              <div key={`${p}-${i}`} className="grid size-24 place-items-center rounded-3xl bg-white p-3 shadow-sm sm:size-28">
                <Image src={`/pictures/${p}.webp`} alt="" width={112} height={112} className="h-auto w-full" />
              </div>
            ))}
          </div>
        ))}
      </div>
    </section>
  );
}
