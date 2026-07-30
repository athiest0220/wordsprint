import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../lib/services/dictionary.dart';

/// Anchor/pangram words to keep OUT of the dailies even though they're frequent
/// enough to qualify: medical, chemistry & physics jargon, obscure/foreign
/// oddities, and anything off-tone for a 13+ game. Add to this freely — a
/// blocked word simply drops that puzzle from the pool. (They remain valid to
/// *find*, just never the headline pangram.)
const _blockedWords = {
  // medical / anatomy / drugs
  'doxycycline', 'zygomatic', 'chloroquine', 'conjunctivae', 'conjunctival',
  'fluphenazine', 'hemolyzing', 'hepatotoxicity', 'hydroxyzine', 'hypoxanthine',
  'methaqualone', 'diaphragmatic', 'exophthalmic', 'oxyhemoglobin',
  'pneumothorax',
  // chemistry / physics / lab
  'chromatograph', 'hydrazine', 'chlorofluorocarbon', 'dicarboxylic',
  'enzymatically', 'hexachlorophene', 'hydroquinone', 'methoxychlor',
  'mycorrhizal', 'piezoelectricity', 'hydrophobicity', 'fluidization',
  'cyclohexylamine', 'monocarboxylic', 'trapezohedron', 'microquake',
  // obscure / foreign / odd
  'katzenjammer', 'gemutlichkeit', 'archaeopteryx', 'picturization',
  'cockalorum', 'boniface', 'lightwood',
};

/// Any anchor containing one of these is dropped (covers all inflections of
/// off-tone roots).
const _blockedParts = ['ejaculat', 'dominatrix'];

bool _blocked(String w) {
  if (_blockedWords.contains(w)) return true;
  for (final p in _blockedParts) {
    if (w.contains(p)) return true;
  }
  return false;
}

/// Rebuilds assets/daily_pools.json for ALL sizes (6-11) so every daily puzzle
/// is anchored on a COMMON word (its pangram is something people know), never
/// repeats within a long cycle, and keeps word-root near-twins (bivouacking /
/// bivouacked) out of the same pool.
///
/// The full dictionary (assets/words.txt) is still used to decide which words
/// are *valid to find* — obscure finds stay a bonus, they're just never the
/// anchor/pangram. "Common" = a word that appears in the top-N of a frequency
/// ranked list (Norvig's Google-corpus count_1w.txt), intersected with our dict.
///
/// Usage: dart run tool/build_pools.dart <topN> <freqPath> <outPath>
void main(List<String> args) {
  final topN = args.isNotEmpty ? int.parse(args[0]) : 50000;
  final freqPath = args.length > 1 ? args[1] : 'count_1w.txt';
  final outPath = args.length > 2 ? args[2] : 'assets/daily_pools.json';

  const minWordLength = {6: 3, 7: 4, 8: 5, 9: 5, 10: 6, 11: 7};
  // Word-count band [floor, target, ceiling] a pooled puzzle must land in.
  // Big sizes get a lower floor: common 10/11-distinct-letter sets naturally
  // yield few words, and reaching for more just drags in jargon. A tight,
  // hard-but-fair puzzle with fewer words beats an obscure pangram.
  const wordBand = {
    6: [30, 60, 120],
    7: [20, 38, 65],
    8: [16, 32, 58],
    9: [12, 26, 52],
    10: [8, 22, 55],
    11: [5, 16, 55],
  };
  // Common words with many distinct letters are scarce, so the big sizes look a
  // little deeper into the frequency list. Kept modest to stay out of jargon
  // territory (deeper than this is where methoxychlor/hydrazine live).
  const topNForSize = {6: 0, 7: 0, 8: 0, 9: 0, 10: 1, 11: 2}; // multiplier steps
  final sBit = 1 << ('s'.codeUnitAt(0) - 0x61);

  final dict = Dictionary.fromText(File('assets/words.txt').readAsStringSync());

  // Filtered dictionary for evaluation: drop any word containing 's' (the set
  // never has 's', so such words can never be valid) and anything too short.
  final fMask = <int>[];
  final fLen = <int>[];
  for (var i = 0; i < dict.words.length; i++) {
    final m = dict.masks[i];
    if (m & sBit != 0) continue;
    if (dict.lengths[i] < 3) continue;
    fMask.add(m);
    fLen.add(dict.lengths[i]);
  }

  // Common words in frequency order → rank (0 = most common). Only real dict
  // words, pure a-z. We keep a generous slice; per-size caps applied later.
  final maxNeeded = topN * 6;
  final commonRank = <String, int>{};
  var kept = 0;
  final alpha = RegExp(r'^[a-z]+$');
  final wsSplit = RegExp(r'\s+');
  for (final line in File(freqPath).readAsLinesSync()) {
    // Accept both "word<TAB>count" (Norvig) and "word count" (OpenSubtitles).
    final w = line.trim().split(wsSplit).first;
    if (!alpha.hasMatch(w)) continue;
    if (!dict.wordSet.contains(w)) continue;
    commonRank[w] = kept;
    kept++;
    if (kept >= maxNeeded) break;
  }
  final commonByRank = commonRank.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  final pools = <String, List<List<String>>>{};

  for (final size in [6, 7, 8, 9, 10, 11]) {
    final minLen = minWordLength[size]!;
    final band = wordBand[size]!;
    final floor = band[0], target = band[1], ceil = band[2];
    final sizeTopN = topN * (1 + topNForSize[size]!);

    // Unique common anchor letter-sets, most-common anchor kept per set.
    final maskAnchor = <int, String>{};
    final maskAnchorRank = <int, int>{};
    for (final e in commonByRank) {
      if (e.value >= sizeTopN) break;
      final w = e.key;
      if (w.length < minLen) continue;
      if (_blocked(w)) continue;
      final m = Dictionary.maskOf(w);
      if (m & sBit != 0) continue;
      if (Dictionary.popcount(m) != size) continue;
      if (!maskAnchor.containsKey(m)) {
        maskAnchor[m] = w;
        maskAnchorRank[m] = e.value;
      }
    }
    final candidates = maskAnchor.keys.toList()
      ..sort((a, b) => maskAnchorRank[a]!.compareTo(maskAnchorRank[b]!));

    // Evaluate each set: choose the center giving an in-band word count.
    final entries = <_Entry>[];
    for (final setMask in candidates) {
      final notSet = ~setMask;
      final counts = <int, int>{}; // centerBit -> #valid words containing it
      for (var i = 0; i < fMask.length; i++) {
        if (fLen[i] < minLen) continue;
        final m = fMask[i];
        if (m & notSet != 0) continue; // uses a letter outside the set
        var bits = m; // all bits are within setMask
        while (bits != 0) {
          final low = bits & (-bits);
          counts[low] = (counts[low] ?? 0) + 1;
          bits &= bits - 1;
        }
      }
      int? bestCenter;
      var bestDelta = 1 << 30;
      for (final cb in _bitsOf(setMask)) {
        final cnt = counts[cb] ?? 0;
        if (cnt < floor || cnt > ceil) continue;
        final d = (cnt - target).abs();
        if (d < bestDelta) {
          bestDelta = d;
          bestCenter = cb;
        }
      }
      if (bestCenter == null) continue;
      entries.add(_Entry(setMask, bestCenter, maskAnchor[setMask]!,
          maskAnchorRank[setMask]!, counts[bestCenter]!));
    }

    // De-duplicate word roots (keep the most common anchor per stem) so
    // inflections like bivouacking/bivouacked never both appear.
    entries.sort((a, b) => a.rank.compareTo(b.rank));
    final seenStem = <String>{};
    final deduped = <_Entry>[];
    for (final e in entries) {
      final s = _stem(e.anchor);
      if (!seenStem.add(s)) continue;
      deduped.add(e);
    }

    // Deterministic shuffle, then greedily space out similar letter-sets so
    // adjacent days feel different.
    deduped.shuffle(Random(918273 + size));
    final ordered = _greedySpace(deduped);
    final finalList = ordered.take(366).toList();

    pools[size.toString()] = [
      for (final e in finalList) [_lettersOf(e.setMask), _letterOf(e.center)]
    ];
    if (size >= 9) {
      stderr.writeln('  ANCHORS[$size]: '
          '${(finalList.map((e) => e.anchor).toList()..sort()).join(", ")}');
    }
    stderr.writeln('size $size: ${candidates.length} common sets '
        '-> ${entries.length} in-band -> ${deduped.length} after stem-dedup '
        '-> ${finalList.length} in pool  '
        '(e.g. ${finalList.take(4).map((e) => e.anchor).join(", ")})');
  }

  File(outPath).writeAsStringSync(jsonEncode(pools));
  stderr.writeln('wrote $outPath');
}

