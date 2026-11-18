# warket: App Store release

> State file for the `app-store-release` skill. Claude reads it first and updates it at the end of every session.
> ✅ done · ⏳ in progress · 👉 your turn · ⬜ to do
>
> This is audit plan Session 9. The plan (`.claude/plans/audit-plan.md`, local only) adds Session 8b, a new
> logo and Icon Composer icon, between phase 3 and phase 4 here.

## Next session (saved 2026-11-18)

1. Ask the owner which app bugs they found and fix those first (new branch from `main`, owner tests on the iPhone).
2. Owner: press Publicar on the App Privacy page, and run the iPhone tests (plan S6, S8, section 7, S8b).
3. Then: review notes (`store/review-notes.txt`, demo share key in `store/demo-vault.env`), screenshots, build, submit.

## Quick reference

| | |
|---|---|
| Store name | `warket: Private Watchlist` (your pick, 2026-11-13). No other app is called warket (`asc apps public search`, US) |
| Home-screen name | `warket` (`CFBundleDisplayName`) |
| Bundle ID | `com.blhdes.warket` (permanent), registered 2026-11-13 (id `3U5J3HJ9AT`) |
| Apple ID (App Store Connect) | `6834424963` · store version `1.0.0` id `06462626-b774-4560-a00e-e8a13f49e4fe` |
| SKU | `warket-ios` |
| Team | `56BK7T2JG7` (same as VILLE) |
| `asc` profile | `Ale` (the team key VILLE uses, `asc auth status --validate` → works) |
| Primary language | English (U.S.). The app is English only (no String Catalog) |
| Listing locales | en-US only (your pick, 2026-11-13) |
| Devices / orientation | iPhone only, portrait |
| Minimum iOS | 17.0 |
| Version (build) | 1.0.0 (1) |
| Price | Free (set 2026-11-13, your OK) |
| Category | Productivity, secondary Finance (set 2026-11-13, your OK; Risks 1) |
| Privacy label | proposed: Other User Content, not linked to you, App Functionality (matches `PrivacyInfo.xcprivacy`). Check in phase 3 |
| Privacy policy URL | https://asset-cafe.vercel.app/privacy (built into the app, `Core/AppLinks.swift`). Page written (`public/privacy.html`), not live yet |
| Support URL | https://asset-cafe.vercel.app/support (built into the app). Page written (`public/support.html`), not live yet |
| Server | `https://warket-api.alee-b44.workers.dev` (Cloudflare Worker, D1 database in the EU), built into the app |
| Pages | `public/privacy.html`, `public/support.html`, `public/pages.css`: plain HTML, system fonts, no outside requests. `vercel.json` rewrites `/privacy` and `/support` to them; the service worker leaves them alone. They go live when `main` is pushed |

## Decisions

