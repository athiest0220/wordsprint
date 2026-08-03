import 'package:flutter/material.dart';

import '../dev_flags.dart';
import '../services/app_repository.dart';
import '../services/audio_service.dart';
import '../services/puzzle_engine.dart';
import '../services/settings_store.dart';
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
  late bool _showOops;
  late LevelSetting _soundLevel;
  late LevelSetting _musicLevel;
  late String _musicTrack;
  late HapticIntensity _hapticIntensity;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _clearOnWrong = widget.repo.settings.clearOnWrong;
    _showOops = widget.repo.settings.showOops;
    _soundLevel = widget.repo.settings.soundLevel;
    _musicLevel = widget.repo.settings.musicLevel;
    _musicTrack = widget.repo.settings.musicTrack;
    _hapticIntensity = widget.repo.settings.hapticIntensity;
    _themeMode = widget.repo.settings.themeMode;
  }

  static const List<ButtonSegment<LevelSetting>> _levelSegments = [
    ButtonSegment(value: LevelSetting.off, label: Text('Off')),
    ButtonSegment(value: LevelSetting.low, label: Text('Low')),
    ButtonSegment(value: LevelSetting.medium, label: Text('Med')),
    ButtonSegment(value: LevelSetting.high, label: Text('High')),
  ];

  static const List<ButtonSegment<HapticIntensity>> _hapticSegments = [
    ButtonSegment(value: HapticIntensity.off, label: Text('Off')),
    ButtonSegment(value: HapticIntensity.low, label: Text('Low')),
    ButtonSegment(value: HapticIntensity.medium, label: Text('Med')),
    ButtonSegment(value: HapticIntensity.high, label: Text('High')),
  ];

  /// Uniform card: leading icon + title, a description, and a full-width
  /// segmented control (optionally with an extra control beneath, e.g. the
  /// music soundtrack picker).
  Widget _levelCard<T>({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<ButtonSegment<T>> segments,
    required T selected,
    required ValueChanged<T> onChanged,
    Widget? extra,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: BeeColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(color: BeeColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<T>(
                segments: segments,
                selected: {selected},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onChanged(s.first),
              ),
            ),
            if (extra != null) extra,
          ],
        ),
      ),
    );
  }

  /// Uniform on/off card with a leading icon, matching the level cards' left
  /// alignment.
  Widget _switchCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: SwitchListTile(
        value: value,
        activeThumbColor: BeeColors.accent,
        secondary: Icon(icon, color: BeeColors.accent),
        title: Text(title),
        subtitle: Text(subtitle),
        onChanged: onChanged,
      ),
    );
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
            // --- ordered by importance: feel first, then gameplay, then admin ---

            // Sound effects — Off / Low / Med / High
            _levelCard<LevelSetting>(
              icon: Icons.volume_up_outlined,
              title: 'Sound effects',
              subtitle: 'Blips for taps, found words, and round start/finish.',
              segments: _levelSegments,
              selected: _soundLevel,
              onChanged: (v) async {
                setState(() => _soundLevel = v);
                await widget.repo.settings.setSoundLevel(v);
                if (v != LevelSetting.off) {
                  await widget.repo.audio.setSoundVolume(audioFromLevel(v));
                  widget.repo.audio.valid(); // preview at the new level
                }
              },
            ),

            // Background music — Off / Low / Med / High + soundtrack picker
            _levelCard<LevelSetting>(
              icon: Icons.music_note_outlined,
              title: 'Background music',
              subtitle: 'A soundtrack while you play.',
              segments: _levelSegments,
              selected: _musicLevel,
              onChanged: (v) async {
                setState(() => _musicLevel = v);
                await widget.repo.settings.setMusicLevel(v);
                if (v == LevelSetting.off) {
                  await widget.repo.audio.pauseMusic();
                } else {
                  await widget.repo.audio.setMusicVolume(audioFromLevel(v));
                  await widget.repo.audio.startMusic();
                }
              },
              extra: _musicLevel == LevelSetting.off
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          const Text('Soundtrack'),
                          const Spacer(),
                          DropdownButton<String>(
                            value: _musicTrack,
                            underline: const SizedBox.shrink(),
                            items: [
                              const DropdownMenuItem(
                                  value: AudioService.shuffleId,
                                  child: Text('Shuffle all')),
                              for (final t in AudioService.musicTracks)
                                DropdownMenuItem(
                                    value: t.id, child: Text(t.name)),
                            ],
                            onChanged: (v) async {
                              if (v == null) return;
                              setState(() => _musicTrack = v);
                              await widget.repo.audio.setMusicTrack(v);
                            },
                          ),
                        ],
                      ),
                    ),
            ),

            // Vibration / haptics — Off / Low / Med / High
            _levelCard<HapticIntensity>(
              icon: Icons.vibration,
              title: 'Vibration / haptics',
              subtitle: 'Strength of the buzz on taps, found words, and rank-ups.',
              segments: _hapticSegments,
              selected: _hapticIntensity,
              onChanged: (v) async {
                setState(() => _hapticIntensity = v);
                await widget.repo.settings.setHapticIntensity(v);
                if (v != HapticIntensity.off) widget.repo.haptics.preview();
              },
            ),

            // Appearance — System / Light / Dark
            _levelCard<ThemeMode>(
              icon: Icons.brightness_6_outlined,
              title: 'Appearance',
              subtitle: 'Light, dark, or follow your device.',
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: _themeMode,
              onChanged: (v) async {
                setState(() => _themeMode = v);
                await widget.repo.settings.setThemeMode(v);
                appThemeMode.value = v; // live-apply across the app
              },
            ),

            // Clear entry after a wrong word
            _switchCard(
              icon: Icons.backspace_outlined,
              title: 'Clear entry after a wrong word',
              subtitle: 'On: the letters clear automatically so you can retype. '
                  'Off: your entry stays put and you delete it yourself.',
              value: _clearOnWrong,
              onChanged: (v) async {
                setState(() => _clearOnWrong = v);
                await widget.repo.settings.setClearOnWrong(v);
              },
            ),

            // Show mistake counter
            _switchCard(
              icon: Icons.error_outline,
              title: 'Show mistake counter',
              subtitle: 'Shows the “Oops” count while you play, and on your '
                  'shared result. Turn it off if tracking mistakes isn’t your '
                  'thing.',
              value: _showOops,
              onChanged: (v) async {
                setState(() => _showOops = v);
                await widget.repo.settings.setShowOops(v);
              },
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
                    ListTile(
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
