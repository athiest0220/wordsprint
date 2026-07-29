import 'package:flutter/material.dart';

import '../services/app_repository.dart';
import '../services/puzzle_engine.dart';
import '../theme.dart';
import '../util/format.dart';
import 'game_screen.dart';
import 'how_to_screen.dart';
import 'import_screen.dart';
import 'paywall_screen.dart';
import 'results_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppRepository repo;
  const HomeScreen({super.key, required this.repo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];

  DateTime get _today => PuzzleEngine.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    // First launch: show the tutorial once.
    if (!widget.repo.settings.seenTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openTutorial());
    }
  }

  Future<void> _openTutorial() async {
    await widget.repo.settings.setSeenTutorial(true);
    if (!mounted) return;
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HowToScreen()));
  }

  String _key(int size) {
    final d = _today;
    return PuzzleEngine.keyFor(d, size, widget.repo.settings.variantFor(d, size));
  }

  @override
  Widget build(BuildContext context) {
    final d = _today;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset('assets/icon/logo.png',
                  width: 30, height: 30, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            const Text('Word Sprint'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'How to play',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HowToScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Statistics',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => StatsScreen(repo: widget.repo)));
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsScreen(repo: widget.repo)));
              if (mounted) setState(() {}); // refresh after e.g. a fresh day
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '${_months[d.month - 1]} ${d.day}, ${d.year}  ·  pick a size',
                style: const TextStyle(fontSize: 13, color: BeeColors.muted),
              ),
            ),
            if (widget.repo.entitlement.inTrial) _trialBanner(),
            _importCard(),
            for (final size in PuzzleEngine.sizes) _sizeCard(size),
          ],
        ),
      ),
    );
  }

  Widget _trialBanner() {
    final left = widget.repo.entitlement.trialDaysLeft;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BeeColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BeeColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock, color: BeeColors.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Free trial — $left ${left == 1 ? 'day' : 'days'} left',
              style: const TextStyle(fontSize: 13, color: BeeColors.accent),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PaywallScreen(repo: widget.repo)));
              if (mounted) setState(() {});
            },
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  /// Returns true if the player may proceed (in trial or unlocked). Otherwise
  /// shows the paywall and returns whether it was unlocked.
  Future<bool> _ensureEntitled() async {
    if (widget.repo.entitlement.entitled) return true;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PaywallScreen(repo: widget.repo)));
    if (mounted) setState(() {});
    return widget.repo.entitlement.entitled;
  }

  Widget _importCard() {
    return Card(
      color: BeeColors.surfaceHi,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          if (!await _ensureEntitled()) return;
          if (!mounted) return;
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ImportScreen(repo: widget.repo)));
          if (mounted) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BeeColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: BeeColors.accent.withValues(alpha: 0.5)),
                ),
                child: const Icon(Icons.newspaper_outlined,
                    color: BeeColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today’s Puzzle',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Time yourself against today’s puzzle',
                        style:
                            TextStyle(fontSize: 12, color: BeeColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: BeeColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sizeCard(int size) {
    final progress = widget.repo.progress.load(_key(size));
    final minLen = PuzzleEngine.minWordLength[size]!;
    final completed = progress.completeMs != null;
    final gaveUp = !completed && progress.gaveUp;
    final inProgress = !completed &&
        !gaveUp &&
        (progress.foundWords.isNotEmpty || progress.startedRecorded);

    Widget statusChip;
    if (completed) {
      statusChip = _chip('✓ ${formatClock(progress.completeMs)}',
          BeeColors.good, const Color(0xFF14261C));
    } else if (gaveUp) {
      statusChip = _chip('Revealed · ${progress.foundWords.length} found',
          BeeColors.muted, BeeColors.surfaceHi);
    } else if (inProgress) {
      // Show the player's current rank + word progress (rank tells them how
      // close they are to their goal — more motivating than a bare count).
      final puzzle = widget.repo.puzzleFor(_today, size);
      final total = puzzle.validWords.length;
      final rank = puzzle.rankFor(progress.foundWords.length, total);
      final rc = rankColor(rank);
      statusChip = _chip(
          '▶ $rank · ${progress.foundWords.length}/$total',
          rc,
          rc.withValues(alpha: 0.14));
    } else {
      statusChip = _chip('Play', BeeColors.accent, const Color(0xFF12233F));
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(size, completed),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              _sizeBadge(size),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: BeeColors.cellText),
                        children: [
                          TextSpan(text: '$size Letters'),
                          TextSpan(
                            text: '   $minLen+ letter words',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: BeeColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: statusChip,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sizeBadge(int size) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BeeColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BeeColors.accent.withValues(alpha: 0.5)),
      ),
      child: Text('$size',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: BeeColors.accent)),
    );
  }

  Widget _chip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.6)),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  Future<void> _open(int size, bool completed) async {
    if (!await _ensureEntitled()) return;
    if (!mounted) return;
    // Generating here (cached in the repo) keeps the home list snappy.
    final puzzle = widget.repo.puzzleFor(_today, size);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => completed
          ? ResultsScreen(repo: widget.repo, puzzle: puzzle)
          : GameScreen(repo: widget.repo, puzzle: puzzle),
    ));
    if (mounted) setState(() {}); // refresh status on return
  }
}
