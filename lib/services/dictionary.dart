import 'dart:typed_data';

/// The word list plus precomputed letter bitmasks used by [PuzzleEngine].
///
/// Each word gets a 26-bit mask (bit i set == letter 'a'+i present). Subset
/// tests, "contains center", and pangram detection then reduce to fast integer
/// bit operations instead of per-character string scans.
class Dictionary {
  final List<String> words;
  final Set<String> wordSet;
  final Uint32List masks;
  final Uint8List lengths;

  Dictionary._(this.words, this.wordSet, this.masks, this.lengths);

  /// Build from the raw asset text: one lowercase a-z word per line.
  factory Dictionary.fromText(String text) {
    final words = <String>[];
    for (final raw in text.split('\n')) {
      final w = raw.trim();
      if (w.isEmpty) continue;
      words.add(w);
    }
    final masks = Uint32List(words.length);
    final lengths = Uint8List(words.length);
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      masks[i] = maskOf(w);
      lengths[i] = w.length > 255 ? 255 : w.length;
    }
    return Dictionary._(words, words.toSet(), masks, lengths);
  }

  /// 26-bit letter-presence mask for a lowercase word.
  static int maskOf(String word) {
    var m = 0;
    for (var i = 0; i < word.length; i++) {
      final c = word.codeUnitAt(i);
      if (c >= 0x61 && c <= 0x7a) m |= 1 << (c - 0x61);
    }
    return m;
  }

  /// Number of distinct letters in a mask (popcount).
  static int popcount(int m) {
    var count = 0;
    while (m != 0) {
      m &= m - 1;
      count++;
    }
    return count;
  }

  bool contains(String word) => wordSet.contains(word.toLowerCase());
}
