# Word Sprint — Project Handoff

A complete, self-contained briefing for a Claude Project that oversees the **Word Sprint** app. Everything needed to pick up the work is here — no external memory required.

_Last updated: 2026-07-31._

---

## 1. What the app is

**Word Sprint: Speed Spelling** — a Flutter word game. A daily "spelling-bee-style" puzzle: one **center letter** (required in every word) plus surrounding letters; find every valid word before the clock beats you. Sizes **6–11 letters**. The hook is **speed** ("race the dictionary") — it times you to pangram, to a perfect pangram, and to completion, and tracks career stats.

- **Owner:** Tim Gallagher (timgallagher0220@gmail.com), operating as **Prism BI**.
- **Platforms:** iOS (App Store) + Android (Google Play). Built from one Flutter codebase.
- **Package / bundle ID:** `com.wordsprint.wordsprint`
- **Display name:** "Word Sprint: Speed Spelling"
- **Monetization:** Free to play, **no ads, no accounts**. 3-day free trial → one-time **$2.99 "Full Unlock" IAP** (`word_sprint_unlock`). Secret trial-extension code (type `PRISMB` + center-I) exists.
- **Tech:** Flutter/Dart. Deterministic daily puzzles (no server) via a seeded engine + precomputed pools. Local storage via `shared_preferences`. Sharing via `share_plus`.

---

## 2. Where things live

| Thing | Location |
|---|---|
| **Flutter project** | `C:\Users\timga\Desktop\SpeedBee` |
| **GitHub repo** | `github.com/athiest0220/wordsprint` (branch `main`). Push as GitHub user **athiest0220**. |
| **Credentials** | `C:\Users\timga\Desktop\Word Sprint Keys\CREDENTIALS.md` |
| **Store assets** | `C:\Users\timga\Desktop\Word Sprint Launch\` (icons, screenshots, store copy in `STORE_LISTINGS_READY.md`) |
| **Flutter SDK** | `C:\Users\timga\flutter\bin\` (use `flutter.bat` / `dart.bat`) |
| **adb** | `C:\Users\timga\Android\Sdk\platform-tools\adb.exe` |
| **Landing page + privacy** | Hosted on `prism-bi.com` (Netlify). Privacy: `https://prism-bi.com/wordsprint/privacy.html` |

---

## 3. Current status (as of 2026-07-31)

**Current version: `1.0.0+10`** (Android versionCode 10). Latest commit `e35caf2` on `main`, pushed.

### Version history (what shipped in each)
- **v7** (`40307bb`): Removed NYT "Queen Bee" branding → "Flawless!" + academic ranks; "Today's Spelling Bee/Import a Spelling Bee" → "Today's Puzzle/Import a Puzzle"; fixed rank to be **word-count based** (was hidden points, so 34/58 words wrongly showed "Bachelor's").
- **v8** (`39c15b1`): Fixed **stale share card** — every share wrote to one fixed temp filename, so Android messaging apps re-served an old cached image. Now writes a unique timestamped filename per share.
- **v9** (`52935b5`): **Statistics share** now renders a **card image** (was plain text); both result & stats cards carry a **"Play Word Sprint · prism-bi.com/wordsprint"** footer baked into the image (survives image-only shares like Instagram) + appended to text captions.
- **v10** (`e35caf2`): **Common-word daily puzzles for all sizes, no repeats.** See §5.

### Store status
- **Apple App Store:** App **v1.0** is **"Waiting for Review"** with build #7 + the Full Unlock IAP (submitted together). **iOS build #8 (v10)** was triggered on Codemagic 2026-07-30 (commit e35caf2) and is heading to TestFlight as **1.0.0 (8)**. NEXT: once build #8 lands, swap it into the in-review version + re-attach the IAP + add release notes + resubmit (see §7 gotchas).
- **Google Play:** Closed testing **"alpha"** track currently has **code 7** live. **v10 AAB (code 10)** is built and staged at `C:\Users\timga\Downloads\WordSprint-1.0.0-v10-release.aab`. IN PROGRESS: creating a new closed-testing release — **blocked on the 54 MB AAB drag-upload** (browser automation caps uploads at 10 MB, so Tim drag-drops it), then fill release notes → Preview & confirm → Publishing overview → "Send changes for review".
- **Release notes (both stores):** `C:\Users\timga\Downloads\WordSprint-v10-release-notes.txt` — "everyday words / no repeats / share fixes."

