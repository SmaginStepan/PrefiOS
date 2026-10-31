# Preferans Master 2.2.0 — release checklist (manual steps)

Version 2.2.0, bundle `com.an0obis.Pref`, App Store id 6787721817.
Nothing here is submitted for review: that is the last step, and yours.

The real AdMob ids live only in the untracked `Config/Secrets.xcconfig`
(this repository is public). A Release build without them ships with ads off.

## 0. Upload the build to TestFlight

Done: build **6** of 2.2.0 is uploaded (builds 3-5 are older; 6 fixes the multiplayer "replaced" loop).
How it was uploaded, for the next release: accept any pending Program License
Agreement first (App Store Connect → Business), then
`xcodegen generate`, `xcodebuild archive` on the `Pref` scheme (needs the
untracked `Config/Secrets.xcconfig` for the real AdMob ids) and
`xcodebuild -exportArchive -exportOptionsPlist ExportOptions.plist
-allowProvisioningUpdates` with `method = app-store-connect`,
`destination = upload` (automatic signing creates the distribution
certificate).

A new upload of the same version needs a higher build number (project.yml:
`CFBundleVersion` and `CURRENT_PROJECT_VERSION`, now 6).

Business setup that had to be finished before the price showed in the app:
Paid Apps agreement Active, a bank account (processing takes up to 24 h),
the US tax forms (W-8BEN, non-US individual) and the DAC7 questionnaire
(no personal services).

## 1. App Store Connect — create the in-app purchase

Monetization → In-App Purchases → **+**

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Reference name | Remove ads |
| Product ID | `remove_ads_forever` (exactly; the app looks it up by this id) |
| Price | USD 4.99 tier (Tier 5), all territories |
| Family Sharing | optional (off is fine) |

Localizations (display name ≤ 30 chars, description ≤ 45 chars):

| Locale | Display name | Description |
|---|---|---|
| English (U.S.) | Remove ads | Ad-free forever, one payment |
| Russian | Убрать рекламу | Без рекламы навсегда, один платёж |
| Spanish | Quitar anuncios | Sin anuncios para siempre |

App Review information for the IAP: a screenshot of the "Remove ads" sheet
(main menu → Remove ads) and the note "Opens from the main menu, item Remove ads.
One non-consumable purchase that switches off the interstitial ads."

State must reach **Ready to Submit**.

## 2. Attach the IAP to version 2.2.0

The version page has no in-app purchase section any more. Choose the uploaded
build under **Build**, then press **Add for Review** on the version page: this
creates a *draft submission* (nothing is sent yet). Open the product
(Monetization → In-App Purchases → Remove ads forever), press **Add for
Review ▾** and pick the existing draft. The draft panel ("Borradores de
envíos") must now list **both** the app version and the in-app purchase — a
first non-consumable purchase is reviewed together with a new app version.
The final **Submit to App Review** button is in that panel; it is yours.

## 3. Sandbox test (TestFlight build; an iPhone or an Apple-silicon Mac)

Done once on a Mac (Designed for iPad run of the TestFlight build): the price
(€5,99 in Spain) showed, the purchase dialog said "test purchase only, no
charge" and the app switched to "Anuncios eliminados". Restore on a fresh
install was not run.

1. TestFlight builds buy through the sandbox automatically; confirm with your
   own Apple ID — the dialog must say it is a test purchase and nothing is
   charged. (A separate sandbox Apple account under Users and Access →
   Sandbox is optional.)
2. Install the TestFlight build.
3. (iPhone steps from here.) Play 10 single-player deals; from the 11th,
   an ad should appear before the score table (not within 45 s of the last).
4. Menu → **Remove ads** → Buy → confirm. Ads stop, the menu item and
   "Privacy settings" disappear.
5. Delete and reinstall the app → Menu → Remove ads → **Restore purchase**.
6. Sandbox refund check: Settings → App Store → Sandbox Account → Manage →
   or Xcode's Transaction Manager; the app drops ad-free on the next launch.

## 4. App Privacy answers (App Store Connect → App Privacy)

These match `Pref/Resources/PrivacyInfo.xcprivacy` (tracking = yes).

**Do you or your third-party partners collect data from this app?** Yes.

| Data type | Used for tracking | Linked to user | Purposes |
|---|---|---|---|
| Identifiers → Device ID | **Yes** | Yes | Third-Party Advertising, Analytics |
| Usage Data → Advertising Data | **Yes** | Yes | Third-Party Advertising, Analytics |
| Usage Data → Product Interaction | **Yes** | Yes | Third-Party Advertising, Analytics |
| Location → Coarse Location | **Yes** | Yes | Third-Party Advertising, Analytics |
| Identifiers → User ID (random player id) | No | Yes | App Functionality |
| Contact Info → Name (leaderboard display name) | No | Yes | App Functionality |

Also add, to match Google's own SDK manifest (Apple's privacy report merges
SDK manifests, so a mismatch shows up): Diagnostics → Crash Data,
Performance Data, Other Diagnostic Data — not linked, not tracking, purposes
Analytics (+ Third-Party Advertising for performance/other).

