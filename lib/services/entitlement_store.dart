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
  static const _freeUntilKey = 'speedbee.freeUntilMs';
  static const _familyRedeemedKey = 'speedbee.familyRedeemed';

  /// Number of free trial days (distinct days played).
  static const trialDays = 3;

  /// Owner "family" easter-egg words (the kids' nicknames). Entering any of
  /// these — even after the trial is over — grants a temporary free window.
  /// Each word is usable ONCE per device; the grants stack, so knowing all
  /// three yields up to 3 × [familyGrantDays] days. Case-insensitive.
  static const _familyCodes = {'handsome', 'potato', 'midget'};

  /// Length of the free window each family code grants.
  static const familyGrantDays = 14;

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

  // --- family free-grant window (owner easter-egg codes) ---

  /// When the current free grant expires (null if none was ever granted).
  DateTime? get freeUntil {
    final ms = prefs.getInt(_freeUntilKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Whether a family-code free window is currently active.
  bool get inFreeGrant {
    final until = freeUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  /// Whole days left in the active free grant (0 if none).
  int get freeGrantDaysLeft {
    final until = freeUntil;
    if (until == null) return 0;
    final ms = until.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) return 0;
    return (ms / Duration.millisecondsPerDay).ceil();
  }

  /// Family words already redeemed on this device (each is one-time).
  List<String> get _familyRedeemed =>
      prefs.getStringList(_familyRedeemedKey) ?? const [];

  /// Redeem an owner family code (case-insensitive) for a [familyGrantDays]-day
  /// free window. Each word works ONCE per device; multiple grants stack onto
  /// the end of any active window.
  Future<FamilyCodeResult> redeemFamilyCode(String word) async {
    final w = word.trim().toLowerCase();
    if (!_familyCodes.contains(w)) return FamilyCodeResult.invalid;
    final done = _familyRedeemed.toList();
    if (done.contains(w)) return FamilyCodeResult.alreadyRedeemed;
    done.add(w);
    await prefs.setStringList(_familyRedeemedKey, done);
    // Stack: extend from the later of now / the current expiry.
    final now = DateTime.now();
    final base =
        (freeUntil != null && freeUntil!.isAfter(now)) ? freeUntil! : now;
    final until = base.add(const Duration(days: familyGrantDays));
    await prefs.setInt(_freeUntilKey, until.millisecondsSinceEpoch);
    return FamilyCodeResult.granted;
  }

  /// May the player start a game? True during the trial, an active free grant,
  /// or after purchase.
  bool get entitled =>
      purchased || inFreeGrant || trialDaysUsed <= trialDayAllowance;

  /// In the base trial window (not purchased, no free grant, still has days).
  bool get inTrial =>
      !purchased && !inFreeGrant && trialDaysUsed <= trialDayAllowance;

  // --- DEV/testing helpers (remove before store submission) ---

  /// Simulate an exhausted trial so the paywall appears.
  Future<void> devExpireTrial() async {
    await setPurchased(false);
    await prefs.remove(_bonusDaysKey);
    await prefs.remove(_promoRedeemedKey);
    await prefs.remove(_wafflesRedeemedKey);
    await prefs.remove(_freeUntilKey);
    await prefs.remove(_familyRedeemedKey);
    await prefs.setStringList(_playDaysKey,
        ['2000-01-01', '2000-01-02', '2000-01-03', '2000-01-04']);
  }

  /// Back to a brand-new trial (locked features usable again, day 1).
  Future<void> devResetTrial() async {
    await setPurchased(false);
    await prefs.remove(_bonusDaysKey);
    await prefs.remove(_promoRedeemedKey);
    await prefs.remove(_wafflesRedeemedKey);
    await prefs.remove(_freeUntilKey);
    await prefs.remove(_familyRedeemedKey);
    await prefs.remove(_playDaysKey);
    await recordOpenedToday();
  }
}

/// Outcome of trying to redeem the hidden trial-extension code.
enum TrialPromoResult { granted, alreadyRedeemed, alreadyOwned }

/// Outcome of trying to redeem a family (kid-nickname) free-access code.
enum FamilyCodeResult { granted, alreadyRedeemed, invalid }
