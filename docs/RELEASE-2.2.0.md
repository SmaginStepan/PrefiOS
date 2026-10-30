# Preferans Master 2.2.0 — release checklist (manual steps)

Version 2.2.0, bundle `com.an0obis.Pref`, App Store id 6787721817.
Nothing here is submitted for review: that is the last step, and yours.

The real AdMob ids live only in the untracked `Config/Secrets.xcconfig`
(this repository is public). A Release build without them ships with ads off.

## 0. Upload the build to TestFlight

The command-line upload failed: the Apple Developer account has a **new
Program License Agreement to accept** ("PLA Update available") and this Mac has
no "iOS Distribution" certificate. Fix once, then either path works:

1. developer.apple.com/account → accept the latest Program License Agreement
   (also App Store Connect → Business → Agreements).
2. Open `~/Desktop/Projects/PrefiOS-archives/Pref-2.2.0-3.xcarchive` (double-click:
   Xcode → Organizer → Archives). It is already built at 2.2.0 (3) with the real
   AdMob ids. **Distribute App → App Store Connect → Upload** (automatic signing
   creates the distribution certificate). 
3. Or rebuild: `xcodegen generate`, then Product → Archive in Xcode on the
   `Pref` scheme (needs the untracked `Config/Secrets.xcconfig`).

A new upload of the same version needs a higher build number (project.yml:
`CFBundleVersion` and `CURRENT_PROJECT_VERSION`, now 3).

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

App Store Connect → Pref → iOS App 2.2.0 → scroll to **In-App Purchases and
Subscriptions** → **+** → tick `remove_ads_forever`. (The first IAP of an app is
reviewed together with a new app version, so it has to be attached here.)
Then choose the uploaded build under **Build**.

## 3. Sandbox test (on a real iPhone, TestFlight build)

1. Users and Access → Sandbox → create a sandbox Apple account (new e-mail).
2. iPhone → Settings → App Store → Sandbox Account → sign in with it.
   (TestFlight builds buy through the sandbox automatically.)
3. Install the TestFlight build. Play 10 single-player deals; from the 11th,
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
* Privacy & messaging → create and publish the **GDPR** consent message for
  the iOS app (EEA/UK); optional US-states message. Without a published
  message the consent form never appears and EEA users get no ads.
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
| Multiplayer vs Android, season deal 0 vs Android | Needs two devices | Create a table on one platform, join from the other, both ways; compare the season's first deal with the Android app. |
