import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/event_details.dart';
import '../services/invite_service.dart';
import '../services/plan_generator.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'sign_in_screen.dart';

/// Invite guests: share the invite anywhere (WhatsApp groups, iMessage, ...), pick contacts
/// or type numbers and emails, send in bulk, and see who's coming.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  Future<String>? publishing;
  Future<List<Rsvp>>? replies;
  late final TextEditingController messageCtrl;
  final _shareKey = GlobalKey();

  bool get _canPickContacts => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    messageCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (publishing == null && state.isSignedIn && state.event != null) {
      messageCtrl.text = state.event!.inviteMessage.isNotEmpty ? state.event!.inviteMessage : _defaultMessage(state.event!);
      _publish(state);
    }
  }

  @override
  void dispose() {
    messageCtrl.dispose();
    super.dispose();
  }

  static String _defaultMessage(EventDetails e) => switch (e.occasion) {
        'Birthday' => 'Come celebrate with us! Cake, games and lots of fun. 🎂',
        'Housewarming' => 'We\'ve moved in! Join us to bless our new home. 🏡',
        'Baby shower' => 'A little one is on the way! Celebrate with us. 🍼',
        'Pooja' => 'Please join us for the pooja and prasadam. 🙏',
        'Anniversary' => 'Celebrate this special day with us. 💍',
        _ => 'We\'d love to see you there! 🎉',
      };

  String _hostName(AppState s) {
    final n = (s.profile?['name'] as String?)?.trim();
    if (n != null && n.isNotEmpty) return n;
    final d = s.accounts?.user?.displayName?.trim();
    if (d != null && d.isNotEmpty) return d;
    return (s.email ?? 'Your host').split('@').first;
  }

  void _publish(AppState state) {
    final e = state.event!;
    setState(() {
      publishing = InviteService.publish(e, hostName: _hostName(state), message: messageCtrl.text);
      replies = publishing!.then(InviteService.rsvps);
    });
  }

  Future<void> _saveMessage() async {
    final state = AppScope.of(context);
    await state.update((e) => e.inviteMessage = messageCtrl.text.trim());
    _publish(state);
    if (mounted) toast(context, 'Invite updated. Guests see the new note.');
  }

  String _text(AppState state, String id) => inviteText(state.event!, inviteUrl(id), hostName: _hostName(state), message: messageCtrl.text);

  Future<void> _shareAnywhere(AppState state, String id) async {
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    try {
      // ignore: deprecated_member_use
      await Share.share(
        _text(state, id),
        subject: 'You\'re invited: ${state.event!.title}',
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      await _copy(state, id);
    }
  }

  Future<void> _copy(AppState state, String id) async {
    await Clipboard.setData(ClipboardData(text: _text(state, id)));
    if (mounted) toast(context, 'Invite copied. Paste it in any chat or group.');
  }

  Future<void> _addInvitees(List<Invitee> people) async {
    if (people.isEmpty) return;
    final state = AppScope.of(context);
    var added = 0;
    await state.update((e) {
      final have = {for (final i in e.invitees) i.key};
      for (final p in people) {
        if (p.key.isEmpty || !have.add(p.key)) continue;
        e.invitees.add(p);
        added++;
      }
    });
    if (mounted) toast(context, added == 0 ? 'They\'re already on your list.' : 'Added $added to your guest list.');
  }

  Future<void> _pickContacts() async {
    try {
      if (!await FlutterContacts.requestPermission(readonly: true)) {
        if (mounted) toast(context, 'Allow Contacts for Hoopla in Settings, or type numbers instead.');
        return;
      }
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      if (!mounted) return;
      final picked = await Navigator.of(context).push<List<Invitee>>(
        MaterialPageRoute(builder: (_) => _ContactPicker(contacts: contacts)),
      );
      await _addInvitees(picked ?? const []);
    } catch (e) {
      if (mounted) toast(context, 'Couldn\'t open your contacts.');
    }
  }

  Future<void> _typeContacts() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add numbers or emails'),
        content: TextField(
          controller: ctrl,
          minLines: 4,
          maxLines: 8,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'One per line or separated by commas:\nPriya 732 555 0100\nsam@example.com',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: HC.violet), onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Add')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null) return;
    final people = parseInvitees(text);
    if (people.isEmpty && mounted) {
      toast(context, 'No phone numbers or emails found.');
      return;
    }
    await _addInvitees(people);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final e = state.event;
    return Scaffold(
      appBar: AppBar(title: const Text('Invite guests')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: e == null
              ? const SizedBox.shrink()
              : !state.isSignedIn
                  ? _signInFirst(context)
                  : FutureBuilder<String>(
                      future: publishing,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(child: Text('Couldn\'t create the invite. Check your connection.', style: body(14, color: HC.muted)));
                        }
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        return _content(context, state, e, snap.data!);
                      },
                    ),
        ),
      ),
    );
  }

  Widget _signInFirst(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💌', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text('Send invites and track RSVPs', style: display(22), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Sign in free so guests\' replies come back to you.', style: body(14, color: HC.muted), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HC.violet, minimumSize: const Size(220, 50)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
              builder: (_) => const SignInScreen(reason: 'Sign in free to send invites and see who\'s coming.'),
            )),
            child: const Text('Sign in free'),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, AppState state, EventDetails e, String id) {
    final phones = [for (final i in e.invitees) if (i.phoneDigits.isNotEmpty) i.phoneDigits];
    final emails = [for (final i in e.invitees) if (i.email.isNotEmpty) i.email];
    final text = _text(state, id);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // ---- the invite
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [HC.ink, Color(0xFF3B2C8F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOU\'RE INVITED', style: overline(color: HC.lime)),
              const SizedBox(height: 6),
              Text(e.title, style: display(24, color: Colors.white)),
              const SizedBox(height: 6),
              Text(
                '${DateFormat('EEE, MMM d').format(e.date)} · ${clockAmPm(e.startMinutes)}'
                '${e.venue == null ? '' : '\n${e.venue!.address.isNotEmpty ? e.venue!.address : e.venue!.label}'}',
                style: body(14, color: HC.nightMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: messageCtrl,
          maxLines: 3,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Note on the invite',
            suffixIcon: IconButton(tooltip: 'Save note', onPressed: _saveMessage, icon: const Icon(Icons.check_rounded)),
          ),
          onEditingComplete: _saveMessage,
        ),
        const SizedBox(height: 4),
        Text('Guests open the link, see this card and reply Going / Maybe / Can\'t go. No app needed.', style: body(12, color: HC.muted)),

        // ---- send to everyone
        const SizedBox(height: 22),
        Text('Send to everyone', style: display(18)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            _SendTile(key: _shareKey, emoji: '📤', label: 'Share…', sub: 'Any app or group', onTap: () => _shareAnywhere(state, id)),
            _SendTile(
              emoji: '💬',
              label: 'WhatsApp',
              sub: 'Pick chats or groups',
              onTap: () => openLink(context, Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}')),
            ),
            _SendTile(
              emoji: '✉️',
              label: 'Text',
              sub: phones.isEmpty ? 'iMessage / SMS' : 'All ${phones.length} numbers',
              onTap: () => openLink(context, InviteService.smsTo(phones, text)),
            ),
            _SendTile(
              emoji: '📧',
              label: 'Email',
              sub: emails.isEmpty ? 'Any email' : 'All ${emails.length} (BCC)',
              onTap: () => openLink(context, InviteService.emailTo(emails, 'You\'re invited: ${e.title}', text)),
            ),
            _SendTile(emoji: '🔗', label: 'Copy', sub: 'Invite + link', onTap: () => _copy(state, id)),
            _SendTile(
              emoji: '👀',
              label: 'Preview',
              sub: 'What guests see',
              onTap: () => openLink(context, Uri.parse(inviteUrl(id))),
            ),
          ],
        ),

        // ---- guest list
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Text('Guest list (${e.invitees.length})', style: display(18))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (_canPickContacts) ...[
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), side: const BorderSide(color: HC.line)),
                  onPressed: _pickContacts,
                  icon: const Icon(Icons.contacts_rounded, size: 18, color: HC.violet),
                  label: Text('Pick contacts', style: body(14, weight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), side: const BorderSide(color: HC.line)),
                onPressed: _typeContacts,
                icon: const Icon(Icons.keyboard_rounded, size: 18, color: HC.violet),
                label: Text('Type numbers / emails', style: body(14, weight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        if (e.invitees.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Add people here to text or email them all at once, or just use Share… for WhatsApp groups.', style: body(13, color: HC.muted)),
          )
        else ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: HC.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: HC.line)),
            child: Column(
              children: [
                for (var i = 0; i < e.invitees.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: HC.line),
                  _InviteeRow(
                    person: e.invitees[i],
                    text: text,
                    onRemove: () => state.update((ev) => ev.invitees.removeWhere((x) => x.key == e.invitees[i].key)),
                  ),
                ],
              ],
            ),
          ),
        ],

        // ---- RSVPs
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Text('Who\'s coming', style: display(18))),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => setState(() => replies = InviteService.rsvps(id)),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        FutureBuilder<List<Rsvp>>(
          future: replies,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)));
            }
            final list = snap.data ?? const <Rsvp>[];
            final sum = RsvpSummary.of(list);
            final waiting = (e.invitees.length - sum.replies).clamp(0, 9999);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _Stat(value: '${sum.people}', label: 'coming (${sum.adults} adults, ${sum.kids} kids)', color: HC.lime)),
                    const SizedBox(width: 8),
                    Expanded(child: _Stat(value: '${sum.maybe}', label: 'maybe')),
                    const SizedBox(width: 8),
                    Expanded(child: _Stat(value: '${sum.no}', label: 'can\'t go')),
                    if (e.invitees.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(child: _Stat(value: '$waiting', label: 'no reply yet')),
                    ],
                  ],
                ),
                if (sum.people > 0 && sum.people != e.guests) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await state.update((ev) => ev.guests = sum.people);
                      if (context.mounted) toast(context, 'Guest count set to ${sum.people}. Your plan and budget use it now.');
                    },
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: Text('Use ${sum.people} as my guest count (now ${e.guests})'),
                  ),
                ],
                const SizedBox(height: 10),
                if (list.isEmpty)
                  Text('No replies yet. They show up here as guests RSVP.', style: body(13, color: HC.muted))
                else
                  for (final r in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CardBox(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.status.emoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.name, style: body(15, weight: FontWeight.w600)),
                                  Text(
                                    r.status == RsvpStatus.no
                                        ? r.status.label
                                        : '${r.status.label} · ${r.adults} adult${r.adults == 1 ? '' : 's'}${r.kids > 0 ? ', ${r.kids} kid${r.kids == 1 ? '' : 's'}' : ''}',
                                    style: body(12, color: HC.muted),
                                  ),
                                  if (r.note.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('"${r.note}"', style: body(13)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SendTile extends StatelessWidget {
  const _SendTile({super.key, required this.emoji, required this.label, required this.sub, required this.onTap});
  final String emoji;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HC.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: HC.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(label, style: body(14, weight: FontWeight.w700)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: body(11, color: HC.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteeRow extends StatelessWidget {
  const _InviteeRow({required this.person, required this.text, required this.onRemove});
  final Invitee person;
  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = person;
    final digits = p.phoneDigits.replaceAll('+', '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      child: Row(
        children: [
          CircleAvatar(radius: 18, backgroundColor: HC.track, child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase(), style: body(14, weight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w600)),
                Text([p.phone, p.email].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: HC.muted)),
              ],
            ),
          ),
          if (digits.isNotEmpty)
            IconButton(
              tooltip: 'WhatsApp ${p.name}',
              onPressed: () => openLink(context, Uri.https('wa.me', '/$digits', {'text': text})),
              icon: const Icon(Icons.chat_rounded, size: 20, color: Color(0xFF1FA855)),
            ),
          if (p.phoneDigits.isNotEmpty)
            IconButton(
              tooltip: 'Text ${p.name}',
              onPressed: () => openLink(context, InviteService.smsTo([p.phoneDigits], text)),
              icon: const Icon(Icons.sms_outlined, size: 20, color: HC.violet),
            ),
          if (p.email.isNotEmpty)
            IconButton(
              tooltip: 'Email ${p.name}',
              onPressed: () => openLink(context, InviteService.emailTo([p.email], 'You\'re invited!', text)),
              icon: const Icon(Icons.mail_outline_rounded, size: 20, color: HC.violet),
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: HC.muted),
            onSelected: (_) => onRemove(),
            itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove from list'))],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color = HC.card});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      color: color,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: display(24)),
          Text(label, maxLines: 2, style: body(11, color: HC.ink)),
        ],
      ),
    );
  }
}

