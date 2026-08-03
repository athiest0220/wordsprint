import 'dart:convert';
import 'dart:io';
import '../lib/services/dictionary.dart';
import '../lib/services/puzzle_engine.dart';

// Usage: dart run tool/preview_week.dart <year> <month> <day> [numDays]
// Prints, for each of the next N days and each size 6-11, the puzzle as
// center-letter + space + the remaining letters (e.g. "T OUGHER"), plus the
// anchor/pangram and valid-word count.
void main(List<String> args) {
  final y = int.parse(args[0]);
  final m = int.parse(args[1]);
  final d = int.parse(args[2]);
  final days = args.length > 3 ? int.parse(args[3]) : 7;

  final dict = Dictionary.fromText(File('assets/words.txt').readAsStringSync());
  final poolsRaw =
      jsonDecode(File('assets/daily_pools.json').readAsStringSync())
          as Map<String, dynamic>;
  final dailyPools = <int, List<List<String>>>{
    for (final e in poolsRaw.entries)
      int.parse(e.key): [
        for (final entry in (e.value as List))
          [for (final s in (entry as List)) s as String]
      ]
  };
  final engine = PuzzleEngine(dict, dailyPools: dailyPools);

  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  for (var i = 0; i < days; i++) {
    final date = DateTime(y, m, d).add(Duration(days: i));
    stdout.writeln(
        '${names[date.weekday - 1]} ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
    for (final size in [6, 7, 8, 9, 10, 11]) {
      final p = engine.generate(date, size);
      final center = p.center.toUpperCase();
      final rest = (p.letters.where((l) => l.toUpperCase() != center).toList()
            ..sort())
          .map((l) => l.toUpperCase())
          .join();
      // longest pangram = the "word of the day"
      final pangrams = p.pangrams.toList()..sort((a, b) => b.length.compareTo(a.length));
      final wotd = pangrams.isNotEmpty ? pangrams.first.toUpperCase() : '(none)';
      stdout.writeln('  $size: $center $rest'.padRight(22) +
          '  ${p.validWords.length} words   word of the day: $wotd');
    }
    stdout.writeln('');
  }
}
