import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'sign_in_screen.dart';
import 'upgrade_screen.dart';

const _danger = Color(0xFFB42318);

/// Account: sign in, plan, become a provider, sign out, delete account.
void showAccountSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HC.ground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

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

    final children = <Widget>[
      Text('Account', style: display(22)),
      const SizedBox(height: 10),
    ];

    if (!state.usingCloud) {
      children.add(Text('Sign-in turns on once Firebase is connected (flutterfire configure).', style: body(14, color: HC.muted)));
    } else if (!state.isSignedIn) {
      children.addAll([
        Text(
          'You\'re using Hoopla as a guest. Sign in free to see your full plan and keep it on all your devices.',
          style: body(14, color: HC.muted),
        ),
        const SizedBox(height: 16),
        _SheetButton(label: 'Sign in or create account', filled: true, onTap: () => open(const SignInScreen())),
        _SheetButton(
          label: 'I offer a service: join as a provider',
          onTap: () => open(const SignInScreen(initialRole: UserRole.provider)),
        ),
      ]);
    } else {
      children.addAll([
        Text(state.email ?? 'Signed in', style: body(15, weight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          '${state.isProvider ? 'Provider' : 'Customer'} · ${state.tier.label} plan',
          style: body(13, color: HC.muted),
        ),
        const SizedBox(height: 16),
        if (state.tier != Tier.host)
          _SheetButton(label: state.isPremium ? 'Change plan' : 'See plans', filled: true, onTap: () => open(const UpgradeScreen())),
        if (!state.isProvider)
          _SheetButton(
            label: 'Offer a service? Become a provider',
            onTap: () {
              nav.pop();
              state.setRole(UserRole.provider);
            },
          )
        else
          _SheetButton(
            label: 'Switch to planning my own event',
            onTap: () {
              nav.pop();
              state.setRole(UserRole.customer);
            },
          ),
        _SheetButton(
          label: 'Sign out',
          onTap: () {
            nav.pop();
            state.signOut();
          },
        ),
        TextButton(
          onPressed: () => _delete(context),
          child: Text('Delete account', style: body(14, color: _danger, weight: FontWeight.w600)),
        ),
      ]);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({required this.label, required this.onTap, this.filled = false});
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 48,
        child: filled
            ? FilledButton(
                style: FilledButton.styleFrom(backgroundColor: HC.violet, shape: shape),
                onPressed: onTap,
                child: Text(label, style: body(14, color: Colors.white, weight: FontWeight.w600)),
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: HC.line), shape: shape),
                onPressed: onTap,
                child: Text(label, style: body(14, weight: FontWeight.w600)),
              ),
      ),
    );
  }
}