/// Multi-select list of phone contacts with search.
class _ContactPicker extends StatefulWidget {
  const _ContactPicker({required this.contacts});
  final List<Contact> contacts;

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  String query = '';
  final selected = <String>{};

  List<Contact> get _usable =>
      [for (final c in widget.contacts) if (c.phones.isNotEmpty || c.emails.isNotEmpty) c]..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final list = [
      for (final c in _usable)
        if (q.isEmpty || c.displayName.toLowerCase().contains(q) || c.phones.any((p) => p.number.contains(q))) c,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(selected.isEmpty ? 'Pick contacts' : '${selected.length} selected'),
        actions: [
          TextButton(
            onPressed: selected.isEmpty
                ? null
                : () {
                    final out = <Invitee>[
                      for (final c in _usable)
                        if (selected.contains(c.id))
                          Invitee(
                            name: c.displayName,
                            phone: c.phones.isEmpty ? '' : c.phones.first.number,
                            email: c.emails.isEmpty ? '' : c.emails.first.address,
                          ),
                    ];
                    Navigator.pop(context, out);
                  },
            child: const Text('Add'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search contacts'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final c = list[i];
                final on = selected.contains(c.id);
                return CheckboxListTile(
                  value: on,
                  activeColor: HC.violet,
                  onChanged: (v) => setState(() => v == true ? selected.add(c.id) : selected.remove(c.id)),
                  title: Text(c.displayName),
                  subtitle: Text(c.phones.isNotEmpty ? c.phones.first.number : c.emails.first.address),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
