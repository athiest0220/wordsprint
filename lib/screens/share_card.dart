import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/puzzle.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/share_text.dart';

/// Shows a rendered "result card" (with the real logo) and shares it as an
/// image. Falls back to plain text if image capture fails.
class ShareResultScreen extends StatefulWidget {
  final Puzzle puzzle;
  final int foundCount;
  final int score;
  final int? pangramMs;
  final int? perfectMs;
  final int? completeMs;
  final int oopsCount;
  final int oopsAttempts;
  final int elapsedMs;
  final bool showOops;

  const ShareResultScreen({
    super.key,
    required this.puzzle,
    required this.foundCount,
    required this.score,
    required this.pangramMs,
    required this.perfectMs,
    required this.completeMs,
    required this.oopsCount,
    required this.oopsAttempts,
    required this.elapsedMs,
    required this.showOops,
  });

  @override
  State<ShareResultScreen> createState() => _ShareResultScreenState();
}

class _ShareResultScreenState extends State<ShareResultScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;

  String get _caption => resultShareText(
        puzzle: widget.puzzle,
        foundCount: widget.foundCount,
        score: widget.score,
        pangramMs: widget.pangramMs,
        perfectMs: widget.perfectMs,
        completeMs: widget.completeMs,
        oopsCount: widget.oopsCount,
        oopsAttempts: widget.oopsAttempts,
        elapsedMs: widget.elapsedMs,
        showOops: widget.showOops,
      );

  Future<void> _shareImage() async {
    setState(() => _busy = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/word_sprint_result.png')
          .writeAsBytes(bytes);
      // Image only — the card already shows everything, so no text caption.
      await Share.shareXFiles([XFile(file.path)],
          sharePositionOrigin: _shareOrigin());
    } catch (_) {
      await Share.share(_caption,
          sharePositionOrigin: _shareOrigin()); // fallback if the image fails
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// iOS needs a source rectangle to anchor the share sheet (required on iPad,
  /// and its absence can stop the sheet presenting on iPhone too).
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share result')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: _ResultCard(
                      puzzle: widget.puzzle,
                      foundCount: widget.foundCount,
                      score: widget.score,
                      pangramMs: widget.pangramMs,
                      perfectMs: widget.perfectMs,
                      completeMs: widget.completeMs,
                      oopsCount: widget.oopsCount,
                      oopsAttempts: widget.oopsAttempts,
                      elapsedMs: widget.elapsedMs,
                      showOops: widget.showOops,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BeeColors.accent,
                  foregroundColor: const Color(0xFF0F1420),
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _busy ? null : _shareImage,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Color(0xFF0F1420)))
                    : const Icon(Icons.ios_share),
                label: Text(_busy ? 'Preparing…' : 'Share image'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The visual card that gets captured to an image.
class _ResultCard extends StatelessWidget {
  final Puzzle puzzle;
  final int foundCount;
  final int score;
  final int? pangramMs;
  final int? perfectMs;
  final int? completeMs;
  final int oopsCount;
  final int oopsAttempts;
  final int elapsedMs;
  final bool showOops;

  const _ResultCard({
    required this.puzzle,
    required this.foundCount,
    required this.score,
    required this.pangramMs,
    required this.perfectMs,
    required this.completeMs,
    required this.oopsCount,
    required this.oopsAttempts,
    required this.elapsedMs,
    required this.showOops,
  });

  Color _rankColor(String r) {
    if (r == 'Flawless') return BeeColors.perfect;
    if (r == 'Professor' || r == 'Doctorate') return BeeColors.accent;
    return BeeColors.cellText;
  }

  @override
  Widget build(BuildContext context) {
    final total = puzzle.validWords.length;
    final pct = total == 0 ? 0 : (foundCount / total * 100).round();
    final rank = puzzle.rankFor(score);
    final others = puzzle.letters.where((l) => l != puzzle.center).toList();

    return Container(
      width: 360,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C2942), Color(0xFF0E1622)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: BeeColors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset('assets/icon/logo.png', width: 46, height: 46),
              const SizedBox(width: 10),
              const Text('Word Sprint',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          Text(puzzle.title ?? '${puzzle.size} Letters',
              style: const TextStyle(fontSize: 15, color: BeeColors.muted)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: [
              _letter(puzzle.center, true),
              for (final l in others) _letter(l, false),
            ],
          ),
          const SizedBox(height: 18),
          Text(rank,
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _rankColor(rank))),
          Text('$foundCount / $total words · $pct%',
              style: const TextStyle(color: BeeColors.muted, fontSize: 14)),
          const SizedBox(height: 18),
          Row(
            children: [
              _timeTile('🐝', 'Pangram', pangramMs, BeeColors.pangram),
              if (puzzle.hasPerfectPangram)
                _timeTile('⭐', 'Perfect', perfectMs, BeeColors.perfect),
              _timeTile(
                  '🏁',
                  completeMs != null ? 'Complete' : 'Time',
                  completeMs ?? elapsedMs,
                  BeeColors.good),
            ],
          ),
          if (showOops && oopsCount > 0 && oopsAttempts > 0) ...[
            const SizedBox(height: 10),
            Text('🙈 Oops ${(oopsCount / oopsAttempts * 100).round()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(color: BeeColors.muted, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          const Text('Race the dictionary ⏱',
              textAlign: TextAlign.center,
              style: TextStyle(color: BeeColors.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _letter(String l, bool center) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: center ? BeeColors.accent : BeeColors.surfaceHi,
      ),
      child: Text(l,
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: center ? const Color(0xFF0F1420) : BeeColors.cellText)),
    );
  }

  Widget _timeTile(String icon, String label, int? ms, Color color) {
    final pending = ms == null;
    return Expanded(
      child: Column(
        children: [
          Text('$icon $label',
              style: const TextStyle(fontSize: 11, color: BeeColors.muted)),
          const SizedBox(height: 2),
          Text(formatClock(ms),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: pending ? BeeColors.muted : color)),
        ],
      ),
    );
  }
}
