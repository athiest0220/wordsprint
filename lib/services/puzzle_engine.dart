import '../models/puzzle.dart';
import 'dictionary.dart';

/// Deterministically builds the daily puzzles.
///
/// Given the same [Dictionary] and the same (date, size), [generate] always
/// returns an identical puzzle — that is what lets every device share the same
/// "daily" without a server. All randomness flows through a seeded generator
/// ([_Rng]) whose algorithm is fixed here rather than relying on the platform.
class PuzzleEngine {
  final Dictionary dict;

  PuzzleEngine(this.dict);

  /// Minimum word length per letter-count, as specified by the game rules.
  static const Map<int, int> minWordLength = {
    6: 3,
    7: 4,
    8: 5,
    9: 5,
    10: 6,
    11: 7,
  };

  /// The 'S' bit — excluded from letter sets (NYT convention) so puzzles don't
  /// devolve into trivial plurals.
  static final int _sBit = 1 << ('s'.codeUnitAt(0) - 0x61);

  /// Acceptable count of valid words, per size: (floor, target, ceiling).
  /// Larger sets have higher minimum lengths, so they naturally yield fewer
  /// words — the bands shrink accordingly.
  static const Map<int, List<int>> _wordBand = {
    6: [30, 60, 120],
    7: [20, 38, 65],
    8: [16, 32, 58],
    9: [14, 28, 52],
    10: [11, 22, 46],
    11: [9, 18, 40],
  };

  static const List<int> sizes = [6, 7, 8, 9, 10, 11];

  /// Strip a DateTime down to a local calendar date.
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// The persistence key for a puzzle. Variant 0 is the plain daily; a bumped
  /// variant ("New letters" reroll) gets its own key so progress starts fresh.
  static String keyFor(DateTime d, int size, int variant) => variant == 0
      ? '${dateKey(d)}#$size'
      : '${dateKey(d)}#$size#v$variant';

  /// Generate the puzzle for [date]/[size]. A non-zero [variant] re-rolls the
  /// letters (and gives the result its own key).
  Puzzle generate(DateTime date, int size, {int variant = 0}) {
    final day = dateOnly(date);
    final p = _generate(day, size, variant);
    return variant == 0 ? p : p.withCustomKey(keyFor(day, size, variant));
  }

  Puzzle _generate(DateTime day, int size, int variant) {
    assert(sizes.contains(size), 'size must be 6..11');
    final minLen = minWordLength[size]!;
    final band = _wordBand[size]!;
    final floor = band[0], target = band[1], ceil = band[2];

    // Seed is a pure function of (date, size, variant) so it's reproducible.
    final seed = _seed(day, size, variant);
    final rng = _Rng(seed);

    // 1. Collect candidate letter sets: masks of words with exactly `size`
    //    distinct letters, no 'S', and long enough to be a pangram. Each such
    //    word guarantees its set has at least one pangram. A set is also
    //    "perfect-capable" if some length-`size` isogram maps to it — those
    //    sets have a perfect pangram (uses each letter exactly once).
    final candidateSet = <int>{};
    final perfectCapable = <int>{};
    for (var i = 0; i < dict.words.length; i++) {
      if (dict.lengths[i] < minLen) continue;
      final m = dict.masks[i];
      if (m & _sBit != 0) continue;
      if (Dictionary.popcount(m) == size) {
        candidateSet.add(m);
        if (dict.lengths[i] == size) perfectCapable.add(m); // isogram
      }
    }
    var candidates = candidateSet.toList()..sort(); // deterministic order
    _shuffle(candidates, rng);

    // Roughly half of all days, front-load perfect-capable sets so the
    // "time to perfect pangram" clock actually gets exercised — while still
    // leaving plenty of days with no perfect pangram, as intended.
    final preferPerfect = ((seed >> 3) & 1) == 1 && perfectCapable.isNotEmpty;
    if (preferPerfect) {
      final pref = <int>[];
      final rest = <int>[];
      for (final m in candidates) {
        (perfectCapable.contains(m) ? pref : rest).add(m);
      }
      candidates = [...pref, ...rest]; // preserves shuffle order within groups
    }

    // 2. Try candidates until one lands in the target band. Keep the closest
    //    fallback so we always return a playable puzzle.
    _Build? best;
    var bestDist = 1 << 30;
    const searchCap = 400;

    for (var c = 0; c < candidates.length && c < searchCap; c++) {
      final setMask = candidates[c];
      final letterBits = _bitsOf(setMask);

      // Evaluate each possible center letter for this set.
      final order = List<int>.from(letterBits);
      _shuffle(order, rng);
      for (final centerBit in order) {
        final build = _evaluate(setMask, centerBit, size, minLen);
        if (build.validWords.length < floor) continue;
        final dist = (build.validWords.length - target).abs();
        if (build.validWords.length <= ceil && build.pangrams.isNotEmpty) {
          // In-band and has a pangram: accept immediately.
          return _finish(day, size, setMask, centerBit, minLen, build);
        }
        if (build.pangrams.isNotEmpty && dist < bestDist) {
          bestDist = dist;
          best = build.withCenter(setMask, centerBit);
        }
      }
    }

    // 3. Fallback: closest by word-count that still has a pangram.
    if (best != null) {
      return _finish(
          day, size, best.setMask, best.centerBit, minLen, best);
    }

    // 4. Last resort (essentially never hit): first candidate, first letter.
    final setMask = candidates.first;
    final centerBit = _bitsOf(setMask).first;
    final build = _evaluate(setMask, centerBit, size, minLen);
    return _finish(day, size, setMask, centerBit, minLen, build);
  }

