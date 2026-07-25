import 'dart:convert';

/// Aggregate speed statistics for one letter-count (or the "all sizes" roll-up).
///
/// Times are accumulated as sums + counts so averages are cheap, plus a running
/// best (fastest) for each of the three milestones.
class SizeStats {
  int gamesStarted;
  int gamesCompleted;

  int pangramCount;
  int pangramSumMs;
  int? pangramBestMs;

  int perfectCount;
  int perfectSumMs;
  int? perfectBestMs;

  int completeCount;
  int completeSumMs;
  int? completeBestMs;

  /// Oops-rate aggregate: total mistakes over total answer-attempts
  /// (found + oops), summed across every finished game.
  int oopsTotal;
  int attemptsTotal;
  int gamesEnded;

  SizeStats({
    this.gamesStarted = 0,
    this.gamesCompleted = 0,
    this.pangramCount = 0,
    this.pangramSumMs = 0,
    this.pangramBestMs,
    this.perfectCount = 0,
    this.perfectSumMs = 0,
    this.perfectBestMs,
    this.completeCount = 0,
    this.completeSumMs = 0,
    this.completeBestMs,
    this.oopsTotal = 0,
    this.attemptsTotal = 0,
    this.gamesEnded = 0,
  });

  int? get avgPangramMs =>
      pangramCount == 0 ? null : pangramSumMs ~/ pangramCount;
  int? get avgPerfectMs =>
      perfectCount == 0 ? null : perfectSumMs ~/ perfectCount;
  int? get avgCompleteMs =>
      completeCount == 0 ? null : completeSumMs ~/ completeCount;

  /// Average oops rate as a fraction 0..1, or null if no games finished.
  double? get oopsRate =>
      attemptsTotal == 0 ? null : oopsTotal / attemptsTotal;

  void addEnd(int oops, int attempts) {
    oopsTotal += oops;
    attemptsTotal += attempts;
    gamesEnded++;
  }

  void addPangram(int ms) {
    pangramCount++;
    pangramSumMs += ms;
    if (pangramBestMs == null || ms < pangramBestMs!) pangramBestMs = ms;
  }

  void addPerfect(int ms) {
    perfectCount++;
    perfectSumMs += ms;
    if (perfectBestMs == null || ms < perfectBestMs!) perfectBestMs = ms;
  }

  void addComplete(int ms) {
    gamesCompleted++;
    completeCount++;
    completeSumMs += ms;
    if (completeBestMs == null || ms < completeBestMs!) completeBestMs = ms;
  }

  Map<String, dynamic> toJson() => {
        'gs': gamesStarted,
        'gc': gamesCompleted,
        'pac': pangramCount,
        'pas': pangramSumMs,
        'pab': pangramBestMs,
        'pec': perfectCount,
        'pes': perfectSumMs,
        'peb': perfectBestMs,
        'coc': completeCount,
        'cos': completeSumMs,
        'cob': completeBestMs,
        'oot': oopsTotal,
        'oat': attemptsTotal,
        'oge': gamesEnded,
      };

  factory SizeStats.fromJson(Map<String, dynamic> j) => SizeStats(
        gamesStarted: j['gs'] as int? ?? 0,
        gamesCompleted: j['gc'] as int? ?? 0,
        pangramCount: j['pac'] as int? ?? 0,
        pangramSumMs: j['pas'] as int? ?? 0,
        pangramBestMs: j['pab'] as int?,
        perfectCount: j['pec'] as int? ?? 0,
        perfectSumMs: j['pes'] as int? ?? 0,
        perfectBestMs: j['peb'] as int?,
        completeCount: j['coc'] as int? ?? 0,
        completeSumMs: j['cos'] as int? ?? 0,
        completeBestMs: j['cob'] as int?,
        oopsTotal: j['oot'] as int? ?? 0,
        attemptsTotal: j['oat'] as int? ?? 0,
        gamesEnded: j['oge'] as int? ?? 0,
      );
}

/// The full stats book: one [SizeStats] per size (7..11).
class StatsBook {
  final Map<int, SizeStats> bySize;

  StatsBook(this.bySize);

  /// The letter-counts tracked, smallest first.
  static const List<int> allSizes = [6, 7, 8, 9, 10, 11];

  factory StatsBook.empty() =>
      StatsBook({for (final s in allSizes) s: SizeStats()});

  /// A synthetic roll-up across every size.
  SizeStats get overall {
    final all = SizeStats();
    for (final s in bySize.values) {
      all.gamesStarted += s.gamesStarted;
      all.gamesCompleted += s.gamesCompleted;
      all.pangramCount += s.pangramCount;
      all.pangramSumMs += s.pangramSumMs;
      all.perfectCount += s.perfectCount;
      all.perfectSumMs += s.perfectSumMs;
      all.completeCount += s.completeCount;
      all.completeSumMs += s.completeSumMs;
      all.oopsTotal += s.oopsTotal;
      all.attemptsTotal += s.attemptsTotal;
      all.gamesEnded += s.gamesEnded;
      all.pangramBestMs = _minOpt(all.pangramBestMs, s.pangramBestMs);
      all.perfectBestMs = _minOpt(all.perfectBestMs, s.perfectBestMs);
      all.completeBestMs = _minOpt(all.completeBestMs, s.completeBestMs);
    }
    return all;
  }

  static int? _minOpt(int? a, int? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a < b ? a : b;
  }

  String encode() =>
      jsonEncode({for (final e in bySize.entries) '${e.key}': e.value.toJson()});

  factory StatsBook.decode(String s) {
    final raw = jsonDecode(s) as Map<String, dynamic>;
    final map = <int, SizeStats>{};
    for (final size in allSizes) {
      final v = raw['$size'];
      map[size] = v == null
          ? SizeStats()
          : SizeStats.fromJson(v as Map<String, dynamic>);
    }
    return StatsBook(map);
  }
}