- 2026-11-13: Keep bundle ID `com.blhdes.warket`. It is already in the project, and the Keychain service of the saved vault key uses the same name. The account mixes `agu.*` and `app.*`, so there is no single convention to follow.
- 2026-11-13: iPhone only, portrait, iOS 17+, for 1.0.
- 2026-11-13: Encryption exempt (`ITSAppUsesNonExemptEncryption = NO`): the app only uses HTTPS.
- 2026-11-13: Privacy and support pages at `asset-cafe.vercel.app/privacy` and `/support` (plan D9, no own domain, D16). Changing them later needs an app update.
- 2026-11-13: Never write "encrypted" in store text, pages or review notes. The server stores vault content as plain text, kept apart per vault. Safe wording: "no account, no email, your 12 words never leave your phone".
- 2026-11-13: New logo and Icon Composer icon (plan Session 8b) before the screenshots and the build.
- 2026-11-13: Content rights "does not use third-party content": everything shown is what the user types. Site icons and page titles are fetched only for links the user adds, the way a browser would.
- 2026-11-13: Age rating 4+, user-generated content "no": a vault is seen only by people its owner gives a key to. No public feed, no strangers, no messaging.
- 2026-11-13: China mainland left out (ICP filing), as for VILLE.
- 2026-11-13: Store version `1.0.0`, the same as `MARKETING_VERSION` (Apple created it as 1.0; renamed with your OK).
- 2026-11-13: Store name `warket: Private Watchlist`, English listing only (the app is English only). Your picks.
- 2026-11-13: Public contact on the support and privacy pages: your personal Gmail, as for VILLE (your choice, knowing it's public). App Review contact copied from VILLE into `store/contact.env` (gitignored).
- 2026-11-13: The pages load no web fonts and no scripts, so opening the privacy policy contacts nobody but Vercel.

## 1. Foundations

- ✅ Agreements: no banners in App Store Connect (checked 2026-11-13)
- ✅ Explicit App ID `com.blhdes.warket` registered with `asc bundle-ids create` (id `3U5J3HJ9AT`, 2026-11-13, your OK)
- ✅ App record created in Chrome (your OK): `warket: Private Watchlist`, English (U.S.), SKU `warket-ios`, full access, Apple ID `6834424963` (2026-11-13)
- ✅ API key: the team key from VILLE, `asc auth status --validate` → works (2026-11-13)

## 2. Project readiness

- ✅ `audit.sh` has no ❌ (2026-11-13)
- ✅ Privacy manifest `warket-ios/warket/PrivacyInfo.xcprivacy`: UserDefaults `CA92.1`, Other User Content (not linked, App Functionality), no tracking
- ✅ Export compliance key
- ✅ iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait
- ✅ Release build compiles (generic iOS, unsigned, 2026-11-13)
- ⬜ Third-party content: basis for the rights answer written under Risks

## 3. Product page

- ✅ Copy written in `store/metadata/` (en-US), validated and approved (2026-11-13)
- ✅ Privacy policy and support pages live (2026-11-18): https://asset-cafe.vercel.app/privacy and /support answer 200 with their own titles
- ✅ Metadata pushed with `asc metadata apply` (your OK, 2026-11-13): subtitle, description, keywords, promotional text, support and privacy URLs. A dry run afterwards shows 0 changes. To change: edit `store/metadata/`, then the same command
- ✅ Category Productivity + Finance, price Free (your OK, 2026-11-13)
- ✅ Availability: every country except China mainland (ICP filing), copyright `2026 Alejandro Gómez Urrea`, content rights "does not use third-party content", age rating all none (4+). Sent with `asc`, your OK (2026-11-13)
- ⏳ App Privacy answered in Chrome (your OK): Other User Content, not linked to you, App Functionality, no tracking. Saved, NOT published. 👉 You press Publicar on the App Privacy page: its confirmation is your statement that the answers are accurate
- ⏳ App Review details (contact from `store/contact.env`, notes in `store/review-notes.txt`, demo vault). Demo vault created 2026-11-18 on the live server from `warket-seed-data.json` (11 lists, 62 assets), with your OK; its 12 words and share key are in `store/demo-vault.env` (gitignored). Viewer checked: read works, writes answer 403

## 4. Screenshots

Session 8b done 2026-11-18 (Dial, commit `f205709`). Logo workshop (8b.1): https://claude.ai/artifact/TFD8q1ZfsXZp5Epb1wBUcK

- ⬜ Demo mode and demo content (rights checked)
- ⬜ Capture UI test runs on the iPhone
- ⬜ Koubou template and captions
- ⬜ Validated and uploaded

## 5. Build and submit

- ⬜ Final testing on the iPhone (by you): plan sections S6 and S8 owner tests
- ⬜ Archive and upload
- ⬜ TestFlight check
- ⬜ Review notes
- ⬜ Submitted
- ⬜ Released

## Risks and open questions

1. **"Finance" and Guideline 5.1.1(ix).** Apps that provide financial services must come from a company, not a person. warket gives no financial service: it holds no money, places no trades, shows no prices and gives no advice. It is a private notebook of assets. Proposal: primary category Productivity (secondary Finance), and the description says so plainly.
2. **"12 words" looks like a crypto wallet (Guideline 3.1.5).** Wallets must come from an organization. Reviewers know the 12-word pattern from wallets. The review notes and the description must say clearly: warket is not a wallet. The 12 words are only the key to your notes. No coins, no blockchain, no private keys of any wallet. Avoid "seed phrase" in store text, say "12 words" or "a 12-word key".
3. **Data deletion (Guideline 5.1.1(v)).** Covered by "Delete vault" in the app (plan S8). There is no account, so there is nothing else to delete.
4. **Content shared by key (Guideline 1.2).** Sharing is private: only someone with the key can read, nobody can write. No public feed, no discovery. Say so in the review notes.
5. **Third-party services the app talks to.** Site names go to Google for small site icons (`google.com/s2/favicons`). Links go to `api.microlink.io` to read page titles when the page itself can't be read. Images load from addresses the user types in. The privacy page must name all three.
6. **Review needs content.** No login: the reviewer taps "Generate new phrase". Offer a share key to a demo vault filled from `warket-seed-data.json`, so they see a full app.
7. **Share keys can't be changed.** A share key is computed from the vault key, so the same 12 words always give the same share key, and only deleting the vault stops it. The pages say so. The iPhone app has no "Stop sharing" yet (plan 6.8), and even with one, sharing again would bring back the same key.
8. **Public repo.** Contact details go in `store/contact.env` (gitignored). No UDIDs or keys in git.
9. **iPhone Duo.** Screenshots required from April 2027 for iOS 27.1+ SDK builds.

## Log

- 2026-11-13: Started. `asc` already logged in (VILLE's team key), Apple Distribution certificate present, `audit.sh` all green. Bundle ID not registered, no app record yet. README fixed (sharing, HTTPS and notes wording, no long dashes). `store/` rules added to `.gitignore`.
- 2026-11-13: Bundle ID registered (your OK). Privacy and support pages written (`public/`, Vercel rewrites, service worker skips them), built and checked locally, not live. English store copy written and validated, not sent. App record waits for your sign-in to App Store Connect in Chrome. Plan Session 8b (new logo) added before phase 4.
- 2026-11-13: You signed in. No agreement banners. App record created (Apple ID `6834424963`). `asc validate`: 35 blocking items, the usual list for a new record (copy, review details, category, content rights, price, availability, screenshots, build).
- 2026-11-13: Sent with your OK: store version renamed 1.0 → 1.0.0 (matches `MARKETING_VERSION`), English copy (`asc metadata apply`, dry run first, then 0 changes left), categories Productivity + Finance, price Free. `asc validate`: 35 → 30 blocking (24 age-rating questions, review details, content rights, availability, copyright, screenshots, build).
- 2026-11-13: Sent with your OK: availability without China, copyright, content rights, age rating 4+. App Privacy answered and saved in Chrome, not published (the publish confirmation is yours). `asc validate`: 3 blocking left (review details, screenshots, build). Logo workshop published for plan Session 8b. Commits pushed on `fix/audit-session-9`, `main` untouched.
- 2026-11-18: New logo (Session 8b, Dial) committed `f205709`. With your OK: `fix/audit-session-9` fast-forwarded into `main` and pushed (deploys the website with /privacy, /support and the new favicons). Demo vault created for App Review, keys in `store/demo-vault.env`.
