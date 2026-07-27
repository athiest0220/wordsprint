// Offline generator: precompute the no-repeat daily cycle for the large sizes
// (10 & 11), where English offers too few "reasonable" letter-sets for the live
// generator to vary well. Writes assets/daily_pools.json:
//   { "10": [["ABCDEFGHIJ","F"], ...], "11": [...] }
// The app walks each list by day number, so puzzles cycle with no repeat until
// the whole pool is used, and word counts stay in the target range.
//
// Run:  dart run tool/gen_daily_pools.dart
import 'dart:convert';
import 'dart:io';
import '../lib/services/dictionary.dart';
import '../lib/services/puzzle_engine.dart';

// Target word-count window per size (valid words at the chosen center).
const ranges = {
  10: [30, 110],
  11: [45, 110],
};

void main() {
  final dict = Dictionary.fromText(File('assets/words.txt').readAsStringSync());
  final sBit = 1 << ('s'.codeUnitAt(0) - 0x61);
  final out = <String, List<List<String>>>{};

  for (final size in [10, 11]) {
    final minLen = PuzzleEngine.minWordLength[size]!;
    final lo = ranges[size]![0], hi = ranges[size]![1];
    final mid = (lo + hi) ~/ 2;

    // candidate sets
    final cands = <int>{};
    for (var i = 0; i < dict.words.length; i++) {
      if (dict.lengths[i] < minLen) continue;
      final m = dict.masks[i];
      if (m & sBit != 0) continue;
      if (Dictionary.popcount(m) == size) cands.add(m);
    }

    // For each set, pick the center whose word count is in [lo,hi] and closest
    // to the middle of the range.
    final pool = <List<int>>[]; // [setMask, centerBit, count]
    final counts = <int>[];
    for (final setMask in cands) {
      final notSet = ~setMask;
      int? bestCenter;
      var bestCount = 0, bestDist = 1 << 30;
      for (var b = 0; b < 26; b++) {
        final centerBit = 1 << b;
        if (setMask & centerBit == 0) continue;
        var count = 0;
        for (var i = 0; i < dict.words.length; i++) {
          if (dict.lengths[i] < minLen) continue;
          final m = dict.masks[i];
          if (m & notSet != 0) continue;
          if (m & centerBit == 0) continue;
          count++;
        }
        if (count < lo || count > hi) continue;
        final d = (count - mid).abs();
        if (d < bestDist) {
          bestDist = d;
          bestCenter = centerBit;
          bestCount = count;
        }
      }
      if (bestCenter != null) {
        pool.add([setMask, bestCenter, bestCount]);
        counts.add(bestCount);
      }
    }

    // Stable shuffle (seeded by size) so the daily sequence looks random but is
    // fixed and reproducible.
    _shuffle(pool, size * 2654435761 & 0x7fffffff);

    out['$size'] = pool.map((e) {
      final letters = _lettersOf(e[0]);
      final center = _letterOf(e[1]);
      return [letters, center];
    }).toList();

    counts.sort();
    final med = counts.isEmpty ? 0 : counts[counts.length ~/ 2];
    print('size $size: pool=${pool.length}  words ${counts.isEmpty ? "-" : "${counts.first}..${counts.last}"} median=$med  '
        '(no repeat for ${pool.length} days = ${(pool.length / 30).toStringAsFixed(1)} months)');
  }

  File('assets/daily_pools.json').writeAsStringSync(jsonEncode(out));
  print('wrote assets/daily_pools.json');
}

void _shuffle(List list, int seed) {
  var s = seed & 0xFFFFFFFF;
  int next() {
    s = (s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = s;
    t = (t ^ (t >> 15)) * (t | 1) & 0xFFFFFFFF;
    t ^= t + ((t ^ (t >> 7)) * (t | 61) & 0xFFFFFFFF);
    t &= 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  for (var i = list.length - 1; i > 0; i--) {
    final j = next() % (i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
}

String _lettersOf(int mask) {
  final out = <String>[];
  for (var i = 0; i < 26; i++) {
    if (mask & (1 << i) != 0) out.add(String.fromCharCode(0x41 + i));
  }
  return out.join();
}

String _letterOf(int bit) {
  for (var i = 0; i < 26; i++) {
    if (bit == 1 << i) return String.fromCharCode(0x41 + i);
  }
  throw ArgumentError('bad bit');
}
