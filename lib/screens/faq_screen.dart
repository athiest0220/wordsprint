import 'package:flutter/material.dart';
import '../theme.dart';

class _QA {
  final String q;
  final String a;
  const _QA(this.q, this.a);
}

/// A deliberately cheeky FAQ.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _items = <_QA>[
    _QA(
      'Why does Word Sprint have so many more words than other spelling games?',
      'Ask not why ours has MORE words — ask why theirs has fewer.\n\n'
          'We build our word list from the actual English dictionary. Not the '
          'Scrabble dictionary. Not the Urban Dictionary. The English one — you '
          'know, the big one with all the English in it. So yes, some days '
          'you’ll find words you didn’t know existed. That’s not a bug. That’s '
          'a vocabulary.',
    ),
    _QA(
      'Why are there no swear words?',
      'It’s a family game. Feel free to curse at your own kids however you wish '
          '— we just kept this one clean so nobody risks a mouthful of soap.',
    ),
    _QA(
      'Do I really have to use the center letter?',
      'Every single word. It’s the needy one. No center letter, no points.',
    ),
    _QA(
      'What’s a pangram? A perfect pangram?',
      'A pangram uses every letter on the board at least once (it turns blue in '
          'your list). A perfect pangram uses each letter exactly once (it turns '
          'gold) and is scientifically proven* to make you feel brilliant.\n\n'
          '*not actually proven.',
    ),
    _QA(
      'Why is the clock hidden?',
      'Because a ticking clock turns a nice word game into a cardiology '
          'appointment. Tap the timer icon if you enjoy living dangerously.',
    ),
    _QA(
      'I tapped a word and it opened dictionary.com. Magic?',
      'Every word in your list is a link — tap it to find out what on earth it '
          'means. Great for those “that’s definitely not a word” moments. (It '
          'is. It’s always a word.)',
    ),
    _QA(
      'Why can’t I share my practice puzzles?',
      '“I got Flawless on a puzzle that only I have ever seen” is not the flex '
          'you think it is. Share the real daily — everyone gets the same one.',
    ),
    _QA(
      'Is there a subscription?',
      'No. Three free days, then \$2.99 once, yours forever. We’re a word game, '
          'not a gym membership.',
    ),
    _QA(
      'I reached Flawless. Am I better than everyone I know?',
      'Legally, we cannot confirm this. Emotionally, absolutely.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final item = _items[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.q,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: BeeColors.accent)),
                    const SizedBox(height: 8),
                    Text(item.a,
                        style: const TextStyle(height: 1.45)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
