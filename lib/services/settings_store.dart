import 'package:shared_preferences/shared_preferences.dart';

import 'puzzle_engine.dart';

/// Small persistent user-preferences store.
class SettingsStore {
  static const _clearOnWrongKey = 'speedbee.settings.clearOnWrong';
  static const _variantPrefix = 'speedbee.variant.';

  final SharedPreferences prefs;
  SettingsStore(this.prefs);

  /// When true (default), the current entry is cleared after a wrong word so
  /// the player can start typing again immediately. When false, the entry is
  /// left in place for the player to edit/delete themselves.
  bool get clearOnWrong => prefs.getBool(_clearOnWrongKey) ?? true;

  Future<void> setClearOnWrong(bool value) =>
      prefs.setBool(_clearOnWrongKey, value);

  static const _seenTutorialKey = 'speedbee.seenTutorial';
  bool get seenTutorial => prefs.getBool(_seenTutorialKey) ?? false;
  Future<void> setSeenTutorial(bool value) =>
      prefs.setBool(_seenTutorialKey, value);

  static const _hapticsKey = 'speedbee.haptics';
  bool get hapticsEnabled => prefs.getBool(_hapticsKey) ?? true;
  Future<void> setHapticsEnabled(bool value) =>
      prefs.setBool(_hapticsKey, value);

  // --- reroll variant ("New letters") ---

  String _variantKey(DateTime d, int size) =>
      '$_variantPrefix${PuzzleEngine.dateKey(d)}#$size';

  /// Current reroll variant for a given day/size (0 = the plain daily).
  int variantFor(DateTime d, int size) =>
      prefs.getInt(_variantKey(d, size)) ?? 0;

  /// Bump to fresh letters; returns the new variant.
  Future<int> bumpVariant(DateTime d, int size) async {
    final next = variantFor(d, size) + 1;
    await prefs.setInt(_variantKey(d, size), next);
    return next;
  }
}
