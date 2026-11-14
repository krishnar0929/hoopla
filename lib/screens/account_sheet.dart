import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/account_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'feedback_sheet.dart';
import 'help_screen.dart';
import 'refer_screen.dart';
import 'sign_in_screen.dart';
import 'upgrade_screen.dart';
import 'party_stories_screen.dart';

const _danger = Color(0xFFB42318);

/// Account: a panel that slides in from the right on wide screens (web, iPad)
/// and a bottom sheet on phones.
void showAccountSheet(BuildContext context) {
  final wide = MediaQuery.of(context).size.width >= 720;
  if (!wide) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: HC.ground,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => _AccountSheet(controller: controller),
      ),
    );
    return;
  }
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close account',
    barrierColor: const Color(0x6617142B),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: HC.ground,
        elevation: 12,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 420,
          height: double.infinity,
          child: SafeArea(child: _AccountSheet(showClose: true)),
        ),
      ),
    ),
    transitionBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet({this.controller, this.showClose = false});
  final ScrollController? controller;
  final bool showClose;

  Future<void> _cancelTrial(BuildContext context) async {
    final state = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel your free trial?'),
        content: const Text('Your plan goes back to Free now and you won\'t be charged. Each account gets one free trial.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep trial')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel trial'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await state.cancelTrial();
      messenger.showSnackBar(const SnackBar(content: Text('Trial cancelled. You won\'t be charged.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final state = AppScope.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('This deletes your events, provider listing and login. It can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep account')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    nav.pop();
    final error = await state.deleteAccount();
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Your account and data were deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final nav = Navigator.of(context);

    void open(Widget page) {
      nav.pop();
      nav.push(MaterialPageRoute<void>(builder: (_) => page));
    }

    final signedIn = state.usingCloud && state.isSignedIn;
    final email = state.email ?? '';
    final name = (state.profile?['name'] as String?)?.trim();
    final shownName = (name != null && name.isNotEmpty) ? name : (signedIn ? email.split('@').first : 'Guest');

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text('Account', style: display(26))),
            if (showClose)
              IconButton(tooltip: 'Close', onPressed: () => nav.pop(), icon: const Icon(Icons.close_rounded)),
          ],
        ),
        const SizedBox(height: 14),

        // ---- profile header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [HC.ink, Color(0xFF2E2560)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: HC.lime, shape: BoxShape.circle),
                child: signedIn
                    ? Text(shownName.isEmpty ? '?' : shownName[0].toUpperCase(), style: display(22))
                    : const Icon(Icons.person_outline_rounded, color: HC.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shownName, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(18, color: Colors.white)),
                    if (signedIn && email.isNotEmpty && email != shownName)
                      Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, color: HC.nightMuted)),
                    const SizedBox(height: 6),
                    _Chip(
                      !state.usingCloud
                          ? 'Offline'
                          : !signedIn
                              ? 'Not signed in'
                              : state.isProvider
                                  ? 'Provider · ${state.provider?.serviceType ?? 'listing'}'
                                  : 'Planning events · free',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (AppState.userPlansEnabled && signedIn && state.onTrial) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(color: HC.lime, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Expanded(
                  child: Text('Free trial ends ${DateFormat('EEE, MMM d · h:mm a').format(state.trialEndsAt!)}.',
                      style: body(13, weight: FontWeight.w600)),
                ),
                TextButton(onPressed: () => _cancelTrial(context), child: const Text('Cancel trial')),
              ],
            ),
          ),
        ],

        // ---- guest: sign in
        if (!state.usingCloud) ...[
          const SizedBox(height: 14),
          Text('Sign-in turns on once Firebase is connected (flutterfire configure).', style: body(14, color: HC.muted)),
        ] else if (!signedIn) ...[
          const SizedBox(height: 16),
          Text('Save your plans and use them on every device. It\'s free.', style: body(14, color: HC.muted)),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: HC.violet, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () => open(const SignInScreen()),
              child: Text('Sign in or create account', style: body(15, color: Colors.white, weight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 18),
          _Group(title: 'For businesses', rows: [
            _Row(
              icon: Icons.storefront_outlined,
              color: HC.coral,
              title: 'List your business free',
              subtitle: 'Photographers, bakers, DJs, decorators, panthulu, caterers…',
              onTap: () => open(const SignInScreen(initialRole: UserRole.provider)),
            ),
          ]),
        ],

        // ---- signed in: account
        if (signedIn) ...[
          const SizedBox(height: 18),
          _Group(title: 'Your account', rows: [
            if (AppState.userPlansEnabled && state.tier != Tier.pro)
              _Row(
                icon: Icons.workspace_premium_outlined,
                color: HC.violet,
                title: state.isPremium ? 'Change plan' : 'See plans',
                onTap: () => open(const UpgradeScreen()),
              ),
            if (!state.isProvider)
              _Row(
                icon: Icons.storefront_outlined,
                color: HC.coral,
                title: 'Offer a service',
                subtitle: 'Switch to a provider account and get listed',
                onTap: () {
                  nav.pop();
                  state.setRole(UserRole.provider);
                },
              )
            else
              _Row(
                icon: Icons.celebration_outlined,
                color: HC.violet,
                title: 'Plan my own event',
                subtitle: 'Switch to planning mode',
                onTap: () {
                  nav.pop();
                  state.setRole(UserRole.customer);
                },
              ),
          ]),
        ],

        const SizedBox(height: 18),
        _Group(title: 'Hoopla', rows: [
          _Row(
            icon: Icons.celebration_outlined,
            color: HC.coral,
            title: 'Party stories',
            subtitle: 'Celebrations planned with Hoopla, with photos and games',
            onTap: () => open(const PartyStoriesScreen()),
          ),
          _Row(
            icon: Icons.card_giftcard_rounded,
            color: const Color(0xFF2EC4B6),
            title: 'Invite friends',
            subtitle: 'Share Hoopla with friends and providers you trust',
            onTap: () => open(const ReferScreen()),
          ),
          _Row(
            icon: Icons.chat_bubble_outline_rounded,
            color: HC.violet,
            title: 'Help & feedback',
            subtitle: 'Email us, send an idea or report a problem',
            onTap: () => open(const HelpScreen()),
          ),
          _Row(
            icon: Icons.star_outline_rounded,
            color: const Color(0xFFF5B400),
            title: 'Rate Hoopla',
            onTap: () {
              nav.pop();
              showRateSheet(nav.context);
            },
          ),
        ]),

        if (signedIn) ...[
          const SizedBox(height: 18),
          _Group(rows: [
            _Row(
              icon: Icons.logout_rounded,
              color: HC.muted,
              title: 'Sign out',
              onTap: () {
                nav.pop();
                state.signOut();
              },
            ),
          ]),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _delete(context),
              child: Text('Delete account', style: body(13, color: _danger, weight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: body(12, color: Colors.white, weight: FontWeight.w600)),
    );
  }
}

/// A white rounded group of rows, like iOS Settings.
class _Group extends StatelessWidget {
  const _Group({this.title, required this.rows});
  final String? title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title!.toUpperCase(), style: overline()),
          ),
        Container(
          decoration: BoxDecoration(
            color: HC.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HC.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 64, color: HC.line),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.color, required this.title, required this.onTap, this.subtitle});
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: body(15, weight: FontWeight.w600)),
                    if (subtitle != null) Text(subtitle!, style: body(12, color: HC.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: HC.muted),
            ],
          ),
        ),
      ),
    );
  }
}
