import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/referrals.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'sign_in_screen.dart';

/// Refer a friend: share your code; when a friend joins with it you both get
/// a week of Pro free. Also where you type a friend's code.
class ReferScreen extends StatefulWidget {
  const ReferScreen({super.key});

  @override
  State<ReferScreen> createState() => _ReferScreenState();
}

class _ReferScreenState extends State<ReferScreen> {
  String? code;
  String? codeError;
  bool loadingCode = false;
  final friendCtrl = TextEditingController();
  bool redeeming = false;
  String? redeemError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.of(context);
      friendCtrl.text = state.pendingRefCode ?? '';
      _loadCode();
    });
  }

  @override
  void dispose() {
    friendCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCode() async {
    final state = AppScope.of(context);
    if (!state.isSignedIn) return;
    setState(() {
      loadingCode = true;
      codeError = null;
    });
    try {
      final c = await state.ensureRefCode();
      if (mounted) setState(() => code = c);
    } catch (e) {
      if (mounted) setState(() => codeError = '$e');
    } finally {
      if (mounted) setState(() => loadingCode = false);
    }
  }

  Future<void> _signIn() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SignInScreen(reason: 'Sign in free to get your invite code and your free week of Pro.')),
    );
    if (ok == true && mounted) {
      final notice = AppScope.of(context).takeReferralNotice();
      if (notice != null) toast(context, notice);
      _loadCode();
    }
  }

  Future<void> _redeem() async {
    final state = AppScope.of(context);
    final c = normalizeCode(friendCtrl.text);
    if (c == null) {
      setState(() => redeemError = 'Codes are 6 letters and numbers, like K7Q2MX.');
      return;
    }
    if (!state.isSignedIn) {
      // Keep it and apply it right after sign-in.
      await state.setPendingRefCode(c);
      if (mounted) await _signIn();
      return;
    }
    setState(() {
      redeeming = true;
      redeemError = null;
    });
    final err = await state.redeemCode(c);
    if (!mounted) return;
    setState(() {
      redeeming = false;
      redeemError = err;
    });
    if (err == null) {
      friendCtrl.clear();
      await state.setPendingRefCode(null);
      if (mounted) toast(context, 'Code applied! You both get 1 week of Pro free. 🎉');
    }
  }

  void _copy(String c) {
    Clipboard.setData(ClipboardData(text: inviteMessage(c)));
    toast(context, 'Invite copied. Paste it anywhere!');
  }

  void _whatsApp(String c) =>
      openLink(context, Uri.parse('https://wa.me/?text=${Uri.encodeComponent(inviteMessage(c))}'));

  void _sms(String c) {
    final text = Uri.encodeComponent(inviteMessage(c));
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    openLink(context, Uri.parse(ios ? 'sms:&body=$text' : 'sms:?body=$text'));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final r = state.referral;
    final until = state.bonusProUntil;
    return Scaffold(
      appBar: AppBar(title: const Text('Refer a friend')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const Text('🎁', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 6),
              Text('Give a week of Pro,\nget a week of Pro', style: display(26)),
              const SizedBox(height: 8),
              Text(
                'When a friend joins Hoopla with your code, you both get 1 week of Pro free: '
                'enough to plan a whole party with helpers nearby and invites. Every friend adds another week.',
                style: body(14, color: HC.muted),
              ),
              const SizedBox(height: 20),
              if (!state.usingCloud)
                Text('Invites turn on once Hoopla is connected to the internet.', style: body(14, color: HC.muted))
              else if (!state.isSignedIn)
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: HC.violet,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _signIn,
                    child: Text('Sign in to get your code', style: display(16, color: Colors.white)),
                  ),
                )
              else
                _codeCard(),
              if (state.isSignedIn) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _Stat(value: '${r.friendsJoined}', label: r.friendsJoined == 1 ? 'friend joined' : 'friends joined')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Stat(
                        value: state.onReferralBonus ? DateFormat('MMM d').format(until!) : '—',
                        label: state.onReferralBonus ? 'Pro free until' : 'no free Pro yet',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const SectionLabel('How it works'),
              const _Step(n: '1', text: 'Share your code or link with friends planning a party.'),
              const _Step(n: '2', text: 'They download Hoopla, sign up, and enter your code.'),
              const _Step(n: '3', text: 'You both get 1 week of Pro free, right away. No card needed.'),
              if (r.usedCode == null && state.usingCloud) ...[
                const SizedBox(height: 20),
                const SectionLabel('Have a friend\'s code?'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: friendCtrl,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        maxLength: 8,
                        decoration: InputDecoration(hintText: 'e.g. K7Q2MX', errorText: redeemError, counterText: ''),
                        onSubmitted: (_) => _redeem(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: HC.ink,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: redeeming ? null : _redeem,
                        child: redeeming
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ] else if (r.usedCode != null) ...[
                const SizedBox(height: 16),
                Text('You joined with code ${r.usedCode}. Thanks for coming!', style: body(13, color: HC.muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _codeCard() {
    final c = code;
    return CardBox(
      color: HC.ink,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('YOUR CODE', style: overline(color: HC.nightMuted)),
          const SizedBox(height: 6),
          if (loadingCode)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator(color: HC.lime)),
            )
          else if (c == null)
            Row(
              children: [
                Expanded(child: Text(codeError ?? 'No code yet.', style: body(14, color: Colors.white))),
                TextButton(onPressed: _loadCode, child: const Text('Try again', style: TextStyle(color: HC.lime))),
              ],
            )
          else ...[
            SelectableText(c, style: display(36, color: HC.lime).copyWith(letterSpacing: 6)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ShareButton(icon: Icons.copy_rounded, label: 'Copy invite', onTap: () => _copy(c)),
                _ShareButton(icon: Icons.chat_rounded, label: 'WhatsApp', onTap: () => _whatsApp(c)),
                if (!kIsWeb) _ShareButton(icon: Icons.sms_outlined, label: 'Text', onTap: () => _sms(c)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: HC.lime,
        foregroundColor: HC.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: body(14, weight: FontWeight.w600)),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: display(22)),
          const SizedBox(height: 2),
          Text(label, style: body(12, color: HC.muted)),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: HC.violet, shape: BoxShape.circle),
            child: Text(n, style: body(13, color: Colors.white, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: body(14))),
        ],
      ),
    );
  }
}
