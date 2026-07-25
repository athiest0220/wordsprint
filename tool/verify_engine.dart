// Standalone verification harness (pure Dart, no Flutter needed).
// Run:  dart tool/verify_engine.dart
import 'dart:io';
import '../lib/services/dictionary.dart';
import '../lib/services/puzzle_engine.dart';

void main() {
  final text = File('assets/words.txt').readAsStringSync();
  final sw = Stopwatch()..start();
  final dict = Dictionary.fromText(text);
  print('Loaded ${dict.words.length} words in ${sw.elapsedMilliseconds}ms\n');

  final engine = PuzzleEngine(dict);
  final today = DateTime(2026, 7, 24);

  var allGood = true;
  for (final size in PuzzleEngine.sizes) {
    final t = Stopwatch()..start();
    final p = engine.generate(today, size);
    final ms = t.elapsedMilliseconds;

    // Determinism: regenerate and compare the essentials.
    final p2 = engine.generate(today, size);
    final deterministic = p.letters.join() == p2.letters.join() &&
        p.center == p2.center &&
        p.validWords.length == p2.validWords.length;

    final ok = p.validWords.length >= PuzzleEngine.minWordLength.length &&
        p.pangrams.isNotEmpty &&
        p.center.isNotEmpty &&
        p.letters.contains(p.center) &&
        deterministic;
    allGood = allGood && ok;

    print('SIZE $size  ${ok ? "OK " : "!! "} (${ms}ms)');
    print('  letters=${p.letters.join()}  center=${p.center}  minLen=${p.minWordLength}');
    print('  words=${p.validWords.length}  pangrams=${p.pangrams.length}'
        '  perfectPangrams=${p.perfectPangrams.length}  maxScore=${p.maxScore}');
    print('  pangram examples: ${p.pangrams.take(3).join(", ")}');
    if (p.perfectPangrams.isNotEmpty) {
      print('  perfect pangram(s): ${p.perfectPangrams.take(3).join(", ")}');
    }
    // Sanity: every valid word must contain center + only use set letters.
    final setLetters = p.letters.map((e) => e.toLowerCase()).toSet();
    var violations = 0;
    for (final w in p.validWords) {
      if (!w.contains(p.center.toLowerCase())) violations++;
      if (w.length < p.minWordLength) violations++;
      for (final ch in w.split('')) {
        if (!setLetters.contains(ch)) {
          violations++;
          break;
        }
      }
    }
    if (violations > 0) {
      allGood = false;
      print('  !! $violations rule violations among valid words');
    }
    print('');
  }

  // Cross-date variety check.
  final a = engine.generate(DateTime(2026, 7, 24), 7).letters.join();
  final b = engine.generate(DateTime(2026, 7, 25), 7).letters.join();
  print('Day-to-day variety (size 7): 07-24=$a  07-25=$b  '
      '${a != b ? "DIFFERENT (good)" : "SAME (!)"}');

  print('\n${allGood ? "ALL CHECKS PASSED" : "SOME CHECKS FAILED"}');
  exit(allGood ? 0 : 1);
}
