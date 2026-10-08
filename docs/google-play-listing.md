# Google Play listing: Likho

Everything to fill in the Play Console, plus what has to change in the app before the first upload.
Research done on 3 October 2026 in the Pakistan store; links are at the end.

## 1. Fix before the first upload

These are blockers. Google can reject the app, or the app will not work for users, until they are
fixed.

1. **Google sign-in in a kids app.** Google's API policy says: "If your application is directed
   primarily at children, it should not use Google Sign-In". Apps for both children and adults may
   only offer it as an optional feature, and "users must be able to access the application in its
   entirety without signing into a Google Account". Likho needs Google sign-in from level 2. Choose
   one:
   - No accounts at launch: progress stays on the phone and every level works without signing in.
     This is the fastest way to launch.
   - A parent account that does not use Google, for example email plus a one-time code from our
     API, behind the parent gate. This keeps progress across phones.
2. **Google Play Billing for Likho Plus.** Levels 32 to 144 are sold as the Likho Plus
   subscription (section 3), but "Store purchase is not wired yet" (`paywall_screen.dart`). The app
   needs:
   - Play Billing Library 8 or newer. Play has refused builds with older versions since
     31 August 2026.
   - The 7-day trial from Play's free-trial offer, instead of the API's own trial (`TrialUsed`).
   - The API checks each purchase with the Google Play Developer API and real-time developer
     notifications, then turns Plus on or off.
   - A paywall that shows the price, the billing period, the trial and how to cancel.
   - The parent gate before the paywall. Today a child who taps level 32 sees it directly.
3. **A public HTTPS server for the API.** Release builds now point to `http://192.168.18.20:8080`,
   an address on your home network. Android also blocks plain `http` by default. Deploy the
   backend with HTTPS (for example `https://api.likho.app`) and point release builds at it
   (`ApiConfig` in `app/lib/data/api/api_client.dart`).
4. **Release signing key.** `android/app/build.gradle.kts` signs release builds with the debug key,
   and Play refuses those. Create an upload key and keep it backed up (losing it means asking
   Google for a reset). Use Play App Signing.
5. **Privacy policy and account deletion links.** Both need to be web pages, and both are ready on
   the website in `landing/` (see the Website section of `README.md`). Deploy it, then use
   `https://<your site>/privacy` and `https://<your site>/delete-account`.
   - The privacy policy is required for every app, and especially for kids apps. The app's
     Settings → Privacy policy row and the Welcome screen's Terms and Privacy Policy link must open
     it too; today they only open the help action and a "coming soon" message.
   - Apps with accounts must give a web link where people can ask for their account to be deleted
     (in-app deletion already exists: Settings → Delete account).
6. **Store builds:** build without `LIKHO_TEST_LOGIN`. It is off unless passed, so just don't pass it.
7. **Closed test first (new personal accounts).** Personal developer accounts created after 13
   November 2023 must run a closed test with at least 12 testers, opted in for 14 days in a row,
   before they can apply for production. Recruit 15–20 testers, because the count must never drop
   below 12.

Already fine:
- The app targets API 36, which Play has required since 31 August 2026.
- There are no ads and no advertising ID.
- Account deletion works in the app.

## 2. Create the app now (no build needed)

| Field | Value |
|---|---|
| Package name | **Not `com.likho.likho`**: Play Console says it is already in use. Try, in order: `com.likho.abcwriting`, `com.likhokids.app`, `com.awaisrasool.likho`. The name Play accepts must then go into the app's `applicationId`. It cannot be changed after the app is created. |
| App name | `Likho: ABC Writing for Kids` |
| Default language | English (United States), en-US |
| App or game | App |
| Free or paid | **Free.** A subscription is sold inside a free app; "Paid" means a one-time price before download. A free app can never become paid, which is fine here. |

Since 30 March 2026, Play registers the package name for Android developer verification as soon as
the app is created. Only the Play Console form can tell whether a name is free: `com.likho.likho`
had no public store page, yet someone had already registered it.

What you can finish today, before any build:
- **Payments profile** (Setup → Payments profile): your bank account and tax details. Google
  supports merchant accounts in Pakistan, and the subscription money is paid out to this profile.
  Accept the paid-apps agreement when Play Console asks.
- **Store listing** as a draft (section 4). The feature graphic and screenshots can come later.
- **Store settings and countries** (section 6).
- **App content forms** (section 7). A privacy policy URL is needed first.

