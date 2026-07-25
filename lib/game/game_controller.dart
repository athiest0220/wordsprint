import 'package:flutter/foundation.dart';

import '../models/game_progress.dart';
import '../models/puzzle.dart';
import '../services/app_repository.dart';
import '../util/share_text.dart';

enum SubmitStatus {
  ok,
  tooShort,
  missingCenter,
  badLetter,
  notAWord,
  alreadyFound,
  empty,
}

/// The result of submitting a guess — carries a user-facing message and, on
/// success, what was earned.
class SubmitOutcome {
  final SubmitStatus status;
  final String message;
  final int points;
  final bool isPangram;
  final bool isPerfect;
  const SubmitOutcome(this.status, this.message,
      {this.points = 0, this.isPangram = false, this.isPerfect = false});

  bool get accepted => status == SubmitStatus.ok;

  /// A rejected answer attempt that counts as an "oops" (mistake). Duplicates
  /// and empty entries are excluded.
  bool get isOops =>
      status == SubmitStatus.tooShort ||
      status == SubmitStatus.missingCenter ||
      status == SubmitStatus.badLetter ||
      status == SubmitStatus.notAWord;
}

/// Drives one live game: elapsed time, guess handling, oops tracking, the three
/// milestone times, and the "give up" reveal.
class GameController extends ChangeNotifier {
  final AppRepository repo;
  final Puzzle puzzle;
  final GameProgress progress;

  final Stopwatch _session = Stopwatch();

  GameController({required this.repo, required this.puzzle})
      : progress = repo.progress.load(puzzle.key);

  // ---- clock ----

  /// Active play time in ms: previously-banked time plus the current session.
  int get elapsedMs => progress.elapsedMs + _session.elapsedMilliseconds;

  bool get isComplete => progress.completeMs != null;
  bool get gaveUp => progress.gaveUp;

  /// The game is over for the day — completed or given up.
  bool get isEnded => isComplete || gaveUp;

  /// Begin (or resume) play. Safe to call whenever the game screen appears.
  void start() {
    if (isEnded) return;
    if (!progress.startedRecorded) {
      progress.startedRecorded = true;
      repo.stats.recordStarted(puzzle.size);
      _persist();
    }
    if (!_session.isRunning) _session.start();
  }

  /// Pause and bank elapsed time. Call when the screen is backgrounded/left.
  void pause() {
    if (_session.isRunning) {
      progress.elapsedMs += _session.elapsedMilliseconds;
      _session
        ..stop()
        ..reset();
      _persist();
    }
  }

  // ---- derived state ----

  List<String> get foundSorted =>
      progress.foundWords.toList()..sort((a, b) {
        if (a.length != b.length) return b.length.compareTo(a.length);
        return a.compareTo(b);
      });

  /// Every valid word, sorted — used for the give-up / completion reveal.
  List<String> get allWordsSorted =>
      puzzle.validWords.toList()..sort((a, b) {
        if (a.length != b.length) return b.length.compareTo(a.length);
        return a.compareTo(b);
      });

  int get foundCount => progress.foundWords.length;
  int get totalCount => puzzle.validWords.length;
  double get foundFraction =>
      totalCount == 0 ? 0 : foundCount / totalCount;

  int get pangramsFound => progress.foundWords.where(puzzle.isPangram).length;

  int get oopsCount => progress.oopsCount;

  /// Answer attempts = accepted words + oops. Oops rate is oops / attempts.
  int get answerAttempts => foundCount + oopsCount;
  double get oopsRate =>
      answerAttempts == 0 ? 0 : oopsCount / answerAttempts;

  int get score {
    var s = 0;
    for (final w in progress.foundWords) {
      s += puzzle.scoreFor(w);
    }
    return s;
  }

  String get rank => puzzle.rankFor(score);
  double get rankFraction =>
      puzzle.maxScore == 0 ? 0 : (score / puzzle.maxScore).clamp(0, 1);

  int? get pangramMs => progress.pangramMs;
  int? get perfectMs => progress.perfectMs;
  int? get completeMs => progress.completeMs;

  // ---- guessing ----