### Testing (to unlock Production)
Google requires **≥12 testers for 14 continuous days** on a personal dev account before Production. Two things are running:
1. **TestersCommunity** (testerscommunity.com) — paid service, **Pro plan, 25 testers**, submitted 2026-07-30 (Day 0/16, "reports pending"). Uses Google Group **`testers-community@googlegroups.com`**, which must be on the closed track's Testers tab + all countries enabled. **0 credits left** after this submission.
2. Personal TestFlight/closed testers (see §6).

---

## 4. Build & deploy pipeline

All commands run from `C:\Users\timga\Desktop\SpeedBee` (Git Bash or PowerShell).

**Version bump:** edit `pubspec.yaml` `version: 1.0.0+N` (N = Android versionCode).

**Android AAB (Google Play):**
```
"C:/Users/timga/flutter/bin/flutter" build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab  (~52 MB)
```

**Android APK (sideload to phone for testing):**
```
"C:/Users/timga/flutter/bin/flutter" build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
"C:/Users/timga/Android/Sdk/platform-tools/adb.exe" install -r <apk>   # -r preserves game data
```

**iOS (TestFlight/App Store):** built in the cloud via **Codemagic** (codemagic.io), workflow **"Word Sprint iOS → TestFlight"**, branch `main`.
- ⚠️ **A git push does NOT auto-trigger Codemagic** — you must click **Start new build** (Applications → wordsprint → Start new build → main + the workflow → Start new build). It re-scales between renders, so verify the build actually appears under **Builds** (a new index at the top).
- The iOS build number = **Codemagic's own build index** (via `--build-number=$BUILD_NUMBER` in `codemagic.yaml`), independent of pubspec. Codemagic build #N → TestFlight build "1.0.0 (N)". (v7 = build #7; v10 = build #8.)
- Build runs on a Mac mini M2, ~7–10 min, then auto-uploads to TestFlight.

