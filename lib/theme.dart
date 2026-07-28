import 'package:flutter/material.dart';

/// SpeedBee palette — a cool blue system on deep blue-black. Tuned for a game
/// mostly played in dark rooms; the accent blue carries the brand and the
/// 3D cubes, gold is reserved for the rare "perfect pangram".
class BeeColors {
  static const accent = Color(0xFF3D8BFF); // primary blue
  static const accentDeep = Color(0xFF1E63D6);

  // Legacy alias so older references keep working (now blue, not honey).
  static const honey = accent;
  static const honeyDeep = accentDeep;

  // Cube faces.
  static const centerFace = Color(0xFF2F6FED);
  static const centerFaceTop = Color(0xFF5B92F5);
  static const centerFaceSide = Color(0xFF1C4FB0);
  static const outerFace = Color(0xFF2C3444);
  static const outerFaceTop = Color(0xFF3C4658);
  static const outerFaceSide = Color(0xFF1B2130);
  static const cellText = Color(0xFFECEFF4);
  static const outerCellText = Color(0xFFECEFF4);

  // Bubble base colors (a bright accent center, brighter blue outers so the
  // board doesn't read as dark/gray).
  static const bubbleCenter = Color(0xFF3D8BFF);
  static const bubbleOuter = Color(0xFF6885BE);

  static const bg = Color(0xFF161E2E);
  static const surface = Color(0xFF1F2A3D);
  static const surfaceHi = Color(0xFF2C3A54);

  static const good = Color(0xFF5FD08A);
  static const bad = Color(0xFFF0736B);
  static const pangram = Color(0xFF3D8BFF); // blue
  static const perfect = Color(0xFFF5C542); // gold — pops against blue
  static const muted = Color(0xFF8791A6);
}

/// Progressive rank colors — blue → violet → magenta → amber, climbing to the
/// perfect-pangram gold at Flawless. Shared by the game and home screens.
Color rankColor(String rank) {
  switch (rank) {
    case "Bachelor's":
      return const Color(0xFF5B9BF0); // blue
    case "Master's":
      return const Color(0xFF8E7BEF); // indigo
    case 'Doctorate':
      return const Color(0xFFC56BE0); // purple
    case 'Professor':
      return const Color(0xFFF59E4B); // amber
    case 'Flawless':
      return BeeColors.perfect; // gold
    case 'Student':
      return const Color(0xFF8AA0C6); // steel blue
    default:
      return BeeColors.accent;
  }
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: BeeColors.bg,
    cardColor: BeeColors.surface,
    colorScheme: base.colorScheme.copyWith(
      primary: BeeColors.accent,
      secondary: BeeColors.accentDeep,
      surface: BeeColors.surface,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: BeeColors.cellText,
      displayColor: BeeColors.cellText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: BeeColors.bg,
      elevation: 0,
      centerTitle: true,
    ),
  );
}