  /// Scan the dictionary for every word buildable from [setMask] that contains
  /// the center letter and is long enough.
  _Build _evaluate(int setMask, int centerBit, int size, int minLen) {
    final valid = <String>{};
    final pangrams = <String>{};
    final perfect = <String>{};
    final notSet = ~setMask;
    for (var i = 0; i < dict.words.length; i++) {
      if (dict.lengths[i] < minLen) continue;
      final m = dict.masks[i];
      if (m & notSet != 0) continue; // uses a letter outside the set
      if (m & centerBit == 0) continue; // missing the required letter
      final w = dict.words[i];
      valid.add(w);
      if (m == setMask) {
        pangrams.add(w);
        if (w.length == size) perfect.add(w);
      }
    }
    return _Build(valid, pangrams, perfect);
  }

  Puzzle _finish(DateTime day, int size, int setMask, int centerBit, int minLen,
      _Build b,
      {String? customKey, String? title, bool isImport = false}) {
    final letters = _lettersOf(setMask);
    final center = _letterOf(centerBit);
    var maxScore = 0;
    // Score each valid word with the same rule the Puzzle uses.
    for (final w in b.validWords) {
      var pts = w.length == minLen ? 1 : w.length;
      if (b.pangrams.contains(w)) pts += size;
      maxScore += pts;
    }
    return Puzzle(
      date: day,
      size: size,
      letters: letters,
      center: center,
      minWordLength: minLen,
      validWords: b.validWords,
      pangrams: b.pangrams,
      perfectPangrams: b.perfect,
      maxScore: maxScore,
      customKey: customKey,
      title: title,
      isImport: isImport,
    );
  }

  /// Build a puzzle from an explicit set of [letters] and a [center] letter —
  /// e.g. importing today's NYT Spelling Bee. Valid words are computed from the
  /// bundled dictionary (so completion reflects our word list, not NYT's). The
  /// letter 'S' is allowed here, unlike the generated dailies.
  Puzzle generateCustom({
    required List<String> letters,
    required String center,
    required String customKey,
    String? title,
  }) {
    final upper = letters.map((e) => e.toUpperCase()).toList();
    final size = upper.length;
    final minLen = minWordLength[size] ?? 4;
    var setMask = 0;
    for (final l in upper) {
      setMask |= Dictionary.maskOf(l.toLowerCase());
    }
    final centerBit = Dictionary.maskOf(center.toLowerCase());
    final build = _evaluate(setMask, centerBit, size, minLen);
    return _finish(dateOnly(DateTime(2000)), size, setMask, centerBit, minLen,
        build,
        customKey: customKey, title: title, isImport: true);
  }

  // ---- helpers ----

  int _seed(DateTime day, int size, int variant) {
    // Mix date, size and variant into a 32-bit seed.
    final dateInt = day.year * 10000 + day.month * 100 + day.day;
    var h = dateInt * 2654435761 + size * 40503 + variant * 2246822519;
    h ^= h >> 16;
    h = (h * 0x45d9f3b) & 0xFFFFFFFF;
    h ^= h >> 16;
    return h & 0xFFFFFFFF;
  }

  void _shuffle(List<int> list, _Rng rng) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  List<int> _bitsOf(int mask) {
    final bits = <int>[];
    for (var i = 0; i < 26; i++) {
      if (mask & (1 << i) != 0) bits.add(1 << i);
    }
    return bits;
  }

  List<String> _lettersOf(int mask) {
    final out = <String>[];
    for (var i = 0; i < 26; i++) {
      if (mask & (1 << i) != 0) {
        out.add(String.fromCharCode(0x41 + i)); // uppercase
      }
    }
    return out;
  }

  String _letterOf(int bit) {
    for (var i = 0; i < 26; i++) {
      if (bit == 1 << i) return String.fromCharCode(0x41 + i);
    }
    throw ArgumentError('not a single-letter bit');
  }
}

class _Build {
  final Set<String> validWords;
  final Set<String> pangrams;
  final Set<String> perfect;
  int setMask = 0;
  int centerBit = 0;
  _Build(this.validWords, this.pangrams, this.perfect);

  _Build withCenter(int setMask, int centerBit) {
    this.setMask = setMask;
    this.centerBit = centerBit;
    return this;
  }
}

/// Mulberry32 — a tiny, fully-deterministic 32-bit PRNG. Chosen over
/// dart:math Random so puzzle generation never depends on SDK internals.
class _Rng {
  int _state;
  _Rng(int seed) : _state = seed & 0xFFFFFFFF;

  int _next() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = (t ^ (t >> 15)) * (t | 1) & 0xFFFFFFFF;
    t ^= t + ((t ^ (t >> 7)) * (t | 61) & 0xFFFFFFFF);
    t &= 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  /// Uniform int in [0, bound).
  int nextInt(int bound) => _next() % bound;
}