What has to wait for a build:
- The Likho Plus subscription (section 3). Play Console only lets you create subscriptions after a
  signed build with Play Billing is uploaded, even to internal testing.
- Testing and publishing.

Heads-up for personal developer accounts: once an app sells anything, Google Play shows the
developer's legal name, full address and email publicly. An organization account shows the
business details instead, and it skips the 12-tester rule. It needs a D-U-N-S number, which is
free but takes time.

## 3. Likho Plus subscription (Monetize → Subscriptions, after a build with billing)

| Setting | Value |
|---|---|
| Product ID | `likho_plus`. Permanent; it can never be reused. |
| Name | Likho Plus |
| Base plan 1 | `monthly`: auto-renewing, every month, Rs 799 |
| Base plan 2 | `yearly`: auto-renewing, every year, Rs 4,999 (about Rs 416 a month, as the paywall says) |
| Offer | `free-trial-7d` on both base plans: a 7-day free trial, for new subscribers only |
| Other countries | set the price in PKR; Play can fill in the other countries' prices for you |

- Plus unlocks levels 32 to 144 (Small Letter Cove to Story Space). Letter Land (capitals A–Z,
  levels 1–31) stays free. The free part is one constant, `FREE_UP_TO` in
  `tools/curriculum/build_levels.py`.
- Google keeps 15% of subscription payments.
- These prices are the ones in today's paywall. If you change them, change them in both places.
- Test with license testers (Setup → License testing) before launch: their purchases cost nothing
  and renew within minutes.

## 4. Store listing (Grow → Store presence → Main store listing)

### App name (27 of 30 characters)

```
Likho: ABC Writing for Kids
```

"Likho" alone is not enough. Three other apps already use the name ("Likho – Write Notes Simply",
"Likho Notes", "Bolo Aur Likho"), and the name says nothing to a parent who is searching. The
title is the strongest search signal, so it carries "ABC", "writing" and "kids".

Other titles that also fit:
- `Likho - ABC Tracing for Kids` (28)
- `Likho: Kids Handwriting ABC` (27)

Rules: no emojis, no ALL CAPS, and no "best", "#1", "free" or prices in the title.

### Short description (80 of 80)

```
Letter tracing & handwriting practice: capital and small letters, phonics, words
```

Other short descriptions:
- `Trace and write ABC with Pencil: capital & small letters, phonics and words` (75)
- `Fun ABC tracing and handwriting game: capital & small letters, phonics, words` (77)

### Full description (2,777 of 4,000)

```
Likho is a kids learning game that makes handwriting practice a happy adventure. With Pencil, a cheerful talking pencil, your child learns to write the English alphabet: first tracing capital and small letters (uppercase and lowercase), then phonics, words, sentences and short stories.

"Likho" means "write!" in Urdu. It is made for kindergarten and early primary children aged 5 to 8 (KG to Class 3) who are learning to read and write in English.

HOW KIDS LEARN TO WRITE
• Letter tracing with step-by-step stroke guides, then writing on their own
• One new letter at a time, in nine short games: find it, trace it, hear its sound, hunt for it, write it alone
• Letters in A to Z order, capitals first, then small letters with their sounds
• Older letters keep coming back, so children remember them
• Likho checks every letter and gives a gentle hint after a mistake
• Pencil reads every instruction out loud, so children who cannot read yet can play on their own
• Colourful pictures for the words: A is for apple!

12 WORLDS, 144 LEVELS
1. Letter Land: capital letters A to Z
2. Small Letter Cove: small letters a to z and their sounds
3. Phonics Forest: blend words like cat, hen, pig, dog and bus
4. Word Town: colours, numbers, animals, family and food
5. Sound Mountain: sh, ch, th, ee, oo and more letter pairs
6. Blend Beach: star, frog, flag and other blends
7. Sight Word Garden: the, said, was, they and other words to know by sight
8. Sentence Sky: capital letters, full stops and short sentences such as "I see a cat."
9. Action Jungle: doing words, describing words and in, on, under
10. Question Island: who, what, where, and talking with friendly aliens
11. Reading River: read sentences and little stories, then answer questions
12. Story Space: put stories in order and write about me, my family and my day
Each world ends with a sleepy boss that your child wakes up by finishing the level.

REWARDS THAT KEEP THEM GOING
• Up to 3 stars in every level
• A sticker book to fill
• Outfits for Pencil in his room, bought with stars: hats, glasses, a cape and more
• A certificate when the whole course is complete
• Happy sounds and gentle vibrations for every success

FOR PARENTS
• No ads
• Up to 4 child profiles, each with their own progress
• A parent gate keeps settings and the parent area away from little fingers
• See each child's progress through the course
• Short sessions: choose about 5, 10 or 15 minutes, then Pencil takes a nap
• Progress is saved to your account, so it stays safe when you change phones
• Works offline: once the course is downloaded, kids can keep practising without internet

LIKHO PLUS
Letter Land, with all 26 capital letters, is free to play. Likho Plus, a monthly or yearly subscription, unlocks all 12 worlds and 144 levels. New families can try it free for 7 days. The subscription renews automatically until you cancel it in Google Play.

WALIDAIN KE LIYE
Likho bachon ke liye English likhna seekhne wala game hai. Bachay ABC, capital aur small letters, phonics, alfaaz aur chhote jumlay likhna seekhte hain. Pencil har hidayat bol kar batata hai, is liye chhote bachay bhi khud khel sakte hain. Koi ads nahi, aur settings parent gate ke peeche mehfooz hain.

One letter at a time, your child will write with confidence. Start the adventure with Pencil today!
```

