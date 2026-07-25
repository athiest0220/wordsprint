import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_repository.dart';
import '../services/nyt_fetcher.dart';
import '../theme.dart';
import 'game_screen.dart';

/// Lets the player type in an external 7-letter Spelling Bee (e.g. today's NYT,
/// read off a "spelling bee answers" site) and play it with the Word Sprint
/// timer. Valid words come from the bundled dictionary.
class ImportScreen extends StatefulWidget {
  final AppRepository repo;
  const ImportScreen({super.key, required this.repo});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _centerCtrl = TextEditingController();
  final _othersCtrl = TextEditingController();
  String? _error;
  bool _loading = false;

  static final _lettersOnly = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
    TextInputFormatter.withFunction((old, nu) =>
        nu.copyWith(text: nu.text.toUpperCase())),
  ];

  @override
  void dispose() {
    _centerCtrl.dispose();
    _othersCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoFetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bee = await NytFetcher.fetchToday();
      final key = 'NYT-${(bee.letters.toList()..sort()).join()}';
      final puzzle = widget.repo.engine.generateCustom(
        letters: bee.letters,
        center: bee.center,
        customKey: key,
        title: 'Today’s Spelling Bee',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => GameScreen(repo: widget.repo, puzzle: puzzle),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Couldn’t fetch automatically '
            '(${e.toString().replaceAll('Exception: ', '')}). '
            'Enter the letters manually below.';
      });
    }
  }

  void _start() {
    final center = _centerCtrl.text.trim().toUpperCase();
    final others = _othersCtrl.text.trim().toUpperCase().split('')
      ..removeWhere((c) => c.trim().isEmpty);

    if (center.length != 1) {
      setState(() => _error = 'Enter exactly one center letter.');
      return;
    }
    if (others.length != 6) {
      setState(() => _error =
          'Enter exactly 6 other letters (you have ${others.length}).');
      return;
    }
    final all = <String>{center, ...others};
    if (all.length != 7) {
      setState(() => _error = 'All 7 letters must be different.');
      return;
    }

    final letters = [center, ...others];
    final key = 'NYT-${(letters.toList()..sort()).join()}';
    final puzzle = widget.repo.engine.generateCustom(
      letters: letters,
      center: center,
      customKey: key,
      title: 'Imported Bee',
    );

    if (puzzle.validWords.isEmpty) {
      setState(() => _error =
          'No valid words found for those letters — double-check them.');
      return;
    }

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => GameScreen(repo: widget.repo, puzzle: puzzle),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import a Spelling Bee')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Play an outside puzzle with the Word Sprint timer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Grab today’s Spelling Bee and play it against the clock. '
              'Fetch it automatically, or type the letters in yourself.',
              style: TextStyle(color: BeeColors.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: BeeColors.accent,
                foregroundColor: const Color(0xFF0F1420),
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _loading ? null : _autoFetch,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Color(0xFF0F1420)),
                    )
                  : const Icon(Icons.cloud_download_outlined),
              label: Text(_loading
                  ? 'Fetching today’s puzzle…'
                  : 'Get today’s puzzle'),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Expanded(child: Divider(color: BeeColors.surfaceHi)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('or enter manually',
                      style: TextStyle(color: BeeColors.muted, fontSize: 12)),
                ),
                Expanded(child: Divider(color: BeeColors.surfaceHi)),
              ],
            ),
            const SizedBox(height: 16),
            _label('Center letter (required in every word)'),
            const SizedBox(height: 6),
            TextField(
              controller: _centerCtrl,
              maxLength: 1,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: _lettersOnly,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4),
              decoration: _boxDeco('e.g.  T'),
            ),
            const SizedBox(height: 16),
            _label('The other 6 letters'),
            const SizedBox(height: 6),
            TextField(
              controller: _othersCtrl,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: _lettersOnly,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 8),
              decoration: _boxDeco('e.g.  ACLONI'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: BeeColors.bad, height: 1.3)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: BeeColors.accent,
                foregroundColor: const Color(0xFF0F1420),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _start,
              child: const Text('Start the timer',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(fontWeight: FontWeight.w600, color: BeeColors.muted));

  InputDecoration _boxDeco(String hint) => InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(
            color: BeeColors.muted, letterSpacing: 2, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: BeeColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BeeColors.surfaceHi),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BeeColors.accent, width: 2),
        ),
      );
}
