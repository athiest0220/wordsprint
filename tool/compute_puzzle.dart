import 'dart:io';
import '../lib/services/dictionary.dart';
import '../lib/services/puzzle_engine.dart';

// Usage: dart run tool/compute_puzzle.dart <year> <month> <day> <size>
void main(List<String> args) {
  final y = int.parse(args[0]);
  final m = int.parse(args[1]);
  final d = int.parse(args[2]);
  final size = int.parse(args[3]);
  final text = File('assets/words.txt').readAsStringSync();
  final dict = Dictionary.fromText(text);
  final engine = PuzzleEngine(dict);
  final p = engine.generate(DateTime(y, m, d), size);
  final words = p.validWords.toList()..sort();
  stdout.writeln('CENTER=${p.center}');
  stdout.writeln('LETTERS=${p.letters.join()}');
  stdout.writeln('COUNT=${words.length}');
  stdout.writeln('PANGRAMS=${(p.pangrams.toList()..sort()).join(",")}');
  stdout.writeln('WORDS=${words.join(",")}');
}
