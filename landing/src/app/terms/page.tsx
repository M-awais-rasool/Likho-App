import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage, LegalSection } from "@/components/LegalPage";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Terms of use",
  description: "The terms for using Likho and Likho Plus.",
  alternates: { canonical: "/terms" },
};

export default function TermsPage() {
  return (
    <LegalPage title="Terms of use" intro={<p>These terms explain the rules for using Likho. By using Likho, you agree to them.</p>}>
      <LegalSection title="Who can use Likho">
        <p>
          Likho is made for children aged 5 to 8, playing with a parent&apos;s permission. Accounts, purchases and settings are for parents
          or guardians aged 18 or over, who are responsible for how the account is used.
        </p>
      </LegalSection>

      <LegalSection title="Your account">
        <p>
          A parent signs in with Google to save progress. Keep your Google account secure; you can sign out of any device and delete the
          account at any time (see our <Link href="/delete-account">account deletion page</Link>).
        </p>
      </LegalSection>

      <LegalSection title="Likho Plus">
        <ul>
          <li>The first two worlds are free. Likho Plus unlocks all worlds and levels.</li>
          <li>Likho Plus is a monthly or yearly subscription, sold through Google Play or the App Store, and may start with a free trial.</li>
          <li>The subscription renews automatically until you cancel it. You can cancel anytime from your store&apos;s subscription settings; access continues until the end of the period you paid for.</li>
          <li>Payments and refunds are handled by the store, under its own rules.</li>
        </ul>
      </LegalSection>

      <LegalSection title="Using Likho fairly">
        <p>Please don&apos;t copy, resell or reverse-engineer the app or its content, try to break into our servers, or use Likho in a way that could harm others.</p>
      </LegalSection>

      <LegalSection title="Our content">
        <p>
          Likho, Pencil the mascot, the lessons and the app&apos;s design belong to {site.developer}. The course pictures are Microsoft Fluent
          Emoji, used under the MIT licence.
        </p>
      </LegalSection>

      <LegalSection title="No guarantees">
        <p>
          We work hard to keep Likho working and helpful, but we provide it &quot;as is&quot;, and we can&apos;t promise it will always be
          available or error-free. As far as the law allows, we are not liable for indirect losses from using Likho.
        </p>
      </LegalSection>

      <LegalSection title="Changes">
        <p>We may update these terms. We will change the date at the top of this page, and tell you in the app about important changes.</p>
      </LegalSection>

      <LegalSection title="Contact">
        <p>
          Questions about these terms: <a href={`mailto:${site.email}`}>{site.email}</a>. Our <Link href="/privacy">privacy policy</Link>{" "}
          explains how we handle information.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
