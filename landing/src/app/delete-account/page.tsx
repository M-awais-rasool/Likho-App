import type { Metadata } from "next";
import { LegalPage, LegalSection } from "@/components/LegalPage";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Delete your account",
  description: "How to delete your Likho account and all of its data.",
  alternates: { canonical: "/delete-account" },
};

export default function DeleteAccountPage() {
  return (
    <LegalPage
      title="Delete your Likho account"
      intro={<p>You can delete your Likho account, and all of the information in it, at any time. Here&apos;s how.</p>}
    >
      <LegalSection title="In the app">
        <ol className="ml-5 list-decimal space-y-2">
          <li>Open Likho and tap the settings button on the map.</li>
          <li>Answer the grown-ups question to open the parent area.</li>
          <li>
            Go to <strong>Settings</strong> and tap <strong>Delete account</strong>.
          </li>
          <li>Confirm. The account is deleted straight away.</li>
        </ol>
      </LegalSection>

      <LegalSection title="Without the app">
        <p>
          Email <a href={`mailto:${site.email}?subject=Delete%20my%20Likho%20account`}>{site.email}</a> from the email address of your
          Likho account (the Google account you sign in with), with the subject &quot;Delete my Likho account&quot;. We will confirm and
          delete the account.
        </p>
      </LegalSection>

      <LegalSection title="What is deleted">
        <ul>
          <li>The parent account: name, email address, profile photo link, country, device type and app version.</li>
          <li>Every child profile: names, ages and Pencil&apos;s colours.</li>
          <li>All progress: levels, stars, stickers, outfits and room items, and play days.</li>
          <li>Likho Plus details on our side (the store keeps its own purchase records).</li>
          <li>Settings and signed-in sessions on every device.</li>
        </ul>
        <p>This can&apos;t be undone.</p>
      </LegalSection>

      <LegalSection title="What is not deleted">
        <ul>
          <li>Your Google account itself; Likho only stops using it.</li>
          <li>
            A Likho Plus subscription is billed by Google Play or the App Store: cancel it in your store&apos;s subscription settings, or it
            keeps renewing.
          </li>
          <li>Anything played without signing in: it was never sent to us.</li>
        </ul>
      </LegalSection>
    </LegalPage>
  );
}
