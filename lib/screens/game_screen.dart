import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../game/game_controller.dart';
import '../models/puzzle.dart';
import '../services/app_repository.dart';
import '../services/puzzle_engine.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/bubble_board.dart';
import '../widgets/timers_bar.dart';
import 'results_screen.dart';
import 'share_card.dart';

class GameScreen extends StatefulWidget {
  final AppRepository repo;
  final Puzzle puzzle;
  const GameScreen({super.key, required this.repo, required this.puzzle});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final GameController _c;
  late List<String> _outer;
  final FocusNode _focus = FocusNode();
  String _current = '';
  String? _flash;
  Color _flashColor = BeeColors.good;
  Timer? _flashTimer;

  // The live clock is hidden by default (anxiety-free play). A small corner
  // clock can be toggled on.
  bool _showClock = false;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _c = GameController(repo: widget.repo, puzzle: widget.puzzle);
    _outer =
        widget.puzzle.letters.where((l) => l != widget.puzzle.center).toList();
    WidgetsBinding.instance.addObserver(this);
    _c.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _c.start();
      _syncClockTimer();
    } else {
      _c.pause();
      _clockTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashTimer?.cancel();
    _clockTimer?.cancel();
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  void _toggleClock() {
    setState(() => _showClock = !_showClock);
    _syncClockTimer();
  }

  void _syncClockTimer() {
    _clockTimer?.cancel();
    if (_showClock && !_c.isEnded) {
      _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _showFlash(String msg, Color color) {
    setState(() {
      _flash = msg;
      _flashColor = color;
    });
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  bool get _haptics => widget.repo.settings.hapticsEnabled;

  void _tapLetter(String letter) {
    if (_c.isEnded) return;
    if (_haptics) HapticFeedback.selectionClick();
    setState(() => _current += letter);
  }

  void _delete() {
    if (_current.isNotEmpty) {
      setState(() => _current = _current.substring(0, _current.length - 1));
    }
  }

  void _shuffle() => setState(() => _outer.shuffle());

  void _submit() {
    if (_c.isEnded || _current.isEmpty) return;
    final prevRank = _c.rank;
    final outcome = _c.submit(_current);
    if (outcome.accepted) {
      final newRank = _c.rank;
      if (newRank != prevRank) {
        // Rank-up celebration takes priority over the points flash.
        if (_haptics) HapticFeedback.heavyImpact();
        _showFlash('⬆  $newRank!', rankColor(newRank));
      } else {
        if (_haptics) {
          (outcome.isPerfect || outcome.isPangram)
              ? HapticFeedback.mediumImpact()
              : HapticFeedback.lightImpact();
        }
        _showFlash(
            outcome.message,
            outcome.isPerfect
                ? BeeColors.perfect
                : outcome.isPangram
                    ? BeeColors.pangram
                    : BeeColors.good);
      }
      setState(() => _current = '');
      if (_c.isComplete) _goToResults();
    } else if (outcome.status != SubmitStatus.empty) {
      if (_haptics) HapticFeedback.heavyImpact();
      _showFlash(outcome.message, BeeColors.bad);
      // Clear the entry after a wrong word if the setting says so (default),
      // otherwise leave it for the player to edit/delete themselves.
      if (widget.repo.settings.clearOnWrong ||
          outcome.status == SubmitStatus.alreadyFound) {
        setState(() => _current = '');
      }
    }
  }

  Future<void> _confirmReroll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BeeColors.surface,
        title: const Text('New letters?'),
        content: const Text(
            'Heads up: getting new letters starts a practice puzzle. Today’s '
            'official game at this size is capped and you won’t be able to '
            'share its result — only today’s original puzzle can be shared.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('New letters')),
        ],
      ),
    );
    if (ok != true) return;
    final day = PuzzleEngine.dateOnly(DateTime.now());
    await widget.repo.settings.bumpVariant(day, widget.puzzle.size);
    final fresh = widget.repo.puzzleFor(day, widget.puzzle.size);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => GameScreen(repo: widget.repo, puzzle: fresh),
    ));
  }

  void _goToResults() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultsScreen(repo: widget.repo, puzzle: widget.puzzle),
    ));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _c.isEnded) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _delete();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    final ch = event.character?.toUpperCase();
    if (ch != null && ch.length == 1 && RegExp(r'[A-Z]').hasMatch(ch)) {
      if (widget.puzzle.letters.contains(ch)) {
        _tapLetter(ch);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.puzzle;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p.title ?? '${p.size} Letters',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('words must be ${p.minWordLength}+ letters',
                style: const TextStyle(fontSize: 11, color: BeeColors.muted)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showClock ? Icons.timer : Icons.timer_off_outlined),
            tooltip: _showClock ? 'Hide clock' : 'Show clock',
            onPressed: _toggleClock,
          ),
          if (!p.isReroll)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Share result',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ShareResultScreen(
                  puzzle: p,
                  foundCount: _c.foundCount,
                  score: _c.score,
                  pangramMs: _c.pangramMs,
                  perfectMs: _c.perfectMs,
                  completeMs: _c.completeMs,
                  oopsCount: _c.oopsCount,
                  oopsAttempts: _c.answerAttempts,
                  elapsedMs: _c.elapsedMs,
                  showOops: widget.repo.settings.showOops,
                ),
              )),
            ),
          if (!p.isImport)
            IconButton(
              icon: const Icon(Icons.casino_outlined),
              tooltip: 'New letters',
              onPressed: _confirmReroll,
            ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Words',
            onPressed: _openWordsSheet,
          ),
        ],
      ),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 6),
                      TimersBar(
                        pangramMs: _c.pangramMs,
                        perfectMs: _c.perfectMs,
                        completeMs: _c.completeMs,
                        hasPerfect: p.hasPerfectPangram,
                        pangramTotal: p.pangrams.length,
                        perfectTotal: p.perfectPangrams.length,
                      ),
                      const SizedBox(height: 10),
                      _rankRow(),
                      const SizedBox(height: 8),
                      _chipsRow(),
                      const SizedBox(height: 4),
                      if (_c.gaveUp) _endedBanner(),
                      _flashArea(),
                      _currentWord(),
                      Expanded(
                        child: Center(
                          child: Opacity(
                            opacity: _c.isEnded ? 0.55 : 1,
                            child: BubbleBoard(
                              center: p.center,
                              outer: _outer,
                              onLetter: _tapLetter,
                            ),
                          ),
                        ),
                      ),
                      _controls(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (_showClock) _cornerClock(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cornerClock() {
    return Positioned(
      bottom: 78,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: BeeColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BeeColors.surfaceHi),
        ),
        child: Text(
          formatClock(_c.isEnded ? _c.completeMs ?? _c.elapsedMs : _c.elapsedMs),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: BeeColors.muted,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  Widget _rankRow() {
    final pct = (_c.foundFraction * 100).round();
    final tierColor = rankColor(_c.rank);
    return Row(
      children: [
        GestureDetector(
          onTap: _showRanks,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_c.rank,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: tierColor)),
              const SizedBox(width: 3),
              Icon(Icons.info_outline, size: 14, color: tierColor),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _c.rankFraction,
              minHeight: 8,
              backgroundColor: BeeColors.surfaceHi,
              valueColor: AlwaysStoppedAnimation(tierColor),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // The word-count button: found / total · percent.
        Material(
          color: BeeColors.surfaceHi,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _openWordsSheet,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Text('${_c.foundCount}/${_c.totalCount}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  Text('$pct%',
                      style:
                          const TextStyle(color: BeeColors.muted, fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 16, color: BeeColors.muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Shows the full rank ladder with each tier's percentage range, so players
  /// aiming for a target rank can see what's next.
  void _showRanks() {
    const tiers = Puzzle.rankTiers;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: BeeColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Ranks',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: const Icon(Icons.close, color: BeeColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Your rank climbs as you earn more of the puzzle’s points. '
                'Reach the next tier by passing its lower percentage.',
                style: TextStyle(color: BeeColors.muted, height: 1.3),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < tiers.length; i++)
                        _rankLadderRow(
                          label: tiers[i].key,
                          lo: tiers[i].value,
                          hi: i + 1 < tiers.length ? tiers[i + 1].value : null,
                          current: tiers[i].key == _c.rank,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rankLadderRow({
    required String label,
    required double lo,
    required double? hi,
    required bool current,
  }) {
    final color = rankColor(label);
    final range =
        hi == null ? '100%' : '${(lo * 100).round()}–${(hi * 100).round()}%';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: current ? color.withValues(alpha: 0.18) : BeeColors.surfaceHi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: current ? color : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ),
          Text(
            range,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: current ? color : BeeColors.muted,
            ),
          ),
          if (current) ...[
            const SizedBox(width: 8),
            Text('You',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _chipsRow() {
    final oopsPct = (_c.oopsRate * 100).round();
    return Row(
      children: [
        _infoChip('Min ${widget.puzzle.minWordLength}', BeeColors.muted),
        if (widget.repo.settings.showOops) ...[
          const SizedBox(width: 8),
          _infoChip(
            _c.oopsCount == 0 ? 'Oops 0' : 'Oops ${_c.oopsCount} · $oopsPct%',
            _c.oopsCount == 0 ? BeeColors.muted : BeeColors.bad,
          ),
        ],
      ],
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BeeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BeeColors.surfaceHi),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _endedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: BeeColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BeeColors.bad.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, size: 18, color: BeeColors.bad),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Gave up — all words revealed. Score kept.',
                style: TextStyle(fontSize: 13)),
          ),
          TextButton(
            onPressed: _openWordsSheet,
            child: const Text('See words'),
          ),
        ],
      ),
    );
  }

  Widget _flashArea() {
    return SizedBox(
      height: 26,
      child: AnimatedOpacity(
        opacity: _flash == null ? 0 : 1,
        duration: const Duration(milliseconds: 150),
        child: Text(
          _flash ?? '',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _flashColor,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _currentWord() {
    return SizedBox(
      height: 40,
      child: Center(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 2),
            children: [
              for (final ch in _current.split(''))
                TextSpan(
                  text: ch,
                  style: TextStyle(
                    color: ch == widget.puzzle.center
                        ? BeeColors.accent
                        : BeeColors.cellText,
                  ),
                ),
              if (_current.isEmpty)
                TextSpan(
                    text: _c.isEnded ? 'Game over for today' : 'Type or tap letters',
                    style: const TextStyle(
                        fontSize: 16,
                        color: BeeColors.muted,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    final disabled = _c.isEnded;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ctrlButton('Delete', disabled ? null : _delete, outlined: true),
        _ctrlButton('Shuffle', disabled ? null : _shuffle,
            outlined: true, icon: Icons.shuffle),
        _ctrlButton('Enter', disabled ? null : _submit, outlined: false),
      ],
    );
  }

  Widget _ctrlButton(String label, VoidCallback? onTap,
      {bool outlined = true, IconData? icon}) {
    final child = icon != null
        ? Icon(icon, size: 20)
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w700));
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: BeeColors.cellText,
            side: const BorderSide(color: BeeColors.surfaceHi),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: const StadiumBorder(),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F1420),
            backgroundColor: BeeColors.accent,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: const StadiumBorder(),
          );
    return OutlinedButton(onPressed: onTap, style: style, child: child);
  }

  // ---- words sheet (with give-up reveal) ----

  void _openWordsSheet() {
    bool alpha = false; // false = by length (default), true = A–Z
    showModalBottomSheet(
      context: context,
      backgroundColor: BeeColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final reveal = _c.isEnded;
            final base = reveal ? _c.allWordsSorted : _c.foundSorted;
            final words = alpha ? ([...base]..sort()) : base;
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.55,
              maxChildSize: 0.9,
              builder: (context, scroll) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            reveal
                                ? 'All words — found ${_c.foundCount}/${_c.totalCount}'
                                : 'Found ${_c.foundCount} of ${_c.totalCount}  •  '
                                    '${_c.pangramsFound}/${widget.puzzle.pangrams.length} pangrams',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: BeeColors.accent),
                          ),
                        ),
                        if (!reveal)
                          OutlinedButton.icon(
                            onPressed: () =>
                                _confirmGiveUp(sheetContext, setSheetState),
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BeeColors.bad,
                              side: BorderSide(
                                  color: BeeColors.bad.withValues(alpha: 0.6)),
                              shape: const StadiumBorder(),
                            ),
                            label: const Text('Give Up for Today'),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Row(
                      children: [
                        const Text('Sort',
                            style: TextStyle(
                                color: BeeColors.muted, fontSize: 13)),
                        const SizedBox(width: 10),
                        _sortChip('Length', !alpha,
                            () => setSheetState(() => alpha = false)),
                        const SizedBox(width: 6),
                        _sortChip('A–Z', alpha,
                            () => setSheetState(() => alpha = true)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scroll,
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final w in words)
                            _wordChip(w, found: _c.progress.foundWords.contains(w)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sortChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? BeeColors.accent : BeeColors.surfaceHi,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF0F1420) : BeeColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _wordChip(String w, {required bool found}) {
    final isPerfect = widget.puzzle.isPerfectPangram(w);
    final isPangram = widget.puzzle.isPangram(w);
    final Color bg;
    final Color fg;
    Color border = Colors.transparent;
    // Pangrams/perfect are always coloured (blue / yellow) so they stand out in
    // the list even before they're found; a filled background marks the ones
    // you actually got.
    if (isPerfect) {
      fg = BeeColors.perfect; // yellow
      bg = BeeColors.perfect.withValues(alpha: found ? 0.22 : 0.08);
      border = BeeColors.perfect.withValues(alpha: found ? 1 : 0.6);
    } else if (isPangram) {
      fg = BeeColors.accent; // blue
      bg = BeeColors.accent.withValues(alpha: found ? 0.22 : 0.08);
      border = BeeColors.accent.withValues(alpha: found ? 1 : 0.6);
    } else if (found) {
      bg = BeeColors.surfaceHi;
      fg = BeeColors.cellText;
    } else {
      bg = BeeColors.bg; // missed ordinary word (reveal only)
      fg = BeeColors.muted;
    }
    return GestureDetector(
      onTap: () => _lookUp(w),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(w,
                style: TextStyle(
                    color: fg,
                    fontWeight: found
                        ? FontWeight.w700
                        : (isPangram || isPerfect
                            ? FontWeight.w600
                            : FontWeight.w400))),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 12, color: fg.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  /// Open a word's definition on dictionary.com in the browser.
  Future<void> _lookUp(String word) async {
    final uri = Uri.parse('https://www.dictionary.com/browse/$word');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* no browser available */}
  }

  Future<void> _confirmGiveUp(
      BuildContext sheetContext, void Function(void Function()) setSheetState) async {
    final ok = await showDialog<bool>(
      context: sheetContext,
      builder: (_) => AlertDialog(
        backgroundColor: BeeColors.surface,
        title: const Text('Give up for today?'),
        content: const Text(
            'This reveals every word and ends the game. Your current score '
            'and any times you earned are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: const Text('Keep playing')),
          TextButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: const Text('Give up',
                  style: TextStyle(color: BeeColors.bad))),
        ],
      ),
    );
    if (ok == true) {
      _c.giveUp();
      _clockTimer?.cancel();
      setSheetState(() {}); // rebuild sheet into reveal mode
      setState(() {}); // disable the board behind
    }
  }
}
