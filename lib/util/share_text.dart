import '../models/puzzle.dart';
import 'format.dart';

String _rankEmoji(String rank) {
  switch (rank) {
    case 'Flawless':
      return '💯';
    case 'Professor':
      return '🎓';
    case 'Doctorate':
      return '🎓';
    case "Master's":
      return '📗';
    default:
      return '⭐';
  }
}

/// A shareable, Wordle-style summary of one puzzle result — the rank/title,
/// how many words were found, and the three speed times.
String resultShareText({
  required Puzzle puzzle,
  required int foundCount,
  required int score,
  required int? pangramMs,
  required int? perfectMs,
  required int? completeMs,
  required int oopsCount,
  required int oopsAttempts,
  required int elapsedMs,
}) {
  final total = puzzle.validWords.length;
  final pct = total == 0 ? 0 : (foundCount / total * 100).round();
  final rank = puzzle.rankFor(score);
  final title = puzzle.title ?? '${puzzle.size} Letters';

  // Letters with the center highlighted, e.g.  "F"  B E G I R U
  final others =
      puzzle.letters.where((l) => l != puzzle.center).join(' ');

  final b = StringBuffer();
  b.writeln('📖 Word Sprint — $title');
  b.writeln('Letters:  "${puzzle.center}"  $others');
  b.writeln('${_rankEmoji(rank)} $rank — $foundCount/$total words ($pct%)');
  if (pangramMs != null) {
    b.writeln('🐝 Pangram ${formatClock(pangramMs)}');
  }
  if (puzzle.hasPerfectPangram && perfectMs != null) {
    b.writeln('⭐ Perfect pangram ${formatClock(perfectMs)}');
  }
  if (completeMs != null) {
    b.writeln('🏁 Completed in ${formatClock(completeMs)}');
  } else {
    b.writeln('⏱ Time ${formatClock(elapsedMs)}');
  }
  if (oopsCount > 0 && oopsAttempts > 0) {
    b.writeln('🙈 Oops ${(oopsCount / oopsAttempts * 100).round()}%');
  }
  return b.toString().trimRight();
}
