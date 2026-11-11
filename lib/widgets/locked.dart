import 'package:flutter/material.dart';

import '../screens/sign_in_screen.dart';
import '../screens/upgrade_screen.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Opens sign-in (for free-account features) or the Premium screen.
Future<void> openUnlock(BuildContext context, Access needs) async {
  final nav = Navigator.of(context);
  if (needs == Access.member) {
    await nav.push(MaterialPageRoute<bool>(
      builder: (_) => const SignInScreen(reason: 'Sign in free to see your full plan and keep it on all your devices.'),
    ));
  } else {
    await nav.push(MaterialPageRoute<void>(builder: (_) => const UpgradeScreen()));
  }
}

/// A card that stands in for content that needs sign-in or Premium.
class LockedCard extends StatelessWidget {
  const LockedCard({super.key, required this.title, required this.message, required this.needs, this.dark = false});

  final String title;
  final String message;
  final Access needs;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final premium = needs == Access.premium;
    return CardBox(
      color: dark ? HC.nightCard : HC.card,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: premium ? HC.lime : HC.track, borderRadius: BorderRadius.circular(10)),
                child: Icon(premium ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded, size: 20, color: HC.ink),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: body(15, weight: FontWeight.w600, color: dark ? Colors.white : HC.ink))),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: body(13, color: dark ? HC.nightMuted : HC.muted)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: premium ? HC.violet : HC.ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => openUnlock(context, needs),
              child: Text(premium ? 'See Premium' : 'Sign in free', style: body(14, color: Colors.white, weight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A whole tab that needs Premium (Nearby, Party).
class LockedPage extends StatelessWidget {
  const LockedPage({
    super.key,
    required this.title,
    required this.message,
    required this.points,
    this.needs = Access.premium,
    this.dark = false,
  });

  final String title;
  final String message;
  final List<String> points;
  final Access needs;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final text = dark ? Colors.white : HC.ink;
    final muted = dark ? HC.nightMuted : HC.muted;
    return ListView(
      padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 48, 24, 24),
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: HC.lime, borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.workspace_premium_rounded, color: HC.ink, size: 32),
        ),
        const SizedBox(height: 20),
        Text(title, style: display(30, color: text)),
        const SizedBox(height: 8),
        Text(message, style: body(15, color: muted)),
        const SizedBox(height: 20),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, size: 20, color: dark ? HC.lime : HC.violet),
                const SizedBox(width: 10),
                Expanded(child: Text(p, style: body(15, color: text))),
              ],
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: dark ? HC.lime : HC.violet,
              foregroundColor: dark ? HC.ink : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => openUnlock(context, needs),
            child: Text(
              needs == Access.premium ? 'See Premium' : 'Sign in free',
              style: display(17, color: dark ? HC.ink : Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