Notes on the full description:
- Every feature in it exists in the app today. Two lines depend on the sign-in decision in part 1:
  "Progress is saved to your account" and the offline line. Update them if accounts change.
- Not claimed on purpose:
  - every letter A to Z (children write 13 capital and 13 small letters, grouped by shape)
  - speech checking (speak rounds do not listen yet)
  - left-handed mode (a stored setting that does not change the game yet)
  - weekly reports (on the paywall, but not built)
- The LIKHO PLUS paragraph describes the subscription in section 3. Publish the listing only after
  billing works in the app.

## 5. Why these words: what parents type

Play Store search suggestions (Pakistan, 3 October 2026), and where the listing uses them:

| Parents type | Used in |
|---|---|
| abc tracing, abc tracing app for kids, abc tracing and phonics | title (ABC), short and full description |
| letter tracing for kids, letter tracing app, letter tracing games | short description, full description |
| kids writing practice, kids writing app, kids writing game | title (Writing, Kids), full description |
| learn to write for kids | full description ("learns to write") |
| handwriting practice, handwriting app | short description, full description |
| capital and small letters, alphabet capital and small letters | short description, full description (the Pakistani school wording) |
| english writing practice app, kids english learning app | full description ("read and write in English") |
| phonics learning app, phonics games for kids | short description, full description, Phonics Forest |
| kids learning apps offline, kids learning game offline | full description ("kids learning game", "Works offline") |
| likhne wala game, sikho wali game (Roman Urdu) | "WALIDAIN KE LIYE" paragraph |

The leaders in this search are LetterSchool, Writing Wizard, LetraKid and ABC Kids (50M+
downloads, Teacher Approved). Their titles all use ABC, Writing, Tracing, Kids, Phonics and Learn
to Write. Ratings and installs count as much as words, so ask happy testers and parents for
reviews from the first week.

## 6. Store settings

- **App or game:** App. **Category:** Education. (ABC Kids is listed as a game in the Educational
  category; that also works, but parents mostly look for apps.)
- **Tags:** pick up to 5 that fit: early learning, kids, language learning or education.
- **Contact details:** an email address (required) and a website (recommended): the site from part 1.
- **Countries:**
  - Start with Pakistan: the prices are set in rupees and the course follows KG to Class 3.
  - Add countries with many Urdu-speaking families (UAE, Saudi Arabia, UK, US, Canada) when ready.
- **Price:** Free. Play adds "In-app purchases" to the listing once the Likho Plus subscription
  exists.
- **Translations (optional, later):** an Urdu (ur) listing for phones set to Urdu.

## 7. App content (Policy → App content)

- **Privacy policy:** the URL from part 1.
- **Ads:** No, the app has no ads.
- **App access:** reviewers must be able to reach every part of the app. Explain how to sign in,
  or that no sign-in is needed, and that levels 32 and up need Likho Plus.
- **Content rating (IARC questionnaire):**
  - Educational app.
  - No violence, sexual content, gambling or user-to-user chat; no location sharing.
  - Digital purchases: Yes, the Likho Plus subscription.
  - Expect "Everyone" / 3+.
