import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_progress.dart';

/// Loads and saves per-puzzle [GameProgress] so a game can be resumed.
class ProgressStore {
  static const _prefix = 'speedbee.progress.';
  final SharedPreferences prefs;
  ProgressStore(this.prefs);

  GameProgress load(String puzzleKey) {
    final raw = prefs.getString('$_prefix$puzzleKey');
    if (raw == null) return GameProgress(puzzleKey: puzzleKey);
    try {
      return GameProgress.decode(raw);
    } catch (_) {
      return GameProgress(puzzleKey: puzzleKey);
    }
  }

  Future<void> save(GameProgress p) =>
      prefs.setString('$_prefix${p.puzzleKey}', p.encode());

  bool hasProgress(String puzzleKey) =>
      prefs.containsKey('$_prefix$puzzleKey');

  /// Wipe every saved puzzle's progress (used by "Start a fresh day").
  Future<void> clearAll() async {
    final keys =
        prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
