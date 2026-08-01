import 'package:shared_preferences/shared_preferences.dart';

import 'puzzle_engine.dart';

/// Tracks the free trial (distinct days the app was opened) and whether the
/// one-time unlock has been purchased. Fully on-device.
class EntitlementStore {
  static const _purchasedKey = 'speedbee.purchased';
  static const _playDaysKey = 'speedbee.playDays';
  static const _bonusDaysKey = 'speedbee.bonusTrialDays';
  static const _promoRedeemedKey = 'speedbee.prismPromoRedeemed';
  static const _wafflesRedeemedKey = 'speedbee.wafflesPromoRedeemed';

  /// Number of free trial days (distinct days played).
  static const trialDays = 3;

  /// Extra trial days granted by redeeming the hidden Prism BI code.
  static const promoTrialBonusDays = 5;

  /// Extra trial days granted by redeeming the hidden "WAFFLES" code.
  static const wafflesTrialBonusDays = 7;

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

  /// Extra trial days granted by promo codes (0 unless a code was redeemed).
  int get bonusTrialDays => prefs.getInt(_bonusDaysKey) ?? 0;

  /// Total free trial days allowed: the base trial plus any promo bonus.
  int get trialDayAllowance => trialDays + bonusTrialDays;

  int get trialDaysLeft {
    final left = trialDayAllowance - trialDaysUsed;
    return left < 0 ? 0 : left;
  }

  bool get purchased => prefs.getBool(_purchasedKey) ?? false;
  Future<void> setPurchased(bool value) =>
      prefs.setBool(_purchasedKey, value);

  /// Whether the hidden Prism BI trial-extension code has been redeemed.
  bool get promoRedeemed => prefs.getBool(_promoRedeemedKey) ?? false;

  /// Redeem the hidden Prism BI code (one-time) to add [promoTrialBonusDays]
  /// to the free trial. Returns what happened so the UI can respond.
  Future<TrialPromoResult> redeemPrismTrialExtension() async {
    if (purchased) return TrialPromoResult.alreadyOwned;
    if (promoRedeemed) return TrialPromoResult.alreadyRedeemed;
    await prefs.setInt(_bonusDaysKey, bonusTrialDays + promoTrialBonusDays);
    await prefs.setBool(_promoRedeemedKey, true);
    return TrialPromoResult.granted;
  }

  /// Whether the hidden "WAFFLES" trial-extension code has been redeemed.
  bool get wafflesRedeemed => prefs.getBool(_wafflesRedeemedKey) ?? false;

  /// Redeem the hidden "WAFFLES" code (one-time) to add [wafflesTrialBonusDays]
  /// to the free trial. Independent of the Prism BI code.
  Future<TrialPromoResult> redeemWafflesTrialExtension() async {
    if (purchased) return TrialPromoResult.alreadyOwned;
    if (wafflesRedeemed) return TrialPromoResult.alreadyRedeemed;
    await prefs.setInt(_bonusDaysKey, bonusTrialDays + wafflesTrialBonusDays);
    await prefs.setBool(_wafflesRedeemedKey, true);
    return TrialPromoResult.granted;
  }

  /// May the player start a game? True during the trial or after purchase.
  bool get entitled => purchased || trialDaysUsed <= trialDayAllowance;

  /// In the trial window (not yet purchased, still has free days).
  bool get inTrial => !purchased && entitled;

  // --- DEV/testing helpers (remove before store submission) ---

  /// Simulate an exhausted trial so the paywall appears.
  Future<void> devExpireTrial() async {
    await setPurchased(false);
    await prefs.remove(_bonusDaysKey);
    await prefs.remove(_promoRedeemedKey);
    await prefs.remove(_wafflesRedeemedKey);
    await prefs.setStringList(_playDaysKey,
        ['2000-01-01', '2000-01-02', '2000-01-03', '2000-01-04']);
  }

  /// Back to a brand-new trial (locked features usable again, day 1).
  Future<void> devResetTrial() async {
    await setPurchased(false);
    await prefs.remove(_bonusDaysKey);
    await prefs.remove(_promoRedeemedKey);
    await prefs.remove(_wafflesRedeemedKey);
    await prefs.remove(_playDaysKey);
    await recordOpenedToday();
  }
}

/// Outcome of trying to redeem the hidden trial-extension code.
enum TrialPromoResult { granted, alreadyRedeemed, alreadyOwned }
