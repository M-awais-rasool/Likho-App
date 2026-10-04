import Image from "next/image";
import { site } from "@/lib/site";
import { Reveal } from "./Reveal";
import { StoreButtons } from "./StoreButtons";

/** The download call to action, on the app icon's violet sky. */
export function FinalCTA() {
  const live = Boolean(site.playStoreUrl || site.appStoreUrl);
  return (
    <section id="download" className="relative px-5 py-16 sm:px-8">
      <Reveal className="relative mx-auto max-w-[1150px] overflow-hidden rounded-[40px] bg-[linear-gradient(140deg,#b9a2ff_0%,#7c5ce6_55%,#6a48dd_100%)] px-6 py-16 text-center shadow-[0_40px_80px_-40px_rgba(106,72,221,.8)] sm:px-12 sm:py-20">
        {/* soft rays, like the app icon */}
        <div className="pointer-events-none absolute top-1/2 left-1/2 size-[1400px] -translate-x-1/2 -translate-y-1/2 animate-spin-slow rounded-full bg-[repeating-conic-gradient(from_0deg,rgba(255,255,255,.10)_0deg_12deg,transparent_12deg_24deg)] [mask-image:radial-gradient(circle,#000_10%,transparent_55%)]" />
        {["left-[8%] top-[18%] size-6", "right-[10%] top-[14%] size-8", "left-[16%] bottom-[16%] size-5", "right-[18%] bottom-[22%] size-6"].map((pos, i) => (
          <svg key={pos} viewBox="0 0 24 24" className={`absolute ${pos} animate-twinkle fill-white`} style={{ animationDelay: `${i * 0.6}s` }} aria-hidden>
            <path d="M12 0c.8 6.4 5.6 11.2 12 12-6.4.8-11.2 5.6-12 12-.8-6.4-5.6-11.2-12-12C6.4 11.2 11.2 6.4 12 0z" />
          </svg>
        ))}

        <div className="relative mx-auto w-[150px] animate-bob sm:w-[180px]">
          <Image src="/pencil/happy.webp" alt="Pencil jumping for joy" width={679} height={799} className="h-auto w-full drop-shadow-2xl" />
        </div>
        <h2 className="relative mt-6 font-display text-4xl leading-[1.05] font-extrabold text-white sm:text-6xl">Ready for the first letter?</h2>
        <p className="relative mx-auto mt-4 max-w-xl text-lg font-semibold text-white/85">
          {live ? "Download Likho and start writing with Pencil today." : "Likho is coming soon to Google Play and the App Store."}
        </p>
        <StoreButtons dark={false} className="relative mt-8 justify-center" />
      </Reveal>
    </section>
  );
}
