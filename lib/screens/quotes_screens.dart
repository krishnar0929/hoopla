import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/provider_profile.dart';
import '../services/quote_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/celebration.dart';
import '../widgets/common.dart';
import '../widgets/gallery.dart';
import 'sign_in_screen.dart';

// ============================================================ customer side

/// "Request a quote": the event details go to the provider inside Hoopla.
/// Needs a free account so the provider can reply.
Future<void> requestQuote(BuildContext context, ProviderProfile provider) async {
  if (provider.isSample) {
    toast(context, sampleContactNote);
    return;
  }
  final state = AppScope.of(context);
  if (state.event == null) {
    toast(context, 'Plan your event first, then ask for quotes.');
    return;
  }
  if (!state.usingCloud) {
    toast(context, 'Quote requests need an internet connection.');
    return;
  }
  if (!state.isSignedIn) {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SignInScreen(reason: 'Sign in free so providers can reply to your quote request.')),
    );
    if (ok != true || !context.mounted) return;
  }
  if (state.isProvider && state.provider?.uid == provider.uid) {
    toast(context, 'That\'s your own listing.');
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: HC.ground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _RequestSheet(provider: provider, state: state),
  );
}

class _RequestSheet extends StatefulWidget {
  const _RequestSheet({required this.provider, required this.state});
  final ProviderProfile provider;
  final AppState state;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  late final TextEditingController messageCtrl;
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final state = widget.state;
    messageCtrl = TextEditingController(text: defaultQuoteMessage(state.event!, widget.provider));
    final profile = state.profile;
    nameCtrl = TextEditingController(text: (profile?['name'] as String?) ?? state.accounts?.user?.displayName ?? '');
    phoneCtrl = TextEditingController(text: (profile?['phone'] as String?) ?? '');
  }

  @override
  void dispose() {
    messageCtrl.dispose();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final state = AppScope.of(context);
    if (messageCtrl.text.trim().isEmpty) {
      setState(() => error = 'Write a short message.');
      return;
    }
    final nav = Navigator.of(context);
    final overlay = Celebration.overlayOf(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final sent = await QuoteService.send(
        event: state.event!,
        provider: widget.provider,
        message: messageCtrl.text,
        name: nameCtrl.text,
        phone: phoneCtrl.text,
      );
      nav.pop();
      if (sent) {
        Celebration.show(
          overlay,
          title: 'Quote request sent!',
          message: '${widget.provider.businessName} will reply in Hoopla${phoneCtrl.text.trim().isEmpty ? '' : ' or contact you'}. '
              'Track it under "Your quote requests" in Nearby.',
          emoji: '📨',
        );
      } else {
        messenger.showSnackBar(SnackBar(content: Text('You already asked ${widget.provider.businessName} for this event. See "Your quote requests".')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not send. Please try again. ($e)';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final e = state.event!;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Request a quote', style: display(24)),
              const SizedBox(height: 4),
              Text('From ${widget.provider.businessName} · free', style: body(13, color: HC.muted)),
              const SizedBox(height: 14),
              CardBox(
                radius: 14,
                color: HC.track,
                padding: const EdgeInsets.all(12),
                child: Text(
                  '${e.title}\n${DateFormat('EEE, MMM d').format(e.date)} · ${e.guests} guests · ${e.indoor ? 'indoor' : 'outdoor'}',
                  style: body(13, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                minLines: 4,
                maxLines: 8,
                maxLength: 1500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone / WhatsApp (optional)',
                  helperText: 'Only shared with this provider, so they can call or WhatsApp you.',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: body(13, color: const Color(0xFFB42318), weight: FontWeight.w500)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: HC.violet,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: busy ? null : _send,
                  child: busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text('Send request', style: display(16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Link at the top of Nearby: "Your quote requests (2 replied)".
class MyQuotesLink extends StatefulWidget {
  const MyQuotesLink({super.key});

  @override
  State<MyQuotesLink> createState() => _MyQuotesLinkState();
}

class _MyQuotesLinkState extends State<MyQuotesLink> {
  Future<List<QuoteRequest>>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= QuoteService.mine().catchError((_) => <QuoteRequest>[]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QuoteRequest>>(
      future: future,
      builder: (context, snap) {
        final list = snap.data ?? const <QuoteRequest>[];
        if (list.isEmpty) return const SizedBox.shrink();
        final replied = list.where((q) => q.status == QuoteStatus.replied).length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CardBox(
            color: replied > 0 ? HC.lime : HC.card,
            padding: const EdgeInsets.all(14),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MyQuotesScreen()));
              if (mounted) setState(() => future = QuoteService.mine().catchError((_) => <QuoteRequest>[]));
            },
            child: Row(
              children: [
                const Text('📨', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your quote requests (${list.length})${replied > 0 ? ' · $replied new repl${replied == 1 ? 'y' : 'ies'}' : ''}',
                    style: body(14, weight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MyQuotesScreen extends StatefulWidget {
  const MyQuotesScreen({super.key});

  @override
  State<MyQuotesScreen> createState() => _MyQuotesScreenState();
}

class _MyQuotesScreenState extends State<MyQuotesScreen> {
  late Future<List<QuoteRequest>> future = QuoteService.mine();

  Future<void> _cancel(QuoteRequest q) async {
    try {
      await QuoteService.cancel(q);
      setState(() => future = QuoteService.mine());
    } catch (e) {
      if (mounted) toast(context, 'Could not cancel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your quote requests')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: FutureBuilder<List<QuoteRequest>>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) return Center(child: Text('Could not load your requests.', style: body(14, color: HC.muted)));
              final list = snap.data!;
              if (list.isEmpty) {
                return Center(child: Text('No requests yet. Ask providers in Nearby.', style: body(14, color: HC.muted)));
              }
              return RefreshIndicator(
                onRefresh: () async => setState(() => future = QuoteService.mine()),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    for (final q in list)
                      _QuoteTile(
                        title: q.providerName,
                        subtitle: '${q.serviceType} · for ${q.eventTitle}',
                        q: q,
                        replyLabel: 'Reply from ${q.providerName}',
                        actions: [
                          if (q.status.isOpen) TextButton(onPressed: () => _cancel(q), child: const Text('Cancel request')),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================ provider side

/// Lead numbers on the provider's home screen, opening the inbox.
class LeadSummaryCard extends StatefulWidget {
  const LeadSummaryCard({super.key});

  @override
  State<LeadSummaryCard> createState() => _LeadSummaryCardState();
}

class _LeadSummaryCardState extends State<LeadSummaryCard> {
  late Future<LeadStats> future = QuoteService.stats();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LeadStats>(
      future: future,
      builder: (context, snap) {
        final s = snap.data ?? const LeadStats();
        final month = DateFormat('MMMM').format(DateTime.now());
        return CardBox(
          color: HC.ink,
          padding: const EdgeInsets.all(16),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LeadInboxScreen()));
            if (mounted) setState(() => future = QuoteService.stats());
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Your leads · $month', style: overline(color: HC.nightMuted))),
                  if (s.openQuotes > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: HC.lime, borderRadius: BorderRadius.circular(10)),
                      child: Text('${s.openQuotes} new', style: body(12, weight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Big(value: snap.hasData ? '${s.quotesThisMonth}' : '–', label: 'quote requests')),
                  Expanded(child: _Big(value: snap.hasData ? '${s.tapsThisMonth}' : '–', label: 'calls, WhatsApp & profile taps')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('Open your inbox', style: body(14, color: HC.lime, weight: FontWeight.w600)),
                  const Icon(Icons.chevron_right_rounded, color: HC.lime),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: display(32, color: Colors.white)),
        Text(label, style: body(12, color: HC.nightMuted)),
      ],
    );
  }
}

class LeadInboxScreen extends StatefulWidget {
  const LeadInboxScreen({super.key});

  @override
  State<LeadInboxScreen> createState() => _LeadInboxScreenState();
}

class _LeadInboxScreenState extends State<LeadInboxScreen> {
  late Future<List<QuoteRequest>> future = _load();

  Future<List<QuoteRequest>> _load() async {
    final list = await QuoteService.inbox();
    // Opening the inbox marks new requests as seen, so customers know.
    for (final q in list.where((q) => q.status == QuoteStatus.newRequest)) {
      QuoteService.respond(q, status: QuoteStatus.seen).catchError((_) {});
    }
    return list;
  }

  void _refresh() => setState(() => future = QuoteService.inbox());

  Future<void> _reply(QuoteRequest q) async {
    final ctrl = TextEditingController(text: q.reply);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reply to ${q.customerName}'),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Yes, I\'m free that day! Package is \$600 for 3 hours...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HC.violet),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Send reply'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.trim().isEmpty) return;
    await _update(q, reply: text);
  }

  Future<void> _update(QuoteRequest q, {QuoteStatus? status, String? reply}) async {
    try {
      await QuoteService.respond(q, status: status, reply: reply);
      _refresh();
    } catch (e) {
      if (mounted) toast(context, 'Could not update: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quote requests')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: FutureBuilder<List<QuoteRequest>>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) return Center(child: Text('Could not load your inbox.', style: body(14, color: HC.muted)));
              final list = snap.data!;
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No quote requests yet.\nListings with photos, prices and reviews get the most requests.',
                      textAlign: TextAlign.center,
                      style: body(14, color: HC.muted),
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    for (final q in list)
                      _QuoteTile(
                        title: q.customerName,
                        subtitle: '${q.occasion} · ${q.eventTitle}',
                        q: q,
                        replyLabel: 'Your reply',
                        actions: [
                          if (q.status != QuoteStatus.cancelled) ...[
                            if (q.phoneDigits.isNotEmpty) ...[
                              TextButton(onPressed: () => openLink(context, Uri(scheme: 'tel', path: q.phoneDigits)), child: const Text('Call')),
                              TextButton(
                                onPressed: () => openLink(context, Uri.https('wa.me', '/${q.phoneDigits}', {'text': 'Hi ${q.customerName}, this is about your quote request on Hoopla.'})),
                                child: const Text('WhatsApp'),
                              ),
                            ],
                            if (q.customerEmail.isNotEmpty)
                              TextButton(
                                onPressed: () => openLink(context, Uri(scheme: 'mailto', path: q.customerEmail, query: 'subject=${Uri.encodeComponent('Your Hoopla quote request: ${q.eventTitle}')}')),
                                child: const Text('Email'),
                              ),
                            TextButton(onPressed: () => _reply(q), child: Text(q.reply.isEmpty ? 'Reply' : 'Edit reply')),
                            if (q.status != QuoteStatus.booked)
                              TextButton(onPressed: () => _update(q, status: QuoteStatus.booked), child: const Text('Mark booked')),
                            if (q.status.isOpen)
                              TextButton(onPressed: () => _update(q, status: QuoteStatus.declined), child: const Text('Not available')),
                          ],
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================ shared

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.title, required this.subtitle, required this.q, required this.replyLabel, required this.actions});
  final String title;
  final String subtitle;
  final QuoteRequest q;
  final String replyLabel;
  final List<Widget> actions;

  Color get _statusColor => switch (q.status) {
        QuoteStatus.newRequest => HC.violet,
        QuoteStatus.seen => HC.muted,
        QuoteStatus.replied => const Color(0xFF1F8A4C),
        QuoteStatus.booked => const Color(0xFF1F8A4C),
        QuoteStatus.declined || QuoteStatus.cancelled => const Color(0xFFB42318),
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: body(15, weight: FontWeight.w600)),
                      Text(subtitle, style: body(12, color: HC.muted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(q.status.label, style: body(12, color: _statusColor, weight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(q.eventSummary, style: body(12, weight: FontWeight.w600)),
            if (q.createdAt != null) Text('Sent ${DateFormat('MMM d, h:mm a').format(q.createdAt!)}', style: body(11, color: HC.muted)),
            const SizedBox(height: 8),
            Text(q.message, style: body(14)),
            if (q.reply.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: HC.ground, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(replyLabel, style: body(12, color: HC.muted, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(q.reply, style: body(14)),
                  ],
                ),
              ),
            ],
            if (actions.isNotEmpty) Wrap(spacing: 0, children: actions),
          ],
        ),
      ),
    );
  }
}
