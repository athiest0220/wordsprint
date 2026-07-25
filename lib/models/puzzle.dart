/// A single day's puzzle for a given letter-count.
///
/// A puzzle is fully determined by its [date] and [size], so every device that
/// runs the same app version computes an identical puzzle for a given day — no
/// server required. See [PuzzleEngine].
class Puzzle {
  /// Calendar date the puzzle belongs to (time component is stripped).
  final DateTime date;

  /// Number of letters in the wheel (7..11).
  final int size;

  /// The [size] distinct letters, uppercase, sorted alphabetically.
  final List<String> letters;

  /// The required "center" letter — classic Spelling Bee rule: every valid
  /// word must contain it. Uppercase.
  final String center;

  /// Minimum length a word must have to count.
  final int minWordLength;

  /// Every acceptable word (lowercase).
  final Set<String> validWords;

  /// Words that use all [size] letters at least once (lowercase).
  final Set<String> pangrams;

  /// Pangrams that are exactly [size] letters long — use each letter once.
  final Set<String> perfectPangrams;

  /// Sum of the points of every valid word — the "Queen Bee" ceiling.
  final int maxScore;

  /// When set, overrides the date-based [key] — used for imported/custom
  /// puzzles (e.g. an NYT Spelling Bee set) so they don't collide with the
  /// same-day daily puzzle of the same size.
  final String? customKey;

  /// Label shown instead of "N Letters" for custom puzzles (e.g. "NYT Bee").
  final String? title;

  /// True only for externally-imported puzzles (e.g. the NYT Spelling Bee).
  /// A rerolled daily also has a [customKey] but is NOT an import.
  final bool isImport;

  const Puzzle({
    required this.date,
    required this.size,
    required this.letters,
    required this.center,
    required this.minWordLength,
    required this.validWords,
    required this.pangrams,
    required this.perfectPangrams,
    required this.maxScore,
    this.customKey,
    this.title,
    this.isImport = false,
  });

  bool get isCustom => customKey != null;

  /// A personal practice reroll ("New letters") — has a custom key but is not
  /// an import. These are NOT shareable (only the real daily and imports are).
  bool get isReroll => customKey != null && !isImport;

  /// A copy with a specific persistence key (used by the "New letters" reroll).
  Puzzle withCustomKey(String key) => Puzzle(
        date: date,
        size: size,
        letters: letters,
        center: center,
        minWordLength: minWordLength,
        validWords: validWords,
        pangrams: pangrams,
        perfectPangrams: perfectPangrams,
        maxScore: maxScore,
        customKey: key,
        title: title,
        isImport: isImport,
      );

  bool get hasPerfectPangram => perfectPangrams.isNotEmpty;

  /// Points for a single word, using NYT-style scoring:
  /// a minimum-length word scores 1, longer words score their length, and a
  /// pangram earns a +[size] bonus on top.
  int scoreFor(String word) {
    final w = word.toLowerCase();
    var pts = w.length == minWordLength ? 1 : w.length;
    if (pangrams.contains(w)) pts += size;
    return pts;
  }

  bool isPangram(String word) => pangrams.contains(word.toLowerCase());

  bool isPerfectPangram(String word) =>
      perfectPangrams.contains(word.toLowerCase());

  /// A stable key ("2026-07-24#8") used for persisting per-puzzle state.
  /// Custom puzzles use [customKey] instead so they persist independently.
  String get key =>
      customKey ??
      '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}#$size';

  /// Rank tiers as (label, fractionOfMax) pairs, ascending. Mirrors the NYT
  /// ladder: Genius unlocks at 70%, Queen Bee at 100%.
  /// Academic-themed ranks (fits the book/dictionary motif). Professor is the
  /// motivating "Genius"-level tier (70%); Flawless is every word (100%).
  static const List<MapEntry<String, double>> rankTiers = [
    MapEntry('Student', 0.0),
    MapEntry("Bachelor's", 0.25),
    MapEntry("Master's", 0.50),
    MapEntry('Doctorate', 0.75),
    MapEntry('Professor', 0.90),
    MapEntry('Flawless', 1.0),
  ];

  /// Rank label for a given accumulated score.
  String rankFor(int score) {
    final frac = maxScore == 0 ? 0.0 : score / maxScore;
    var label = rankTiers.first.key;
    for (final tier in rankTiers) {
      if (frac >= tier.value) label = tier.key;
    }
    return label;
  }

  /// Score needed to reach the next rank above [score], or null if at the top.
  int? scoreForNextRank(int score) {
    final frac = maxScore == 0 ? 0.0 : score / maxScore;
    for (final tier in rankTiers) {
      if (tier.value > frac) return (tier.value * maxScore).ceil();
    }
    return null;
  }
}
