import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import 'settings_store.dart';

/// Plays haptics scaled to the user's chosen [HapticIntensity].
///
/// Android goes through the `vibration` package (real duration + amplitude),
/// because the built-in [HapticFeedback] impacts are too faint on many Android
/// devices. iOS maps to the native impact styles (which already feel right and
/// where the vibration package can't set amplitude anyway).
class HapticsService {
  final SettingsStore settings;
  bool _hasVibrator = false;
  bool _hasAmplitude = false;

  HapticsService(this.settings);

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isIOS => !kIsWeb && Platform.isIOS;

  Future<void> init() async {
    if (!_isAndroid) return; // iOS/other use HapticFeedback, no probing needed
    try {
      _hasVibrator = (await Vibration.hasVibrator()) == true;
      _hasAmplitude = (await Vibration.hasAmplitudeControl()) == true;
    } catch (_) {
      _hasVibrator = false;
    }
  }

  // Amplitude (1-255) and duration multiplier per level.
  int get _amplitude {
    switch (settings.hapticIntensity) {
      case HapticIntensity.low:
        return 80;
      case HapticIntensity.medium:
        return 160;
      case HapticIntensity.high:
        return 255;
      case HapticIntensity.off:
        return 0;
    }
  }

  double get _durationScale {
    switch (settings.hapticIntensity) {
      case HapticIntensity.low:
        return 0.55;
      case HapticIntensity.high:
        return 1.7;
      default:
        return 1.0;
    }
  }

  // --- semantic events (the UI calls these) ---

  /// Lightest — a single letter tap.
  void tap() => _buzz(11);

  /// A found/valid word.
  void success() => _buzz(24);

  /// Strongest — rank-up, perfect pangram, round complete.
  void strong() => _buzz(55);

  /// A rejected/invalid word — a distinct double pulse.
  void error() => _double(20, 28);

  /// Timer running low — a double warning pulse.
  void warn() => _double(30, 30);

  /// One-shot used to preview the level when the user changes the setting.
  void preview() => success();

  void _buzz(int baseMs) {
    if (settings.hapticIntensity == HapticIntensity.off) return;
    if (_isIOS) {
      _iosImpact();
      return;
    }
    if (!_isAndroid || !_hasVibrator) {
      HapticFeedback.selectionClick();
      return;
    }
    final ms = (baseMs * _durationScale).round().clamp(5, 220);
    try {
      if (_hasAmplitude) {
        Vibration.vibrate(duration: ms, amplitude: _amplitude);
      } else {
        Vibration.vibrate(duration: ms);
      }
    } catch (_) {}
  }

  /// Two quick pulses with a gap — used for error/warn so they feel distinct
  /// from the single-pulse success. Each pulse keeps the chosen amplitude.
  Future<void> _double(int firstMs, int secondMs) async {
    if (settings.hapticIntensity == HapticIntensity.off) return;
    _buzz(firstMs);
    await Future<void>.delayed(const Duration(milliseconds: 95));
    _buzz(secondMs);
  }

  void _iosImpact() {
    switch (settings.hapticIntensity) {
      case HapticIntensity.low:
        HapticFeedback.lightImpact();
        break;
      case HapticIntensity.high:
        HapticFeedback.heavyImpact();
        break;
      default:
        HapticFeedback.mediumImpact();
    }
  }
}
