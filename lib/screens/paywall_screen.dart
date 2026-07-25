import 'package:flutter/material.dart';

import '../dev_flags.dart';
import '../services/app_repository.dart';
import '../theme.dart';

/// Shown when the free trial is over and the game isn't unlocked yet.
class PaywallScreen extends StatefulWidget {
  final AppRepository repo;
  const PaywallScreen({super.key, required this.repo});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  @override
  void initState() {
    super.initState();
    widget.repo.purchases.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.repo.purchases.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    if (widget.repo.entitlement.entitled) {
      Navigator.of(context).pop(true); // unlocked — let the caller proceed
    } else {
      setState(() {}); // refresh price / error
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.repo.purchases;
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock Word Sprint')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 12),
            Center(
              child: Image.asset('assets/icon/logo.png', width: 96, height: 96),
            ),
            const SizedBox(height: 16),
            const Text('Your free trial is complete',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text(
              'You’ve had three free days on the clock. Unlock the full game — '
              'one time, yours forever.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BeeColors.muted, height: 1.4),
            ),
            const SizedBox(height: 20),
            _perk('Every size, every day (6–11 letters)'),
            _perk('All three speed clocks + full stats'),
            _perk('Unlimited practice & imports'),
            _perk('No ads. No subscription. No nonsense.'),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: BeeColors.accent,
                foregroundColor: const Color(0xFF0F1420),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => p.buy(),
              child: Text('Unlock forever  •  ${p.priceLabel}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => p.restore(),
                child: const Text('Restore purchase'),
              ),
            ),
            if (p.lastError != null) ...[
              const SizedBox(height: 8),
              Text(p.lastError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: BeeColors.bad, fontSize: 12)),
            ],
            if (kDevTools) ...[
              const SizedBox(height: 24),
              const Divider(color: BeeColors.surfaceHi),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await widget.repo.entitlement.setPurchased(true);
                    nav.pop(true);
                  },
                  child: const Text('DEV: unlock without paying (testing)',
                      style: TextStyle(color: BeeColors.muted, fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _perk(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: BeeColors.good, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(t)),
          ],
        ),
      );
}
