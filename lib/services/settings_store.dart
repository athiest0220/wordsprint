import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import 'puzzle_engine.dart';

/// Haptic strength the player picks. [off] disables vibration entirely.
enum HapticIntensity { off, low, medium, high }

/// A simple low/medium/high level (used for sound/music volume storage).
enum AudioLevel { low, medium, high }

/// A four-way off/low/medium/high picker (used for the uniform sound & music
/// controls, matching the haptics control's shape).
enum LevelSetting { off, low, medium, high }

/// Map an enabled flag + volume to the four-way picker value.
LevelSetting levelFromAudio(bool enabled, AudioLevel v) {
  if (!enabled) return LevelSetting.off;
  switch (v) {
    case AudioLevel.low:
      return LevelSetting.low;
    case AudioLevel.medium:
      return LevelSetting.medium;
    case AudioLevel.high:
      return LevelSetting.high;
  }
}

/// Map a (non-off) picker value to a stored volume level (off falls back to
/// medium, which is only used as the volume once switched back on).
AudioLevel audioFromLevel(LevelSetting l) {
  switch (l) {
    case LevelSetting.low:
      return AudioLevel.low;
    case LevelSetting.high:
      return AudioLevel.high;
    case LevelSetting.medium:
    case LevelSetting.off:
      return AudioLevel.medium;
  }
}

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

  static const _hapticsKey = 'speedbee.haptics'; // legacy on/off (pre-intensity)
  static const _hapticIntensityKey = 'speedbee.hapticIntensity';

  /// Selected haptic strength. Falls back to migrating the old on/off toggle:
  /// old "on" -> medium, old "off" -> off; brand-new installs default medium
  /// (the previous default felt too faint on Android).
  HapticIntensity get hapticIntensity {
    final s = prefs.getString(_hapticIntensityKey);
    if (s != null) {
      for (final v in HapticIntensity.values) {
        if (v.name == s) return v;
      }
    }
    if (prefs.getBool(_hapticsKey) == false) return HapticIntensity.off;
    return HapticIntensity.medium;
  }

  Future<void> setHapticIntensity(HapticIntensity value) =>
      prefs.setString(_hapticIntensityKey, value.name);

  /// Convenience for older call sites: haptics are on unless set to [off].
  bool get hapticsEnabled => hapticIntensity != HapticIntensity.off;

  static const _soundKey = 'speedbee.sound';

  /// Whether game sound effects play. Default on.
  bool get soundEnabled => prefs.getBool(_soundKey) ?? true;
  Future<void> setSoundEnabled(bool value) => prefs.setBool(_soundKey, value);

  static const _soundVolumeKey = 'speedbee.soundVolume';

  /// Sound-effect loudness. Defaults to medium.
  AudioLevel get soundVolume {
    switch (prefs.getString(_soundVolumeKey)) {
      case 'low':
        return AudioLevel.low;
      case 'high':
        return AudioLevel.high;
      default:
        return AudioLevel.medium;
    }
  }

  Future<void> setSoundVolume(AudioLevel value) =>
      prefs.setString(_soundVolumeKey, value.name);

  /// Sound effects as a single off/low/med/high control.
  LevelSetting get soundLevel => levelFromAudio(soundEnabled, soundVolume);
  Future<void> setSoundLevel(LevelSetting l) async {
    if (l == LevelSetting.off) {
      await setSoundEnabled(false);
    } else {
      await setSoundEnabled(true);
      await setSoundVolume(audioFromLevel(l));
    }
  }

  static const _musicKey = 'speedbee.music';

  /// Whether the background soundtrack plays. Default on.
  bool get musicEnabled => prefs.getBool(_musicKey) ?? true;
  Future<void> setMusicEnabled(bool value) => prefs.setBool(_musicKey, value);

  static const _musicTrackKey = 'speedbee.musicTrack';

  /// Which soundtrack selection is active: the sentinel 'shuffle' (default) to
  /// rotate through all tracks, or a specific track id (see [AudioService]).
  String get musicTrack => prefs.getString(_musicTrackKey) ?? 'shuffle';
  Future<void> setMusicTrack(String value) =>
      prefs.setString(_musicTrackKey, value);

  static const _musicVolumeKey = 'speedbee.musicVolume';

  /// Background-music loudness. Defaults to medium.
  AudioLevel get musicVolume {
    switch (prefs.getString(_musicVolumeKey)) {
      case 'low':
        return AudioLevel.low;
      case 'high':
        return AudioLevel.high;
      default:
        return AudioLevel.medium;
    }
  }

  Future<void> setMusicVolume(AudioLevel value) =>
      prefs.setString(_musicVolumeKey, value.name);

  /// Background music as a single off/low/med/high control.
  LevelSetting get musicLevel => levelFromAudio(musicEnabled, musicVolume);
  Future<void> setMusicLevel(LevelSetting l) async {
    if (l == LevelSetting.off) {
      await setMusicEnabled(false);
    } else {
      await setMusicEnabled(true);
      await setMusicVolume(audioFromLevel(l));
    }
  }

  static const _themeModeKey = 'speedbee.themeMode';

  /// Light / dark / system theme preference. Defaults to following the OS.
  ThemeMode get themeMode {
    switch (prefs.getString(_themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode value) =>
      prefs.setString(_themeModeKey, value.name);

  static const _showOopsKey = 'speedbee.showOops';

  /// When true (default), the game shows the "Oops" mistake counter. Players
  /// who find it discouraging can hide it.
  bool get showOops => prefs.getBool(_showOopsKey) ?? true;
  Future<void> setShowOops(bool value) =>
      prefs.setBool(_showOopsKey, value);

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
