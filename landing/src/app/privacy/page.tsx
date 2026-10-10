import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage, LegalSection } from "@/components/LegalPage";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy policy",
  description: "How Likho collects, uses and protects information about parents and children.",
  alternates: { canonical: "/privacy" },
};

export default function PrivacyPage() {
  return (
    <LegalPage
      title="Privacy policy"
      intro={
        <p>
          Likho is a handwriting app for children. We collect as little as we can, we never show ads, and we never sell anyone&apos;s
          information. This policy explains what Likho collects, why, and the choices you have.
        </p>
      }
    >
      <LegalSection title="Who we are">
        <p>
          Likho is published by {site.developer} (&quot;we&quot;, &quot;us&quot;). If you have any question about privacy, write to us at{" "}
          <a href={`mailto:${site.email}`}>{site.email}</a>.
        </p>
      </LegalSection>

      <LegalSection title="What we collect">
        <p>
          <strong>Trying Likho without an account.</strong> A child can play the warm-up and the first level without signing in. Nothing
          from that play is sent to us; it stays on the device.
        </p>
        <p>
          <strong>The parent&apos;s account.</strong> A parent signs in with Google. We receive and keep the name, email address and profile
          photo link of that Google account, and Google&apos;s account ID, so we can create the account and keep it secure.
        </p>
        <p>
          <strong>Child profiles, entered by the parent.</strong> For each child (up to 4): a first name or nickname, their age (5 to 8), and
          the colour they pick for Pencil.
        </p>
        <p>
          <strong>Progress and settings.</strong> Levels finished and stars earned, stickers, the outfits and room items Pencil has, the days
          a child played, and the family&apos;s settings (such as sound, vibration and session length).
        </p>
        <p>
          <strong>Subscription status.</strong> Whether the family has Likho Plus, which plan and until when, as reported by Google Play or
          the App Store when a parent buys it. Payment details are handled by the store; we never see card details.
        </p>
        <p>
          <strong>Sign-in sessions.</strong> A security token and a device label for each signed-in device, so we can keep you signed in and
          let you sign out of other devices.
        </p>
        <p>
          <strong>Country, device type and app version.</strong> When the app talks to our servers, we note the country it is used from
          (worked out from the internet address of the request, or from the phone&apos;s region setting), whether the phone runs Android or
          iOS, and which version of Likho it has. We keep only the country, never the internet (IP) address.
        </p>
        <p>
          We do not collect precise location, contacts, photos, voice recordings, advertising IDs or other device identifiers, or anything
          children draw.
        </p>
      </LegalSection>

      <LegalSection title="How we use it">
        <ul>
          <li>To run Likho: show the right levels, save progress and sync it across the family&apos;s devices.</li>
          <li>To show parents each child&apos;s progress, and to give access to Likho Plus.</li>
          <li>
            To understand how Likho is used, inside our team only: for example how many families play each day, which levels children
            find hard, and which countries and app versions are in use.
          </li>
          <li>To keep accounts secure and to answer messages you send us.</li>
        </ul>
        <p>We never use children&apos;s information for advertising, and we do not build profiles for marketing.</p>
      </LegalSection>

      <LegalSection title="Who we share it with">
        <p>We do not sell or rent information. We share it only with services that help us run Likho, and only for that purpose:</p>
        <ul>
          <li>Google, for signing in (Sign in with Google).</li>
          <li>Google Play and the App Store, for subscriptions.</li>
          <li>The hosting provider that runs our servers and stores the data.</li>
        </ul>
        <p>We may also share information if the law requires it, or to protect the safety of our users.</p>
      </LegalSection>

      <LegalSection title="Children's privacy">
        <p>
          Likho is made for children aged 5 to 8. Accounts are created by parents, and children cannot sign up by themselves. We collect
          only the child information described above, which a parent enters, and we do not knowingly collect anything more. Likho has no
          ads, no chat and no way for children to share information with others. The parent area is behind a parent gate.
        </p>
        <p>
          Parents can review a child&apos;s information in the app, change it in the child&apos;s profile, or delete it at any time (see
          below).
        </p>
      </LegalSection>

      <LegalSection title="How long we keep it, and how we protect it">
        <p>
          We keep information for as long as the account exists. Information travels between the app and our servers over an encrypted
          connection (HTTPS), and access to our servers is restricted.
        </p>
        <p>When an account is deleted, we delete its information from our servers.</p>
      </LegalSection>

      <LegalSection title="Your choices and rights">
        <ul>
          <li>Edit or delete a child&apos;s profile in the app (Parents → Manage profiles).</li>
          <li>
            Delete the whole account and all of its information: in the app, or by following the steps on our{" "}
            <Link href="/delete-account">account deletion page</Link>.
          </li>
          <li>
            Ask us for a copy of your information, or ask any question: <a href={`mailto:${site.email}`}>{site.email}</a>.
          </li>
        </ul>
      </LegalSection>

      <LegalSection title="Changes to this policy">
        <p>If we change this policy, we will update this page and the date at the top. For important changes, we will also tell you in the app.</p>
      </LegalSection>
    </LegalPage>
  );
}
