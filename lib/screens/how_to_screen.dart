import 'package:flutter/material.dart';
import '../theme.dart';
import 'faq_screen.dart';

class _Page {
  final String emoji;
  final String? asset; // optional image icon instead of an emoji
  final String title;
  final List<InlineSpan> body;
  const _Page(this.emoji, this.title, this.body, {this.asset});
}

/// The in-app tutorial. Shown once on first launch and re-openable anytime
/// from the "?" button on the home screen.
class HowToScreen extends StatefulWidget {
  const HowToScreen({super.key});

  @override
  State<HowToScreen> createState() => _HowToScreenState();
}

class _HowToScreenState extends State<HowToScreen> {
  final _controller = PageController();
  int _index = 0;

  TextSpan _t(String s) => TextSpan(text: s);
  TextSpan _b(String s, Color c) => TextSpan(
      text: s,
      style: TextStyle(color: c, fontWeight: FontWeight.w800));
  // Inline running-bee image (used in place of the 🐝 emoji).
  WidgetSpan _bee() => const WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Image(
              image: AssetImage('assets/icon/run_bee.png'),
              width: 24,
              height: 24),
        ),
      );

  late final List<_Page> _pages = [
    _Page('', 'Welcome to Word Sprint', [
      _t('A word game that '),
      _b('times you', BeeColors.accent),
      _t('. Find the hidden words in the letters — then race the clock to do '
          'it faster than your friends and family.'),
    ], asset: 'assets/icon/logo.png'),
    _Page('', 'Build words from the letters', [
      _t('Tap the bubbles (or use your keyboard) and press '),
      _b('Enter', BeeColors.accent),
      _t('. Every word must contain the '),
      _b('blue center letter', BeeColors.accent),
      _t('. Bigger boards need longer words — each level shows the '
          'minimum length. Use '),
      _b('Delete', BeeColors.cellText),
      _t(' and '),
      _b('Shuffle', BeeColors.cellText),
      _t(' to help.'),
    ], asset: 'assets/icon/run_bubble.png'),
    _Page('', 'Pangrams & perfect pangrams', [
      _t('A '),
      _b('pangram', BeeColors.accent),
      _t(' uses '),
      _b('all', BeeColors.accent),
      _t(' the letters — it shows up '),
      _b('blue', BeeColors.accent),
      _t(' in your word list. A '),
      _b('perfect pangram', BeeColors.perfect),
      _t(' uses each letter '),
      _b('exactly once', BeeColors.perfect),
      _t(' and shows up '),
      _b('gold', BeeColors.perfect),
      _t('. Depending on the letters, there can be several perfect '
          'pangrams — or none.'),
    ], asset: 'assets/icon/run_bee.png'),
    _Page('', 'Three clocks — this is the point', [
      _t('You’re timed on three things: your first '),
      _b('pangram', BeeColors.pangram),
      _bee(),
      _t(', your first '),
      _b('perfect pangram ⭐', BeeColors.perfect),
      _t(', and finding '),
      _b('every word 🏁', BeeColors.good),
      _t('. The clock is '),
      _b('hidden by default', BeeColors.cellText),
      _t(' — tap the timer icon, if you want to watch it and raise your '
          'anxiety level.'),
    ], asset: 'assets/icon/run_watch.png'),
    _Page('', 'Climb the ranks', [
      _t('Score enough and you rise: '),
      _b('Student → Bachelor’s → Master’s → Doctorate → Professor (90%) → '
          'Flawless', BeeColors.accent),
      _t(' (every single word). What is your best time?'),
    ], asset: 'assets/icon/grad_cap.png'),
    _Page('', 'Extras', [
      _t('• '),
      _b('New letters', BeeColors.accent),
      _t(' — roll a fresh practice puzzle anytime (practice results can’t be '
          'shared).\n• '),
      _b('Today’s Puzzle', BeeColors.accent),
      _t(' — import that day’s outside puzzle and race it.\n• '),
      _b('Give up', BeeColors.accent),
      _t(' — reveal every word; your score locks in where it is.\n• '),
      _b('Tap any word', BeeColors.accent),
      _t(' — look up its meaning on dictionary.com.\n• '),
      _b('Share', BeeColors.accent),
      _t(' your results with friends and family.\n\nYour '),
      _b('Stats', BeeColors.accent),
      _t(' keep every average and best time. Now go set a record!'),
    ], asset: 'assets/icon/die.png'),
  ];

  void _finish() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to play'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FaqScreen())),
            child: const Text('FAQ'),
          ),
          if (!last)
            TextButton(
                onPressed: _finish,
                child: const Text('Skip',
                    style: TextStyle(color: BeeColors.muted))),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        p.asset != null
                            ? Image.asset(p.asset!, width: 120, height: 120)
                            : Text(p.emoji,
                                style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 24),
                        Text(p.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: BeeColors.cellText),
                            children: p.body,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index
                          ? BeeColors.accent
                          : BeeColors.surfaceHi,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: BeeColors.accent,
                  foregroundColor: const Color(0xFF0F1420),
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: last
                    ? _finish
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut),
                child: Text(last ? 'Got it — let’s play!' : 'Next',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
