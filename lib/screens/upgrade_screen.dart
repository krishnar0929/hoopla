import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'sign_in_screen.dart';

/// One paid plan as shown on the subscription page. Edit prices and features here.
class PlanOffer {
  const PlanOffer({
    required this.tier,
    required this.tagline,
    required this.monthly,
    required this.yearly,
    required this.features,
    this.includes,
    this.badge,
    this.comingSoon,
  });

  final Tier tier;
  final String tagline;
  final double monthly;
  final double yearly;
  final List<String> features;

  /// "Everything in Basic, plus:"
  final String? includes;
  final String? badge;

  /// Shown under the features when part of the plan isn't built yet.
  final String? comingSoon;

  /// Percent saved by paying yearly instead of 12 months.
  int get yearlySavings => (100 - yearly / (monthly * 12) * 100).round();
}

const planOffers = <PlanOffer>[
  PlanOffer(
    tier: Tier.basic,
    tagline: 'Plan a party without the stress',
    monthly: 3.99,
    yearly: 29.99,
    features: [
      'Full timeline and checklist with due dates',
      'All party games with how-to videos',
      'Budget planner with a suggested split',
      'Party-day mode: timer and team scoreboard',
      'Return gift ideas, party playlist and invite text',
      'Plan several events at once',
    ],
  ),
  PlanOffer(
    tier: Tier.pro,
    tagline: 'Find the right people and invite everyone',
    monthly: 9.99,
    yearly: 79.99,
    badge: 'Most popular',
    includes: 'Everything in Basic, plus:',
    features: [
      'Find photographers, decorators, panthulu, cake makers and more nearby',
      'Compare ratings, reviews and prices',
      'Call, WhatsApp and request quotes in one tap',
      'Message providers and send booking requests',
      'Invite guests from your phone contacts, by text and email',
      'Share invites to WhatsApp chats and groups',
      'RSVP tracking, live guest count and reminders',
    ],
    comingSoon: 'Messages, booking requests and invites arrive in upcoming updates.',
  ),
];