  SubmitOutcome submit(String rawWord) {
    if (isEnded) return const SubmitOutcome(SubmitStatus.empty, '');
    final word = rawWord.trim().toLowerCase();
    if (word.isEmpty) {
      return const SubmitOutcome(SubmitStatus.empty, '');
    }

    SubmitOutcome outcome;
    if (word.length < puzzle.minWordLength) {
      outcome = SubmitOutcome(SubmitStatus.tooShort,
          'Too short — need ${puzzle.minWordLength}+ letters');
    } else if (!word.contains(puzzle.center.toLowerCase())) {
      outcome = SubmitOutcome(
          SubmitStatus.missingCenter, 'Missing center letter ${puzzle.center}');
    } else if (_hasBadLetter(word)) {
      outcome = const SubmitOutcome(SubmitStatus.badLetter, 'Bad letter');
    } else if (progress.foundWords.contains(word)) {
      outcome = const SubmitOutcome(SubmitStatus.alreadyFound, 'Already found');
    } else if (!puzzle.validWords.contains(word)) {
      outcome = const SubmitOutcome(SubmitStatus.notAWord, 'Not in word list');
    } else {
      outcome = _accept(word);
    }

    if (outcome.isOops) {
      progress.oopsCount++;
      _persist();
      notifyListeners();
    }
    return outcome;
  }

  bool _hasBadLetter(String word) {
    final allowed = puzzle.letters.map((e) => e.toLowerCase()).toSet();
    for (final ch in word.split('')) {
      if (!allowed.contains(ch)) return true;
    }
    return false;
  }

  SubmitOutcome _accept(String word) {
    progress.foundWords.add(word);
    final pts = puzzle.scoreFor(word);
    final isPangram = puzzle.isPangram(word);
    final isPerfect = puzzle.isPerfectPangram(word);
    final now = elapsedMs;

    _checkMilestones(isPangram, isPerfect, now);
    _persist();
    notifyListeners();

    final msg = isPerfect
        ? 'PERFECT PANGRAM!  +$pts'
        : isPangram
            ? 'PANGRAM!  +$pts'
            : '+$pts';
    return SubmitOutcome(SubmitStatus.ok, msg,
        points: pts, isPangram: isPangram, isPerfect: isPerfect);
  }

  void _checkMilestones(bool isPangram, bool isPerfect, int now) {
    if (isPangram && progress.pangramMs == null) {
      progress.pangramMs = now;
      if (!progress.pangramRecorded) {
        progress.pangramRecorded = true;
        repo.stats.recordPangram(puzzle.size, now);
      }
    }
    if (isPerfect && puzzle.hasPerfectPangram && progress.perfectMs == null) {
      progress.perfectMs = now;
      if (!progress.perfectRecorded) {
        progress.perfectRecorded = true;
        repo.stats.recordPerfect(puzzle.size, now);
      }
    }
    if (progress.completeMs == null &&
        progress.foundWords.length >= puzzle.validWords.length) {
      progress.completeMs = now;
      if (!progress.completeRecorded) {
        progress.completeRecorded = true;
        repo.stats.recordComplete(puzzle.size, now);
      }
      pause(); // freeze the clock on completion
      _recordEnd();
    }
  }

  /// Reveal all answers and end the game, keeping the current score and any
  /// milestone times already earned. No "complete" time is recorded.
  void giveUp() {
    if (isEnded) return;
    progress.gaveUp = true;
    pause();
    _recordEnd();
    _persist();
    notifyListeners();
  }

  void _recordEnd() {
    if (progress.endRecorded) return;
    progress.endRecorded = true;
    repo.stats.recordEnd(puzzle.size, progress.oopsCount, answerAttempts);
  }

  /// A shareable summary of the current result (rank, word count, times).
  String shareText() => resultShareText(
        puzzle: puzzle,
        foundCount: foundCount,
        score: score,
        pangramMs: pangramMs,
        perfectMs: perfectMs,
        completeMs: completeMs,
        oopsCount: oopsCount,
        oopsAttempts: answerAttempts,
        elapsedMs: elapsedMs,
      );

  void _persist() => repo.progress.save(progress);

  @override
  void dispose() {
    pause();
    super.dispose();
  }
}
