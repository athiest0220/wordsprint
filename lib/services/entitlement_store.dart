import 'package:shared_preferences/shared_preferences.dart';

import 'puzzle_engine.dart';

/// Tracks the free trial (distinct days the app was opened) and whether the
/// one-time unlock has been purchased. Fully on-device.
class EntitlementStore {
  static const _purchasedKey = 'speedbee.purchased';
  static const _playDaysKey = 'speedbee.playDays';

  /// Number of free trial days (distinct days played).
  static const trialDays = 3;

  final SharedPreferences prefs;
  EntitlementStore(this.prefs);

  List<String> _days() => prefs.getStringList(_playDaysKey) ?? const [];

  /// Record that the app was opened today (counts one trial day per date).
  Future<void> recordOpenedToday() async {
    final today = PuzzleEngine.dateKey(DateTime.now());
    final days = _days().toList();
    if (!days.contains(today)) {
      days.add(today);
      await prefs.setStringList(_playDaysKey, days);
    }
  }

  int get trialDaysUsed => _days().length;
  int get trialDaysLeft {
    final left = trialDays - trialDaysUsed;
    return left < 0 ? 0 : left;
  }

  bool get purchased => prefs.getBool(_purchasedKey) ?? false;
  Future<void> setPurchased(bool value) =>
      prefs.setBool(_purchasedKey, value);

  /// May the player start a game? True during the trial or after purchase.
  bool get entitled => purchased || trialDaysUsed <= trialDays;

  /// In the trial window (not yet purchased, still has free days).
  bool get inTrial => !purchased && entitled;

  // --- DEV/testing helpers (remove before store submission) ---

  /// Simulate an exhausted trial so the paywall appears.
  Future<void> devExpireTrial() async {
    await setPurchased(false);
    await prefs.setStringList(_playDaysKey,
        ['2000-01-01', '2000-01-02', '2000-01-03', '2000-01-04']);
  }

  /// Back to a brand-new trial (locked features usable again, day 1).
  Future<void> devResetTrial() async {
    await setPurchased(false);
    await prefs.remove(_playDaysKey);
    await recordOpenedToday();
  }
}
