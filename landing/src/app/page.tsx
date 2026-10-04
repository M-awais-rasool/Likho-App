import { FAQ } from "@/components/FAQ";
import { FinalCTA } from "@/components/FinalCTA";
import { Footer } from "@/components/Footer";
import { Hero } from "@/components/Hero";
import { HowItWorks } from "@/components/HowItWorks";
import { MeetPencil } from "@/components/MeetPencil";
import { Navbar } from "@/components/Navbar";
import { Parents } from "@/components/Parents";
import { Pricing } from "@/components/Pricing";
import { Rewards } from "@/components/Rewards";
import { StatsStrip } from "@/components/StatsStrip";
import { Worlds } from "@/components/Worlds";

export default function Home() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <StatsStrip />
        <HowItWorks />
        <Worlds />
        <MeetPencil />
        <Rewards />
        <Parents />
        <Pricing />
        <FAQ />
        <FinalCTA />
      </main>
      <Footer />
    </>
  );
}
