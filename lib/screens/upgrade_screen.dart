import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'sign_in_screen.dart';

/// Hoopla Premium: what it unlocks and the plans.
/// Payments are not connected yet; tapping a plan says so.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  static const _benefits = [
    (Icons.place_outlined, 'Find nearby photographers, decorators, panthulu and more'),
    (Icons.chat_outlined, 'Call, WhatsApp and request quotes in one tap'),
    (Icons.celebration_outlined, 'Party-day mode with timer and team scoreboard'),
    (Icons.account_balance_wallet_outlined, 'Budget planner with a suggested split'),
    (Icons.bookmark_border_rounded, 'Save funny game reels from Instagram'),
    (Icons.event_note_outlined, 'Plan several events at once'),
  ];

  Future<void> _choose(BuildContext context, String plan) async {
    final state = AppScope.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!state.isSignedIn) {
      final ok = await nav.push<bool>(MaterialPageRoute(
        builder: (_) => const SignInScreen(reason: 'Sign in first so Premium stays with your account on every device.'),
      ));
      if (ok != true) return;
    }
    messenger.showSnackBar(SnackBar(content: Text('Payments are coming soon. $plan will be ready in the next update.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      backgroundColor: HC.ink,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Hoopla Premium', style: display(34, color: Colors.white)),
                const SizedBox(height: 6),
                Text('Everything you need for a party people remember.', style: body(15, color: HC.nightMuted)),
                if (state.isPremium) ...[
                  const SizedBox(height: 16),
                  CardBox(
                    color: HC.lime,
                    child: Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, color: HC.ink),
                        const SizedBox(width: 10),
                        Expanded(child: Text('You\'re on Premium. Everything is unlocked.', style: body(14, weight: FontWeight.w600))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                for (final b in _benefits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: HC.nightCard, borderRadius: BorderRadius.circular(10)),
                          child: Icon(b.$1, color: HC.lime, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(b.$2, style: body(15, color: Colors.white))),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                _PlanCard(
                  name: 'Party Pass',
                  price: '\$4.99',
                  detail: 'One event, everything unlocked until the party is over.',
                  onTap: () => _choose(context, 'Party Pass'),
                ),
                const SizedBox(height: 10),
                _PlanCard(
                  name: 'Yearly',
                  price: '\$19.99',
                  detail: 'Unlimited events for 12 months.',
                  badge: 'Best value',
                  onTap: () => _choose(context, 'Yearly'),
                ),
                const SizedBox(height: 14),
                Text(
                  'Payments are coming soon. Prices may change before launch.',
                  textAlign: TextAlign.center,
                  style: body(12, color: HC.nightMuted),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 22),
                  CardBox(
                    color: HC.nightCard,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: SwitchListTile(
                      value: state.devPremium,
                      onChanged: state.setDevPremium,
                      activeColor: HC.lime,
                      title: Text('Developer: Premium on this device', style: body(14, color: Colors.white, weight: FontWeight.w600)),
                      subtitle: Text('Only in debug builds, for testing. Hidden in TestFlight and the App Store.', style: body(12, color: HC.nightMuted)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.name, required this.price, required this.detail, required this.onTap, this.badge});
  final String name;
  final String price;
  final String detail;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      color: HC.card,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: display(19)),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: HC.lime, borderRadius: BorderRadius.circular(8)),
                        child: Text(badge!, style: body(11, weight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(detail, style: body(13, color: HC.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(price, style: display(22, color: HC.violet)),
        ],
      ),
    );
  }
}