Privacy Policy URL: https://preferansmaster.com/privacy (data deletion: `#delete`).

Also: **Age Rating** → answer the questionnaire again (the app now shows
ads), and in **App Information → Content Rights / Advertising**, confirm the
app contains third-party ads if the form asks.

## 5. Export compliance

`ITSAppUsesNonExemptEncryption = NO` is in the Info.plist, so App Store
Connect will not ask. If it ever asks: the app uses only standard
encryption (HTTPS/TLS) → exempt.

## 6. What's New (2.2.0)

**English**
> Monthly Season: everyone plays the same deals, one race a month, with its own leaderboard.
> Ads between deals (never in multiplayer, and not during your first 10 deals), and a one-time "Remove ads" purchase.
> Privacy settings, Rate us, and small fixes.

**Русский**
> Сезон: месячная гонка — у всех одинаковые раздачи и своя таблица рекордов.
> Реклама между раздачами (не в сетевой игре и не в первых 10 раздачах) и разовая покупка «Убрать рекламу».
> Настройки конфиденциальности, «Оценить игру» и небольшие исправления.

**Español**
> Temporada: una carrera mensual con los mismos repartos para todos y su propia clasificación.
> Anuncios entre repartos (nunca en multijugador ni en tus primeros 10 repartos) y una compra única para quitarlos.
> Privacidad, Valóranos y pequeñas mejoras.

## 7. AdMob console (once)

* The iOS app and interstitial unit already exist (ids given to the build).
* Privacy & messaging → European regulations: a GDPR message for the iOS app
  ("Преферанс мастер iOS GDPR", en/ru/es, EEA+UK+CH) is published, next to the
  Android one (which was not touched). Without it EEA users get no ads. The
  optional US-states message and the IDFA explainer are not used (the app
  shows Apple's own tracking prompt after the consent form).
* Apps → Verify app (iOS) fails until the store listing has a developer
  website and `https://preferansmaster.com/app-ads.txt` serves
  `google.com, pub-<AdMob publisher id>, DIRECT, f08c47fec0942fa0` (the
  publisher id is shown on that AdMob page). It only lifts "Limited ad
  serving"; it does not block review or release.
* Link the app to its App Store listing once 2.2.0 is live; add `app-ads.txt`
  to https://preferansmaster.com if you want full ad inventory.

## 8. Final steps

1. TestFlight: wait for processing → add internal testers → run section 3.
2. Version 2.2.0 page: Build selected, IAP attached, What's New filled, App
   Privacy published, age rating done.
3. **Add for Review** → **Submit to App Review** (yours; not done here).

## 9. Not verifiable on a simulator — device test plan

| What | Why not on the simulator | How to test |
|---|---|---|
| Real ads (the real unit id) | Simulator runs show Google test ads only; real ads can be limited for new units | Install the TestFlight build, finish 11 deals; if no ad, wait a few hours after unit creation and retry. Never tap your own live ads. |
| UMP EEA form | Simulator geography is not EEA, and the form needs a published AdMob message | Run a Debug build from Xcode on the device with scheme environment variables `PREF_UMP_EEA=1` (forces the EEA geography) and `PREF_UMP_RESET=1` (forgets the stored choice). Check: form appears, then the ATT prompt, then "Privacy settings" shows in the menu and reopens the form. |
| ATT prompt on a real device | Appears on the simulator, but the system may not show it after one answer | Settings → Privacy & Security → Tracking → toggle, or delete the app to see it again. |
| Real purchase / restore / refund | Needs the product in App Store Connect | Section 3 (sandbox). The StoreKit local tests (`PrefTests`) already pass on the iOS 27 simulator. |
| Multiplayer vs Android | Needs two devices | Create a table on one platform, join from the other, both ways. Done 2026-10-31 on the production server (iOS simulator vs Android emulator): one full deal each way with identical talon, tricks, counters and score sheets. Found and fixed in build 6: leaving online play with the back arrow left the old socket alive, so re-entering gave a "replaced" alert and a reconnect loop (present since 2.0); also the Auto button overlapping the guest's score sheet. Not run: host leaves, 4-player sit-out table. |
| Season deal 0 vs Android | The Android app was not run | Checked without it for the October 2026 seed `e0596c48…be19`: the iOS simulator's first deal matches the independent oracle (`tools/season_oracle.mjs`), the Swift dump equals the oracle for deals 0/1/2/7, and Android's unmodified engine (8ae21e5, JVM, `tools/parity/run_parity.sh`) equals the Swift bots over 3 pools. Repeat each month with the new seed (read it from the app's cached `season.json`; the server's season endpoint needs the API key). |