/// Subscription page: Basic and Pro, monthly or yearly.
/// Payments are not connected yet; choosing a plan says so.
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool yearly = false;

  Future<void> _choose(PlanOffer offer) async {
    final state = AppScope.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!state.isSignedIn) {
      final ok = await nav.push<bool>(MaterialPageRoute(
        builder: (_) => const SignInScreen(reason: 'Sign in first so your plan stays with your account on every device.'),
      ));
      if (ok != true) return;
    }
    // Each account gets one 3-day free trial.
    if (!state.trialUsed && state.paidTier.index < offer.tier.index) {
      try {
        await state.startTrial(offer.tier);
        final ends = state.trialEndsAt;
        messenger.showSnackBar(SnackBar(
          content: Text(
            'Your 3-day ${offer.tier.label} trial has started'
            '${ends == null ? '' : ' and ends ${DateFormat('EEE, MMM d').format(ends)}'}. Cancel anytime from Account.',
          ),
        ));
        if (mounted) nav.pop();
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Could not start the trial: $e')));
      }
      return;
    }
    final price = yearly ? '\$${offer.yearly.toStringAsFixed(2)}/year' : '\$${offer.monthly.toStringAsFixed(2)}/month';
    messenger.showSnackBar(SnackBar(
      content: Text('Payments are coming soon. ${offer.tier.label} ($price) will be ready in the next update.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final current = state.tier;
    return Scaffold(
      backgroundColor: HC.ink,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
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
                const SizedBox(height: 4),
                Text('Choose your plan', style: display(32, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  state.onTrial
                      ? 'You\'re trying ${current.label} free until ${DateFormat('EEE, MMM d · h:mm a').format(state.trialEndsAt!)}.'
                      : state.trialEnded
                          ? 'Your free trial has ended. Choose a plan to keep going.'
                          : current == Tier.free
                              ? 'Start free. Upgrade when you need more for your party.'
                              : 'You\'re on ${current.label}. Switch anytime.',
                  style: body(15, color: HC.nightMuted),
                ),
                if (!state.trialUsed) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: HC.lime, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.card_giftcard_rounded, color: HC.ink),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '3 days free on any plan. Cancel within 3 days and you pay nothing.',
                            style: body(14, weight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _BillingToggle(
                  yearly: yearly,
                  onChanged: (v) => setState(() => yearly = v),
                ),
                const SizedBox(height: 18),
                for (final offer in planOffers) ...[
                  _PlanCard(
                    offer: offer,
                    yearly: yearly,
                    current: offer.tier == current,
                    trialAvailable: !state.trialUsed && state.paidTier.index < offer.tier.index,
                    trialEnds: state.onTrial && state.trialTier == offer.tier ? state.trialEndsAt : null,
                    onChoose: () => _choose(offer),
                  ),
                  const SizedBox(height: 14),
                ],
                _FreeCard(current: current == Tier.free),
                const SizedBox(height: 16),
                Text(
                  'Prices in USD. One 3-day free trial per account. After the trial, your plan renews each month or year '
                  'until you cancel in your App Store or Google Play settings. Payments are coming soon; until then '
                  'your plan goes back to Free when the trial ends.',
                  textAlign: TextAlign.center,
                  style: body(12, color: HC.nightMuted),
                ),
                TextButton(
                  onPressed: () => toast(context, 'Restore purchases will work once payments are live.'),
                  child: Text('Restore purchases', style: body(13, color: Colors.white, weight: FontWeight.w600)),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 10),
                  _DevTierPicker(state: state),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BillingToggle extends StatelessWidget {
  const _BillingToggle({required this.yearly, required this.onChanged});
  final bool yearly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool value, {String? note}) {
      final selected = yearly == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 46,
            decoration: BoxDecoration(
              color: selected ? HC.card : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Semantics(
              button: true,
              selected: selected,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: body(15, weight: FontWeight.w600, color: selected ? HC.ink : Colors.white)),
                  if (note != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: HC.lime, borderRadius: BorderRadius.circular(6)),
                      child: Text(note, style: body(11, weight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: HC.nightCard, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          option('Monthly', false),
          option('Yearly', true, note: 'Save up to 37%'),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.offer,
    required this.yearly,
    required this.current,
    required this.trialAvailable,
    required this.onChoose,
    this.trialEnds,
  });
  final PlanOffer offer;
  final bool yearly;
  final bool current;
  final bool trialAvailable;

  /// Set when this plan is on its free trial right now.
  final DateTime? trialEnds;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final highlight = offer.badge != null;
    final price = yearly ? offer.yearly : offer.monthly;
    final perMonth = offer.yearly / 12;
    return Container(
      decoration: BoxDecoration(
        color: HC.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: highlight ? HC.lime : HC.card, width: 3),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(offer.tier.label, style: display(24)),
              const SizedBox(width: 8),
              if (offer.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: HC.lime, borderRadius: BorderRadius.circular(8)),
                  child: Text(offer.badge!, style: body(11, weight: FontWeight.w700)),
                ),
              const Spacer(),
              if (current)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: HC.track, borderRadius: BorderRadius.circular(8)),
                  child: Text(trialEnds != null ? 'Free trial' : 'Your plan', style: body(11, weight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(offer.tagline, style: body(14, color: HC.muted)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${price.toStringAsFixed(2)}', style: display(34, color: HC.violet)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(yearly ? '/ year' : '/ month', style: body(14, color: HC.muted)),
              ),
            ],
          ),
          if (yearly)
            Text(
              '\$${perMonth.toStringAsFixed(2)} a month · save ${offer.yearlySavings}%',
              style: body(13, color: HC.muted, weight: FontWeight.w500),
            ),
          const SizedBox(height: 14),
          if (offer.includes != null) ...[
            Text(offer.includes!, style: body(13, weight: FontWeight.w600)),
            const SizedBox(height: 8),
          ],
          for (final f in offer.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: HC.violet),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: body(14))),
                ],
              ),
            ),
          if (offer.comingSoon != null) ...[
            const SizedBox(height: 2),
            Text(offer.comingSoon!, style: body(12, color: HC.muted)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: highlight ? HC.violet : HC.ink,
                disabledBackgroundColor: HC.track,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: current ? null : onChoose,
              child: Text(
                current
                    ? 'Current plan'
                    : trialAvailable
                        ? 'Start 3-day free trial'
                        : 'Choose ${offer.tier.label}',
                style: body(15, weight: FontWeight.w600, color: current ? HC.muted : Colors.white),
              ),
            ),
          ),
          if (trialEnds != null) ...[
            const SizedBox(height: 8),
            Text(
              'Trial ends ${DateFormat('EEE, MMM d · h:mm a').format(trialEnds!)}. Cancel anytime from Account.',
              textAlign: TextAlign.center,
              style: body(12, color: HC.muted),
            ),
          ] else if (trialAvailable && !current) ...[
            const SizedBox(height: 8),
            Text(
              'Free for 3 days, then \$${price.toStringAsFixed(2)}/${yearly ? 'year' : 'month'}. Cancel anytime.',
              textAlign: TextAlign.center,
              style: body(12, color: HC.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _FreeCard extends StatelessWidget {
  const _FreeCard({required this.current});
  final bool current;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      color: HC.nightCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Free', style: display(20, color: Colors.white)),
              const Spacer(),
              if (current) Text('Your plan', style: body(12, color: HC.lime, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Plan one event with the full timeline and checklist, browse every game, and save funny game reels '
            'from Instagram. Without an account you see a preview of your plan.',
            style: body(13, color: HC.nightMuted),
          ),
        ],
      ),
    );
  }
}

/// Debug builds only: try each plan without paying.
class _DevTierPicker extends StatelessWidget {
  const _DevTierPicker({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      color: HC.nightCard,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Developer: test a plan on this device', style: body(14, color: Colors.white, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Only in debug builds. Hidden in TestFlight, the App Store and the live website.', style: body(12, color: HC.nightMuted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(label: 'Real plan', small: true, selected: state.devTier == null, selectedColor: HC.violet, onTap: () => state.setDevTier(null)),
              for (final t in Tier.values)
                Pill(label: t.label, small: true, selected: state.devTier == t, selectedColor: HC.violet, onTap: () => state.setDevTier(t)),
            ],
          ),
        ],
      ),
    );
  }
}
