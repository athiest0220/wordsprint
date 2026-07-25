import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle.dart';
import 'dictionary.dart';
import 'entitlement_store.dart';
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

  // Small cache so re-entering a puzzle doesn't regenerate it.
  final Map<String, Puzzle> _cache = {};

  AppRepository._(this.dictionary, this.engine, this.stats, this.progress,
      this.settings, this.entitlement, this.purchases);

  static Future<AppRepository> initialize() async {
    final text = await rootBundle.loadString('assets/words.txt');
    final dict = Dictionary.fromText(text);
    final engine = PuzzleEngine(dict);
    final prefs = await SharedPreferences.getInstance();
    final stats = await StatsStore.load(prefs);
    final progress = ProgressStore(prefs);
    final settings = SettingsStore(prefs);
    final entitlement = EntitlementStore(prefs);
    await entitlement.recordOpenedToday(); // counts one trial day per date
    final purchases = PurchaseService(entitlement);
    await purchases.init();
    return AppRepository._(
        dict, engine, stats, progress, settings, entitlement, purchases);
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