- **Target audience and content:**
  - Ages "5 and under" and "6–8": the app asks for ages 5 to 8.
  - This puts the app under the Families policy: no ads SDKs, no device IDs, and nothing that is
    not approved for children (see part 1, item 1).
  - It also makes the app eligible for the Teacher Approved badge, which teachers give to good kids
    apps (you cannot apply for it).
- **Data safety:**
  - Today's app with Google sign-in sends this to our server:

    | Data (Play category) | What | Why |
    |---|---|---|
    | Personal info → Name | the parent's name from Google, the child's first name | App functionality, account management |
    | Personal info → Email address | the parent's Google email | Account management |
    | Personal info → User IDs | the account ID | Account management |
    | Personal info → Other info | the child's age (5–8) and Pencil's colour; the parent's Google photo address | App functionality |
    | App activity → App interactions | levels, stars, stickers, Pencil's outfits, play days | App functionality |
    | Financial info → Purchase history | whether the family has Likho Plus, from Google Play | App functionality |

  - Card and payment details stay with Google Play; the app never sees them.
  - Nothing is shared with third parties.
  - Data is encrypted in transit, once the API uses HTTPS.
  - Users can delete their data: in the app, and through the web link from part 1.
  - If you choose "no accounts at launch", most of this list goes away.
- **Other questions:** answer No to news, government, financial and health features.

## 8. Graphics

| Asset | Size | Status |
|---|---|---|
| App icon | 512 × 512 PNG | ready: `design/app-icon/google-play-512.png` |
| Feature graphic | 1024 × 500 PNG/JPEG, no transparency | to make: Pencil, the Likho name and a short line such as "Learn to write ABC" |
| Phone screenshots | 2–8, 9:16 (1080 × 1920 is best) | to take: 6 to 8 is best |
| Tablet screenshots (7" and 10") | optional | recommended, because the app runs on tablets |
| Video | YouTube link, optional | a 30-second clip of Pencil and tracing helps |

Screenshots to take, with a short caption on each:
1. The world map: "12 worlds, 144 levels of writing fun"
2. A level intro with Pencil and a picture: "Pencil reads every step out loud"
3. Tracing a letter: "Trace and write capital and small letters"
4. A phonics or word round: "Phonics, words and sentences"
5. Level complete with stars: "Win stars and wake the sleepy boss"
6. Pencil's room: "Dress up Pencil with your stars"
7. The parent dashboard: "See every child's progress"

## 9. First release

- Version: `0.1.0+1` in `pubspec.yaml`; consider `1.0.0+1` for the public launch.
- Build: `flutter build appbundle --release`, with the production API, then upload the `.aab` file.
- Release notes (174 of 500):

```
First release of Likho: 144 levels in 12 worlds. Trace and write capital and small letters, then phonics, words, sentences and stories, with Pencil reading every step out loud.
```

## Sources

- [Google API Services User Data Policy: child-directed and mixed audience apps](https://developers.google.com/terms/api-services-user-data-policy)
- [Google Play Families policies](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)
- [Data practices in Families apps](https://support.google.com/googleplay/android-developer/answer/11043825?hl=en)
- [Store listing best practices](https://support.google.com/googleplay/android-developer/answer/13393723?hl=en)
- [Testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [Link a developer account to a payments profile](https://support.google.com/googleplay/android-developer/answer/3092739?hl=en)
- [Google Play supports Pakistani merchant accounts (TechJuice)](https://www.techjuice.pk/google-play-now-supports-pakistani-merchant-accounts/)
- [Create an in-app product (Play Console Help)](https://support.google.com/googleplay/android-developer/answer/1153481?hl=en)
- [Play Billing setup order and Billing Library 8 deadline (Adapty)](https://adapty.io/blog/android-in-app-subscriptions-tutorial/)
- [Public developer address for apps that sell](https://davidserrano.io/your-home-address-exposed-on-google-play/)
- [Store listing character limits and metadata rules (summary)](https://playaudit.app/blog/google-play-listing-requirements)
- [Screenshot and feature graphic sizes](https://appradar.com/blog/android-app-screenshot-sizes-and-guidelines-for-google-play)
- Play Store search and suggestions, Pakistan store: [handwriting for kids](https://play.google.com/store/search?q=handwriting%20for%20kids&c=apps&gl=PK), [likho](https://play.google.com/store/search?q=likho&c=apps&gl=PK), [ABC Kids](https://play.google.com/store/apps/details?id=com.rvappstudios.abc_kids_toddler_tracing_phonics&gl=PK)
