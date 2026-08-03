import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle.dart';
import 'audio_service.dart';
import 'dictionary.dart';
import 'entitlement_store.dart';
import 'haptics_service.dart';
import 'progress_store.dart';
import 'puzzle_engine.dart';
import 'purchase_service.dart';
import 'settings_store.dart';
import 'stats_store.dart';

/// One-time-initialized holder for the dictionary, engine, and the two stores.
/// Everything the UI needs hangs off this.
class AppRepository {
  final Dictionary dictionary;
  final PuzzleEngine engine;
  final StatsStore stats;
  final ProgressStore progress;
  final SettingsStore settings;
  final EntitlementStore entitlement;
  final PurchaseService purchases;
  final AudioService audio;
  final HapticsService haptics;

  // Small cache so re-entering a puzzle doesn't regenerate it.
  final Map<String, Puzzle> _cache = {};

  AppRepository._(this.dictionary, this.engine, this.stats, this.progress,
      this.settings, this.entitlement, this.purchases, this.audio,
      this.haptics);

  static Future<AppRepository> initialize() async {
    final text = await rootBundle.loadString('assets/words.txt');
    final dict = Dictionary.fromText(text);
    // Precomputed no-repeat daily cycles for the large sizes (10 & 11).
    final poolsRaw = jsonDecode(
        await rootBundle.loadString('assets/daily_pools.json')) as Map<String, dynamic>;
    final dailyPools = <int, List<List<String>>>{
      for (final e in poolsRaw.entries)
        int.parse(e.key): [
          for (final entry in (e.value as List))
            [for (final s in (entry as List)) s as String]
        ]
    };
    final engine = PuzzleEngine(dict, dailyPools: dailyPools);
    final prefs = await SharedPreferences.getInstance();
    final stats = await StatsStore.load(prefs);
    final progress = ProgressStore(prefs);
    final settings = SettingsStore(prefs);
    final entitlement = EntitlementStore(prefs);
    await entitlement.recordOpenedToday(); // counts one trial day per date
    final purchases = PurchaseService(entitlement);
    await purchases.init();
    final audio = AudioService(settings);
    await audio.init(); // preload SFX; failures are swallowed inside init()
    final haptics = HapticsService(settings);
    await haptics.init();
    return AppRepository._(dict, engine, stats, progress, settings, entitlement,
        purchases, audio, haptics);
  }

  /// Today's puzzle for [size] at the current reroll variant, generating (and
  /// caching) on demand.
  Puzzle puzzleFor(DateTime date, int size) {
    final day = PuzzleEngine.dateOnly(date);
    final variant = settings.variantFor(day, size);
    final key = PuzzleEngine.keyFor(day, size, variant);
    return _cache.putIfAbsent(
        key, () => engine.generate(day, size, variant: variant));
  }
}