**Landing page (prism-bi.com):** Netlify **Drop** (drag a zip), **atomic full-replace** — the zip must contain the WHOLE site or pages vanish. A ready bundle is staged at `C:\Users\timga\Downloads\prism-bi-wordsprint-deploy.zip` (homepage + portfolio + privacy + the new `wordsprint/` landing page). **NOT yet deployed.** Log in at app.netlify.com with **email** `tim.gallagher@prism-bi.com` (NOT the Google button — that's a different empty team).

---

## 5. The daily puzzle system (v10 — important)

Puzzles are a **pure function of (date, size)** so every device shows the same daily with no server. Two mechanisms:
- **Precomputed pools** (`assets/daily_pools.json`): an ordered per-size cycle of `[letters, center]`. The engine walks it by day-index so puzzles never repeat until the whole cycle is used. **As of v10, ALL sizes 6–11 use pools.**
- The live generator (`lib/services/puzzle_engine.dart`) is the fallback for any size lacking a pool (now none).

**v10 overhaul** — puzzles are now anchored on **common, knowable words** (no more `abhenry` / `mycorrhizae` / `borohydride`), never repeat, and avoid near-duplicate roots (`bivouacking`/`bivouacked`). Built by **`tool/build_pools.dart`**:
- Anchors on an **everyday-speech frequency list** (OpenSubtitles `en_full.txt`, NOT web frequency — web lists over-include medical/chemistry jargon). Frequency lists saved in the session scratchpad (`count_1w.txt` = Norvig/web; `en_subtitles.txt` = OpenSubtitles).
- Keeps the **full 172k-word `assets/words.txt`** for deciding which words are *valid to find* (obscure finds stay a bonus, just never the headline pangram).
- **Stem-dedupes** word roots and **greedy-spaces** similar letter sets so adjacent days feel different.
- Applies a **curated blocklist** (`_blockedWords` / `_blockedParts` in the script) stripping medical/chemistry jargon and off-tone terms (for a 13+ game).
- Difficulty dial = "Balanced / top-50k" (Tim's choice: hard-but-fair).
- **Pool depths:** 6–8 = 366 (a year+), 9 = 149 (~5 mo), 10 = 93 (~3 mo), 11 = 25 (English's ceiling for common 11-distinct-letter words; a 25-day cycle on the hardest size is the accepted trade-off).

**To re-tune** (blocklist, difficulty, word-count bands): edit `tool/build_pools.dart` then:
```
"C:/Users/timga/flutter/bin/dart.bat" run tool/build_pools.dart 50000 <freqListPath> assets/daily_pools.json
```
Then rebuild the app (the JSON ships as an asset). No `lib/` changes needed — `app_repository.dart` loads all pool keys generically and the engine consumes `dailyPools[size]` for any present size.

**To preview upcoming puzzles** (matches what ships, since it loads the pools):
```
"C:/Users/timga/flutter/bin/dart.bat" run tool/compute_puzzle.dart <year> <month> <day> <size>
# prints CENTER / LETTERS / COUNT / PANGRAMS / WORDS
```

### Key files
- `lib/services/puzzle_engine.dart` — generation, seeding (Mulberry32), pool walking, scoring.
- `lib/services/dictionary.dart` — 26-bit letter bitmasks; `maskOf`, `popcount`.
- `lib/services/app_repository.dart` — loads `words.txt` + `daily_pools.json`, wires the engine.
- `lib/models/puzzle.dart` — `rankFor(foundCount, totalWords)` (word-based ranks: Student/Bachelor's/Master's/Doctorate/Professor/Flawless).
- `lib/screens/share_card.dart` + `lib/screens/stats_share_card.dart` — the shareable result/stats cards.
- `lib/util/share_image.dart` — `shareCapturedCard()` (unique-filename share, fixes stale-card bug).
- `lib/util/brand.dart` — `kWordSprintUrl` / `kWordSprintShareTag` (the share footer/link).
- `assets/words.txt` — 172,686-word validity dictionary.
- `assets/daily_pools.json` — the per-size daily cycles.
- `tool/build_pools.dart`, `tool/compute_puzzle.dart` — offline generation/preview tools.

---

## 6. Testers & distribution IDs

**Apple** — App Store app ID **6794757087** (`https://apps.apple.com/app/id6794757087`). TestFlight **Family** internal group `a54c1943-07a2-4ff4-8056-ce8356adaaaf`; team `5cdcf543-abbb-4a2d-a1b7-94582ccaefa1`.
- In group (build 7 installed): **Randy** (rsparacio@comcast.net), **Amy** (agallagher@ga-institute.com).
- Pending team-invite acceptance (must accept the ASC email + sign in with an Apple ID on that address before they appear in the group picker): **James** (jamesgallagher1106@gmail.com), **Kelsey** (kelseygallagher1106@gmail.com), **Lucas Alvarez** (**lucasaalvarez89@gmail.com** — invited 2026-07-30; his `@ga-institute.com` invite was deleted and re-issued to this gmail).
- Internal testers **must** be Users & Access members; ASC **cannot edit a user's email** (delete + re-invite). Faster alternative for one-off testers: add as **External** tester (email only, needs a one-time Beta App Review).

**Google** — Play app `4974265616415784623`, dev account `4842777198155964640`, closed "alpha" track `4699153602846693424`. Closed-test opt-in link: `https://play.google.com/apps/testing/com.wordsprint.wordsprint`. Testers = Google Group **testers-community@googlegroups.com**.

---

## 7. Gotchas / hard-won lessons

**Apple App Store Connect**
- To **swap a build while "Waiting for Review"**: click **"remove this version from review"** first (status → "Developer Rejected"), which **also pulls the IAP** (goes "Developer Rejected") — you must **re-add the IAP** to the new draft via its **Add for Review → Draft iOS Submission**.
- ASC sessions expire often (`authResult=FAILED`). Claude **cannot** enter Apple ID password/2FA — hand login to Tim.
- Export compliance: `ios/Runner/Info.plist` has `ITSAppUsesNonExemptEncryption=false` (stops the "Missing Compliance" prompt).

**Google Play**
- The 54 MB AAB exceeds the browser bridge's 10 MB upload cap → **Tim drag-drops** the AAB into the drop zone; Claude drives the rest.
- Play Console programmatic form-fills often don't register — use **real clicks/typing** for radios, checkboxes, Save/Next. Store listing is a 2-step flow (Assets → **Review** → Next → Save); "Save as draft" leaves it incomplete.
- "Add from library" won't list a version code reserved by an empty draft — discard the empty draft first.
- IARC content rating: answer "Digital purchases" = **Yes** but then tick the **"Purchases of digital goods"** sub-checkbox (not cash/NFT), else it silently produces a wrong **Teen** rating.
- Changes go live only after **Publishing overview → "Send changes for review"** (Managed publishing is off = auto-publish on approval).

**Codemagic** — push does NOT auto-trigger; start builds manually (see §4).

**Browser automation** (Claude-in-Chrome) — flaky this project: screenshot timeouts, coordinate drift from re-scaling, tab-group resets. Re-screenshot before clicking; retry once on timeout; hand final clicks to Tim if frozen. Claude can only see/act on tabs its extension opened — not Tim's other Chrome tabs (ask for the URL).

**adb** — the phone (`R5CW72AQLBH`) drops off USB frequently; ask Tim to reconnect/unlock/allow-debugging. `install -r` preserves game data. To reset like a fresh install: `adb shell pm clear com.wordsprint.wordsprint`.

**Sharing** — image-only shares (Instagram/Stories) drop text captions, so any URL/CTA must be **baked into the card image**, not just the caption.

---

## 8. Website & marketing

- **Landing page** (`prism-bi.com/wordsprint`): dark theme, "Launching soon", App Store + Google Play badges (Apple badge links to `id6794757087`, Play badge to the listing), links to the privacy page. Source in `C:\Users\timga\Downloads\PrismBI-deploy\wordsprint\`. Deploy bundle zipped and ready — NOT yet pushed to Netlify.
- **Privacy policy** already live at `prism-bi.com/wordsprint/privacy.html`; App Privacy = "Data Not Collected".
- A **GTM marketing kit** exists (~$400 budget, no-paid-social stance, AI-host compliance notes). Ask Tim for the file if doing marketing work.

---

## 9. Open threads / immediate next actions

1. **Finish the Google Play v10 release** — Tim drag-drops `Downloads\WordSprint-1.0.0-v10-release.aab`; then fill release notes (`Downloads\WordSprint-v10-release-notes.txt`) → Preview & confirm → **Publishing overview → Send for review**.
2. **Apple v10** — when Codemagic build #8 finishes: remove v1.0 from review, swap build 7→8, re-add the Full Unlock IAP, add release notes ("What's New"), resubmit. (Needs Tim's Apple login.)
3. **On-device test v10** — sideload the v10 APK once the phone is reconnected; verify the new common-word puzzles + share cards.
4. **Deploy the landing page** — Tim logs into Netlify (email login) and drops `Downloads\prism-bi-wordsprint-deploy.zip`.
5. **Tester acceptances** — chase Lucas (lucasaalvarez89@gmail.com), James, Kelsey to accept ASC invites, then add each to the Family TestFlight group.
6. **Reach 12 testers × 14 days on Google** (TestersCommunity is covering this) → then promote closed → **Production**.
7. **Apple public release** — auto-releases on approval (release option = automatic).

---

## 10. How Tim likes to work

- **Act, don't over-explain** — "stop telling me what needs to be done, do it." Do the work; report results plainly.
- Bundle related fixes into **one version** to avoid extra review cycles.
- **Verify on-device** when possible before calling something done.
- Keep the game **"hard, not impossible."**
- He'll say when something needs his hands (a login, a drag-drop, a password) — those are the only real blockers; everything else, just do it.