class _Entry {
  final int setMask;
  final int center;
  final String anchor;
  final int rank;
  final int count;
  _Entry(this.setMask, this.center, this.anchor, this.rank, this.count);
}

/// Crude but effective stemmer: strip one common inflectional suffix, keeping
/// a stem of >= 4 chars. Enough to collapse plurals/tenses of the same root.
String _stem(String w) {
  const suffixes = [
    'ations', 'ation', 'ings', 'ing', 'edly', 'ers', 'er', 'ed', 'es',
    'est', 'ly', 'y'
  ];
  for (final suf in suffixes) {
    if (w.endsWith(suf) && w.length - suf.length >= 4) {
      return w.substring(0, w.length - suf.length);
    }
  }
  return w;
}

List<_Entry> _greedySpace(List<_Entry> items) {
  if (items.length <= 2) return items;
  final remaining = List<_Entry>.from(items);
  final out = <_Entry>[remaining.removeAt(0)];
  while (remaining.isNotEmpty) {
    final prev = out.last.setMask;
    var bestIdx = 0;
    var bestShared = 1 << 30;
    for (var i = 0; i < remaining.length; i++) {
      final shared = Dictionary.popcount(remaining[i].setMask & prev);
      if (shared < bestShared) {
        bestShared = shared;
        bestIdx = i;
      }
    }
    out.add(remaining.removeAt(bestIdx));
  }
  return out;
}

List<int> _bitsOf(int mask) {
  final bits = <int>[];
  for (var i = 0; i < 26; i++) {
    if (mask & (1 << i) != 0) bits.add(1 << i);
  }
  return bits;
}

String _lettersOf(int mask) {
  final sb = StringBuffer();
  for (var i = 0; i < 26; i++) {
    if (mask & (1 << i) != 0) sb.writeCharCode(0x41 + i);
  }
  return sb.toString();
}

String _letterOf(int bit) {
  for (var i = 0; i < 26; i++) {
    if (bit == 1 << i) return String.fromCharCode(0x41 + i);
  }
  throw ArgumentError('not a single bit');
}
