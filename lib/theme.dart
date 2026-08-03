import 'package:flutter/material.dart';

/// App-wide theme mode. Seeded from [SettingsStore.themeMode] once the repo
/// loads, and updated live by the Settings screen; [MaterialApp] listens.
final ValueNotifier<ThemeMode> appThemeMode =
    ValueNotifier<ThemeMode>(ThemeMode.system);

/// Word Sprint palette. Brand/semantic colors (accent blue, gold, green/red,
/// the game bubbles) are the same in light and dark; surfaces and text flip
/// with [BeeColors.brightness], which [MaterialApp.builder] sets once per frame
/// from the active theme. This lets the ~200 existing `BeeColors.x` references
/// keep working while gaining a light theme.

// Dark surfaces/text (original look).
const _bgD = Color(0xFF161E2E);
const _surfD = Color(0xFF1F2A3D);
const _surfHiD = Color(0xFF2C3A54);
const _textD = Color(0xFFECEFF4);
const _mutedD = Color(0xFF8791A6);
const _outerFaceD = Color(0xFF2C3444);
const _outerFaceTopD = Color(0xFF3C4658);
const _outerFaceSideD = Color(0xFF1B2130);

// Light surfaces/text — clean & bright.
const _bgL = Color(0xFFF6F8FC);
const _surfL = Color(0xFFFFFFFF);
const _surfHiL = Color(0xFFE9EEF6);
const _textL = Color(0xFF14203A);
const _mutedL = Color(0xFF5C6880);
const _outerFaceL = Color(0xFFDCE4F0);
const _outerFaceTopL = Color(0xFFEDF1F8);
const _outerFaceSideL = Color(0xFFC4CFE0);

class BeeColors {
  /// Set once per frame from [MaterialApp.builder]; drives the getters below.
  static Brightness brightness = Brightness.dark;
  static bool get _l => brightness == Brightness.light;

  // --- brand / semantic (identical in both themes) ---
  static const accent = Color(0xFF3D8BFF); // primary blue
  static const accentDeep = Color(0xFF1E63D6);
  static const honey = accent; // legacy alias
  static const honeyDeep = accentDeep;

  static const centerFace = Color(0xFF2F6FED);
  static const centerFaceTop = Color(0xFF5B92F5);
  static const centerFaceSide = Color(0xFF1C4FB0);

  static const bubbleCenter = Color(0xFF3D8BFF);
  static const bubbleOuter = Color(0xFF6885BE);

  static const good = Color(0xFF5FD08A);
  static const bad = Color(0xFFF0736B);
  static const pangram = Color(0xFF3D8BFF);
  static const perfect = Color(0xFFF5C542); // gold

  /// White letters on the blue bubbles — fixed in both themes.
  static const bubbleText = Color(0xFFFFFFFF);

  // Fixed dark values for always-dark surfaces (the share / result cards are
  // captured to images and must NOT follow the light theme).
  static const darkText = _textD;
  static const darkMuted = _mutedD;
  static const darkSurface = _surfD;
  static const darkSurfaceHi = _surfHiD;

  // --- surfaces & text (flip with brightness) ---
  static Color get bg => _l ? _bgL : _bgD;
  static Color get surface => _l ? _surfL : _surfD;
  static Color get surfaceHi => _l ? _surfHiL : _surfHiD;
  static Color get cellText => _l ? _textL : _textD;
  static Color get outerCellText => _l ? _textL : _textD;
  static Color get muted => _l ? _mutedL : _mutedD;
  static Color get outerFace => _l ? _outerFaceL : _outerFaceD;
  static Color get outerFaceTop => _l ? _outerFaceTopL : _outerFaceTopD;
  static Color get outerFaceSide => _l ? _outerFaceSideL : _outerFaceSideD;
}

/// Progressive rank colors — the same in both themes (they read on either bg).
Color rankColor(String rank) {
  switch (rank) {
    case "Bachelor's":
      return const Color(0xFF5B9BF0);
    case "Master's":
      return const Color(0xFF8E7BEF);
    case 'Doctorate':
      return const Color(0xFFC56BE0);
    case 'Professor':
      return const Color(0xFFF59E4B);
    case 'Flawless':
      return BeeColors.perfect;
    case 'Student':
      return const Color(0xFF8AA0C6);
    default:
      return BeeColors.accent;
  }
}

ThemeData _theme(Brightness b) {
  final light = b == Brightness.light;
  final base =
      (light ? ThemeData.light(useMaterial3: true) : ThemeData.dark(useMaterial3: true));
  final bg = light ? _bgL : _bgD;
  final surface = light ? _surfL : _surfD;
  final surfaceHi = light ? _surfHiL : _surfHiD;
  final text = light ? _textL : _textD;

  return base.copyWith(
    scaffoldBackgroundColor: bg,
    cardColor: surface,
    dividerColor: surfaceHi,
    colorScheme: base.colorScheme.copyWith(
      primary: BeeColors.accent,
      secondary: BeeColors.accentDeep,
      surface: surface,
      onSurface: text,
      error: BeeColors.bad,
    ),
    textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      centerTitle: true,
    ),
    iconTheme: IconThemeData(color: text),
    listTileTheme: ListTileThemeData(textColor: text, iconColor: BeeColors.accent),
    dialogTheme: DialogThemeData(backgroundColor: surface),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceHi,
      contentTextStyle: TextStyle(color: text),
    ),
  );
}

ThemeData buildDarkTheme() => _theme(Brightness.dark);
ThemeData buildLightTheme() => _theme(Brightness.light);

/// Legacy entry point (kept so any old references compile) — dark theme.
ThemeData buildTheme() => buildDarkTheme();
