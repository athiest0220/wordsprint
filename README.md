# 🐝 SpeedBee

A timing-focused Spelling Bee. Pick a puzzle size from **7 to 11 letters** (five
games a day), then race three clocks:

1. **⏱ Time to pangram** — first word using all the letters
2. **⭐ Time to perfect pangram** — first word using each letter *exactly once*
   (only some days have one)
3. **🏁 Time to complete** — every valid word found (Flawless)

Career **averages and best times** are kept per size and overall.

Built with **Flutter** (one codebase → Android + iOS). Everything runs
**on-device** — no account, no server, fully private.

---

## Game rules

- **Classic center-letter rule**: every word must contain the highlighted
  center letter.
- **Minimum word length** scales with size:

  | Letters | Min word length |
  |:-------:|:---------------:|
  | 7       | 4               |
  | 8       | 5               |
  | 9       | 5               |
  | 10      | 6               |
  | 11      | 7               |

- Letters may repeat within a word. Letter sets never contain **S** (avoids
  trivial plurals, like the NYT).
- The **daily puzzles are shared**: they're generated deterministically from the
  date, so every device computes the same five puzzles for a given day — no
  backend required.
- The clock counts **active play time only** — it pauses when you leave the app,
  so times reflect real speed, not wall-clock.

## Scoring & ranks

Minimum-length word = 1 point; longer words score their length; a pangram earns a
`+size` bonus. Rank ladder runs Student → Bachelor's → Master's → Doctorate →
Professor (90%) → Flawless (100%).

---

## Project layout

```
lib/
  main.dart                     app entry + splash/bootstrap
  theme.dart                    honeycomb dark theme
  models/
    puzzle.dart                 the daily puzzle + scoring/ranks
    game_progress.dart          per-puzzle resume state + milestone times
    stats.dart                  aggregate career stats
  services/
    dictionary.dart             word list + letter bitmasks
    puzzle_engine.dart          DETERMINISTIC daily puzzle generation
    app_repository.dart         one-time init: dictionary, engine, stores
    stats_store.dart            SharedPreferences stats persistence
    progress_store.dart         SharedPreferences per-puzzle persistence
  game/
    game_controller.dart        live game: clock, guesses, milestone recording
  widgets/
    hex_cell.dart               hexagon letter cell
    hex_board.dart              center + ring layout (6–10 outer letters)
    timers_bar.dart             running clock + three milestone tiles
  screens/
    home_screen.dart            size picker + today's status
    game_screen.dart            play surface (tap or hardware keyboard)
    results_screen.dart         completion: three times vs. avg/best
    stats_screen.dart           career averages & bests
assets/
  words.txt                     171,755-word dictionary (ENABLE, len >= 4)
test/
  puzzle_engine_test.dart       engine correctness + determinism
tool/
  verify_engine.dart            standalone (no-Flutter) engine harness
```

---

## Build & run

You need the **Flutter SDK** (which bundles Dart). See
<https://docs.flutter.dev/get-started/install>.

This project ships the source, assets, tests, and `pubspec.yaml`, but **not** the
generated platform folders (`android/`, `ios/`, …). Generate them in place:

```bash
cd SpeedBee
flutter create --platforms=android,ios .   # adds platform scaffolding, keeps lib/
flutter pub get
```

Then:

```bash
flutter run                 # run on a connected device / emulator
flutter test                # run the engine test suite
flutter build apk           # Android APK  -> build/app/outputs/flutter-apk/
flutter build appbundle     # Play Store AAB
# flutter build ipa         # iOS (requires macOS + Xcode)
```

### Verify the engine without Flutter

If you only have the standalone Dart SDK:

```bash
dart tool/verify_engine.dart
```

It generates all five of today's puzzles and checks determinism, rule
compliance, and word-count spread.

---

## Notes & possible next steps

- **App icon / name**: run `flutter create` then drop an icon in (or use
  `flutter_launcher_icons`).
- **Time zone**: "today" uses the device's local date. Switch `DateTime.now()`
  to UTC in `home_screen.dart` / `AppRepository` if you want a globally uniform
  daily rollover.
- **Cloud leaderboards**: the data model is local-only but structured so a sync
  layer could be added later without reworking gameplay.
- **Word list**: `assets/words.txt` is the open ENABLE list filtered to a–z,
  length ≥ 4. Swap in a curated/less-obscure list any time — the engine just
  reads it.
