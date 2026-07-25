import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:speedbee/services/dictionary.dart';
import 'package:speedbee/services/puzzle_engine.dart';

void main() {
  late Dictionary dict;
  late PuzzleEngine engine;

  setUpAll(() {
    dict = Dictionary.fromText(File('assets/words.txt').readAsStringSync());
    engine = PuzzleEngine(dict);
  });

  test('every size generates a valid, rule-abiding puzzle', () {
    final date = DateTime(2026, 7, 24);
    for (final size in PuzzleEngine.sizes) {
      final p = engine.generate(date, size);
      expect(p.letters.length, size);
      expect(p.letters, contains(p.center));
      expect(p.pangrams, isNotEmpty, reason: 'size $size needs a pangram');
      expect(p.validWords.length, greaterThan(5));
      expect(p.minWordLength, PuzzleEngine.minWordLength[size]);

      final allowed = p.letters.map((e) => e.toLowerCase()).toSet();
      for (final w in p.validWords) {
        expect(w.length, greaterThanOrEqualTo(p.minWordLength));
        expect(w.contains(p.center.toLowerCase()), isTrue);
        for (final ch in w.split('')) {
          expect(allowed.contains(ch), isTrue, reason: '$w uses $ch');
        }
      }
      // Pangrams use every letter; perfect pangrams are exactly `size` long.
      for (final pg in p.pangrams) {
        expect(Dictionary.maskOf(pg), Dictionary.maskOf(p.letters.join().toLowerCase()));
      }
      for (final pp in p.perfectPangrams) {
        expect(pp.length, size);
      }
    }
  });

  test('generation is deterministic for a given date and size', () {
    final a = engine.generate(DateTime(2026, 7, 24), 8);
    final b = engine.generate(DateTime(2026, 7, 24), 8);
    expect(a.letters, b.letters);
    expect(a.center, b.center);
    expect(a.validWords.length, b.validWords.length);
  });

  test('puzzles differ from one day to the next', () {
    final a = engine.generate(DateTime(2026, 7, 24), 7);
    final b = engine.generate(DateTime(2026, 7, 25), 7);
    expect(a.letters.join() == b.letters.join() && a.center == b.center,
        isFalse);
  });

  test('no letter set contains S', () {
    for (final size in PuzzleEngine.sizes) {
      final p = engine.generate(DateTime(2026, 7, 24), size);
      expect(p.letters.contains('S'), isFalse);
    }
  });

  test('scoring: min-length word = 1 pt, pangram gets +size bonus', () {
    final p = engine.generate(DateTime(2026, 7, 24), 7);
    final minWord =
        p.validWords.firstWhere((w) => w.length == p.minWordLength, orElse: () => '');
    if (minWord.isNotEmpty && !p.isPangram(minWord)) {
      expect(p.scoreFor(minWord), 1);
    }
    final pangram = p.pangrams.first;
    expect(p.scoreFor(pangram), pangram.length + p.size);
  });
}
