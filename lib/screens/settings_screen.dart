import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dev_flags.dart';
import '../services/app_repository.dart';
import '../services/puzzle_engine.dart';
import '../theme.dart';
import 'faq_screen.dart';
import 'how_to_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppRepository repo;
  const SettingsScreen({super.key, required this.repo});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _clearOnWrong;
  late bool _haptics;

  @override
  void initState() {
    super.initState();
    _clearOnWrong = widget.repo.settings.clearOnWrong;
    _haptics = widget.repo.settings.hapticsEnabled;
  }

  Future<void> _confirmNewDay() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BeeColors.surface,
        title: const Text('Start a fresh day?'),
        content: const Text(
            'Rolls a brand-new set of letters for every size (6–11) and '
            'clears all of today\'s scores and stats — a totally clean slate. '
            'Note: practice puzzles from a fresh day can\'t be shared.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Fresh day')),
        ],
      ),
    );
    if (ok != true) return;
    // Truly fresh: wipe scores + stats, then roll new letters everywhere.
    await widget.repo.stats.reset();
    await widget.repo.progress.clearAll();
    final day = PuzzleEngine.dateOnly(DateTime.now());
    for (final size in PuzzleEngine.sizes) {
      await widget.repo.settings.bumpVariant(day, size);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Fresh puzzles ready for every size!'),
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: SwitchListTile(
                value: _clearOnWrong,
                activeThumbColor: BeeColors.accent,
                title: const Text('Clear entry after a wrong word'),
                subtitle: const Text(
                    'On: the letters clear automatically so you can retype. '
                    'Off: your entry stays put and you delete it yourself.'),
                onChanged: (v) async {
                  setState(() => _clearOnWrong = v);
                  await widget.repo.settings.setClearOnWrong(v);
                },
              ),
            ),
            Card(
              child: SwitchListTile(
                value: _haptics,
                activeThumbColor: BeeColors.accent,
                title: const Text('Vibration / haptics'),
                subtitle: const Text(
                    'Subtle taps for letters, found words, and rank-ups.'),
                onChanged: (v) async {
                  setState(() => _haptics = v);
                  await widget.repo.settings.setHapticsEnabled(v);
                  if (v) HapticFeedback.mediumImpact();
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.wb_sunny_outlined,
                    color: BeeColors.accent),
                title: const Text('Start a fresh day'),
                subtitle: const Text(
                    'New letters for every size (6–11) and clears today’s '
                    'scores and stats — a clean slate.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _confirmNewDay,
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(
                    widget.repo.entitlement.purchased
                        ? Icons.verified
                        : Icons.lock_open,
                    color: BeeColors.accent),
                title: Text(widget.repo.entitlement.purchased
                    ? 'Full version — unlocked'
                    : 'Restore purchase'),
                subtitle: Text(widget.repo.entitlement.purchased
                    ? 'Thanks for supporting Word Sprint!'
                    : 'Already bought it on this account? Restore it here.'),
                onTap: widget.repo.entitlement.purchased
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await widget.repo.purchases.restore();
                        if (!mounted) return;
                        setState(() {});
                        messenger.showSnackBar(const SnackBar(
                            content: Text('Checking for purchases…')));
                      },
              ),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline,
                        color: BeeColors.accent),
                    title: const Text('How to play'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const HowToScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.forum_outlined,
                        color: BeeColors.accent),
                    title: const Text('FAQ'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const FaqScreen())),
                  ),
                ],
              ),
            ),
            Card(
              child: ListTile(
                leading:
                    const Icon(Icons.info_outline, color: BeeColors.accent),
                title: const Text('About & licenses'),
                subtitle: const Text('Version, credits, open-source licenses.'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Word Sprint',
                  applicationVersion: '1.0.0',
                  applicationIcon: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/icon/logo.png',
                        width: 48, height: 48),
                  ),
                  children: const [
                    Text('A timing-focused word game.\n\n'
                        'Word list: the ENABLE dictionary (public domain).'),
                  ],
                ),
              ),
            ),
            // --- DEV ONLY (hidden in release via kDevTools) ---
            if (kDevTools)
              Card(
                color: BeeColors.surface,
                child: Column(
                  children: [
                    const ListTile(
                      dense: true,
                      title: Text('DEV — testing only',
                        style: TextStyle(
                            color: BeeColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.lock_clock, color: BeeColors.bad),
                    title: const Text('Expire trial (show paywall)'),
                    onTap: () async {
                      final m = ScaffoldMessenger.of(context);
                      await widget.repo.entitlement.devExpireTrial();
                      if (!mounted) return;
                      setState(() {});
                      m.showSnackBar(const SnackBar(
                          content: Text('Trial expired — locked.')));
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading:
                        const Icon(Icons.restart_alt, color: BeeColors.accent),
                    title: const Text('Reset to fresh trial'),
                    onTap: () async {
                      final m = ScaffoldMessenger.of(context);
                      await widget.repo.entitlement.devResetTrial();
                      if (!mounted) return;
                      setState(() {});
                      m.showSnackBar(const SnackBar(
                          content: Text('Trial reset — day 1.')));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
