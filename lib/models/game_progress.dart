import 'dart:convert';

/// Persisted state for one player's attempt at one puzzle (identified by
/// [Puzzle.key]). Lets a player resume mid-game and keeps the three milestone
/// times once achieved.
class GameProgress {
  final String puzzleKey;
  final Set<String> foundWords;

  /// Accumulated *active* play time in ms — the clock only advances while the
  /// game screen is foregrounded, so leaving and resuming doesn't inflate it.
  int elapsedMs;

  int? pangramMs; // active-time when the first pangram was found
  int? perfectMs; // ...first perfect pangram (null if the puzzle has none)
  int? completeMs; // ...when every valid word had been found

  /// Count of rejected guesses ("oops") — not-a-word, too short, missing
  /// center, or bad letter. Duplicates and empty entries don't count.
  int oopsCount;

  /// The player tapped "Give Up for Today": the answers are revealed and the
  /// game ends, but the score and any milestone times are kept.
  bool gaveUp;

  /// Which milestones have already been folded into aggregate stats, so a
  /// resumed game never double-counts.
  bool pangramRecorded;
  bool perfectRecorded;
  bool completeRecorded;
  bool startedRecorded;

  /// The end-of-game roll-up (oops rate) has been folded into stats.
  bool endRecorded;

  GameProgress({
    required this.puzzleKey,
    Set<String>? foundWords,
    this.elapsedMs = 0,
    this.pangramMs,
    this.perfectMs,
    this.completeMs,
    this.oopsCount = 0,
    this.gaveUp = false,
    this.pangramRecorded = false,
    this.perfectRecorded = false,
    this.completeRecorded = false,
    this.startedRecorded = false,
    this.endRecorded = false,
  }) : foundWords = foundWords ?? <String>{};

  Map<String, dynamic> toJson() => {
        'k': puzzleKey,
        'w': foundWords.toList(),
        'e': elapsedMs,
        'pa': pangramMs,
        'pe': perfectMs,
        'co': completeMs,
        'oops': oopsCount,
        'gu': gaveUp,
        'par': pangramRecorded,
        'per': perfectRecorded,
        'cor': completeRecorded,
        'str': startedRecorded,
        'endr': endRecorded,
      };

  factory GameProgress.fromJson(Map<String, dynamic> j) => GameProgress(
        puzzleKey: j['k'] as String,
        foundWords: (j['w'] as List).map((e) => e as String).toSet(),
        elapsedMs: j['e'] as int? ?? 0,
        pangramMs: j['pa'] as int?,
        perfectMs: j['pe'] as int?,
        completeMs: j['co'] as int?,
        oopsCount: j['oops'] as int? ?? 0,
        gaveUp: j['gu'] as bool? ?? false,
        pangramRecorded: j['par'] as bool? ?? false,
        perfectRecorded: j['per'] as bool? ?? false,
        completeRecorded: j['cor'] as bool? ?? false,
        startedRecorded: j['str'] as bool? ?? false,
        endRecorded: j['endr'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());
  static GameProgress decode(String s) =>
      GameProgress.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
