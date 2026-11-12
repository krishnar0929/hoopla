import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/referrals.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Sign in or create an account, as a customer (planning an event)
/// or as a provider (photographer, decorator, panthulu, ...).
/// Returns true when signed in.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.initialRole = UserRole.customer, this.reason});

  final UserRole initialRole;
  final String? reason;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late UserRole role = widget.initialRole;
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final refCtrl = TextEditingController();
  bool _refFilled = false;
  bool creating = true;
  bool busy = false;
  String? error;

  bool get _showApple => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _showGoogle => kIsWeb || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    refCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_refFilled) {
      _refFilled = true;
      refCtrl.text = AppScope.of(context).pendingRefCode ?? '';
    }
  }

  bool get _askForCode => creating && role == UserRole.customer;

  Future<void> _run(Future<void> Function(AccountService a) action) async {
    final state = AppScope.of(context);
    final a = state.accounts;
    if (a == null) {
      setState(() => error = 'Sign-in needs Firebase. Run flutterfire configure first.');
      return;
    }
    final typed = refCtrl.text.trim();
    if (_askForCode && typed.isNotEmpty) {
      if (normalizeCode(typed) == null) {
        setState(() => error = 'That friend\'s code doesn\'t look right. Codes are 6 letters and numbers.');
        return;
      }
      await state.setPendingRefCode(typed);
    }
    final carry = List.of(state.events);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action(a);
      await state.afterSignIn(role, carry);
      final notice = state.takeReferralNotice();
      if (notice != null) messenger.showSnackBar(SnackBar(content: Text(notice)));
      if (mounted) nav.pop(true);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = _message(e));
    } catch (e) {
      if (mounted) setState(() => error = 'Something went wrong. Please try again. ($e)');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _email() {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;
    if (!email.contains('@') || pass.isEmpty) {
      setState(() => error = 'Enter your email and a password.');
      return;
    }
    _run((a) => a.emailSignIn(email: email, password: pass, create: creating));
  }

  Future<void> _forgot() async {
    final a = AppScope.of(context).accounts;
    final email = emailCtrl.text.trim();
    if (a == null || !email.contains('@')) {
      setState(() => error = 'Type your email above first.');
      return;
    }
    try {
      await a.sendPasswordReset(email);
      if (mounted) toast(context, 'Password reset link sent to $email.');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = _message(e));
    }
  }

  static String? _message(FirebaseAuthException e) => switch (e.code) {
        'popup-closed-by-user' || 'cancelled-popup-request' || 'canceled' || 'web-context-canceled' => null,
        'invalid-email' => 'That email doesn\'t look right.',
        'wrong-password' || 'invalid-credential' || 'user-not-found' => 'Email or password is wrong.',
        'email-already-in-use' => 'That email already has an account. Tap "Have an account? Sign in".',
        'weak-password' => 'Use a password with at least 6 characters.',
        'too-many-requests' => 'Too many tries. Wait a minute and try again.',
        'network-request-failed' => 'No internet connection.',
        'operation-not-allowed' => 'This sign-in method isn\'t turned on yet (Firebase → Authentication → Sign-in method).',
        'popup-blocked' => 'Your browser blocked the pop-up. Allow pop-ups for this site and try again.',
        _ => e.message ?? 'Sign-in failed (${e.code}).',
      };

  @override
  Widget build(BuildContext context) {
    final provider = role == UserRole.provider;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(creating ? 'Create your account' : 'Welcome back', style: display(30)),
                  const SizedBox(height: 6),
                  Text(widget.reason ?? 'It\'s free. Your plans stay safe on all your devices.', style: body(14, color: HC.muted)),
                  const SizedBox(height: 22),
                  const SectionLabel('I am'),
                  Segmented(
                    options: const ['Planning an event', 'A service provider'],
                    selected: provider ? 1 : 0,
                    height: 42,
                    onChanged: (i) => setState(() => role = i == 0 ? UserRole.customer : UserRole.provider),
                  ),
                  if (provider) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Photographers, decorators, planners, cake makers, panthulu and more: get a free listing customers nearby can find.',
                      style: body(13, color: HC.muted),
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (_showApple)
                    _AuthButton(
                      label: 'Continue with Apple',
                      icon: const Icon(Icons.apple, color: Colors.white),
                      dark: true,
                      onTap: busy ? null : () => _run((a) => a.appleSignIn()),
                    ),
                  if (_showGoogle)
                    _AuthButton(
                      label: 'Continue with Google',
                      icon: Text('G', style: display(18, color: const Color(0xFF4285F4))),
                      onTap: busy ? null : () => _run((a) => a.googleSignIn()),
                    ),
                  if (_showApple || _showGoogle)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          const Expanded(child: Divider(color: HC.line)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('or with email', style: body(12, color: HC.muted)),
                          ),
                          const Expanded(child: Divider(color: HC.line)),
                        ],
                      ),
                    ),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    autofillHints: [creating ? AutofillHints.newPassword : AutofillHints.password],
                    decoration: InputDecoration(labelText: creating ? 'Create a password (6+ characters)' : 'Password'),
                    onSubmitted: (_) => _email(),
                  ),
                  if (_askForCode) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: refCtrl,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Friend\'s invite code (optional)',
                        helperText: 'You both get 1 week of Pro free',
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: body(13, color: const Color(0xFFB42318), weight: FontWeight.w500)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: HC.violet,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: busy ? null : _email,
                      child: busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(creating ? 'Create account' : 'Sign in', style: display(17, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: busy ? null : () => setState(() {
                      creating = !creating;
                      error = null;
                    }),
                    child: Text(creating ? 'Have an account? Sign in' : 'New here? Create an account'),
                  ),
                  if (!creating) TextButton(onPressed: busy ? null : _forgot, child: const Text('Forgot password?')),
                  const SizedBox(height: 8),
                  Text('You can delete your account anytime from Account.', textAlign: TextAlign.center, style: body(12, color: HC.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({required this.label, required this.icon, required this.onTap, this.dark = false});
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: 52,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: dark ? Colors.black : HC.card,
            side: BorderSide(color: dark ? Colors.black : HC.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(label, style: body(15, weight: FontWeight.w600, color: dark ? Colors.white : HC.ink)),
            ],
          ),
        ),
      ),
    );
  }
}
