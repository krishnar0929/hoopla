import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/invite_service.dart';
import '../theme.dart';
import '../widgets/celebration.dart';
import '../widgets/common.dart';

/// What a guest sees when they open an invite link
/// (https://hoopla-894ca.web.app/?invite=...): the invite card and an RSVP form.
/// No app or account needed.
class RsvpScreen extends StatefulWidget {
  const RsvpScreen({super.key, required this.inviteId, this.onPlanOwn});
  final String inviteId;

  /// "Plan your own party with Hoopla".
  final VoidCallback? onPlanOwn;

  @override
  State<RsvpScreen> createState() => _RsvpScreenState();
}

class _RsvpScreenState extends State<RsvpScreen> {
  late final Future<InviteInfo?> future = InviteService.load(widget.inviteId);
  final nameCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  RsvpStatus? status;
  int adults = 1;
  int kids = 0;
  bool busy = false;
  bool sent = false;
  String? error;
  static const _nameKey = 'hoopla.rsvpName';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prev = await InviteService.mine(widget.inviteId);
    String? savedName;
    try {
      savedName = (await SharedPreferences.getInstance()).getString(_nameKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      if (prev != null) {
        nameCtrl.text = prev.name;
        noteCtrl.text = prev.note;
        status = prev.status;
        adults = prev.adults == 0 ? 1 : prev.adults;
        kids = prev.kids;
        sent = true;
      } else if (savedName != null) {
        nameCtrl.text = savedName;
      }
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(InviteInfo info) async {
    final s = status;
    if (nameCtrl.text.trim().isEmpty) {
      setState(() => error = 'Please add your name so ${info.hostName} knows who\'s coming.');
      return;
    }
    if (s == null) {
      setState(() => error = 'Tap Going, Maybe or Can\'t go.');
      return;
    }
    final overlay = Celebration.overlayOf(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await InviteService.reply(info.id, name: nameCtrl.text, status: s, adults: adults, kids: kids, note: noteCtrl.text);
      try {
        await (await SharedPreferences.getInstance()).setString(_nameKey, nameCtrl.text.trim());
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        busy = false;
        sent = true;
      });
      if (s == RsvpStatus.going) {
        Celebration.show(overlay, title: 'See you there!', message: '${info.hostName} will be thrilled. 🎉', emoji: '🥳');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Couldn\'t send your reply. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<InviteInfo?>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final info = snap.data;
          if (info == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎈', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    Text('This invite isn\'t available', style: display(22)),
                    const SizedBox(height: 6),
                    Text('Ask your host to send the link again.', style: body(14, color: HC.muted)),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  _InviteCard(info: info),
                  const SizedBox(height: 18),
                  if (sent && status != null) ...[
                    CardBox(
                      color: HC.lime,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${status!.emoji}  You replied: ${status!.label}', style: display(18)),
                          if (status != RsvpStatus.no) Text('$adults adult${adults == 1 ? '' : 's'}${kids > 0 ? ', $kids kid${kids == 1 ? '' : 's'}' : ''}', style: body(14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (status != RsvpStatus.no)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: HC.ink),
                                  onPressed: () => openLink(context, info.googleCalendarUrl),
                                  icon: const Icon(Icons.event_rounded, size: 18),
                                  label: const Text('Add to calendar'),
                                ),
                              OutlinedButton(onPressed: () => setState(() => sent = false), child: const Text('Change my reply')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text('Will you come?', style: display(22)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Your name'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final s in RsvpStatus.values) ...[
                          Expanded(
                            child: _Choice(
                              label: s.label,
                              emoji: s.emoji,
                              selected: status == s,
                              onTap: () => setState(() => status = s),
                            ),
                          ),
                          if (s != RsvpStatus.no) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    if (status != null && status != RsvpStatus.no) ...[
                      const SizedBox(height: 14),
                      _Counter(label: 'Adults', value: adults, min: 1, onChanged: (v) => setState(() => adults = v)),
                      const SizedBox(height: 8),
                      _Counter(label: 'Kids', value: kids, min: 0, onChanged: (v) => setState(() => kids = v)),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLength: 300,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Note for the host (optional)', hintText: 'Allergies, running late, can\'t wait!'),
                    ),
                    if (error != null) Text(error!, style: body(13, color: const Color(0xFFB42318), weight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: HC.violet, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                        onPressed: busy ? null : () => _send(info),
                        child: busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text('Send my reply', style: display(17, color: Colors.white)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Center(
                    child: TextButton(
                      onPressed: widget.onPlanOwn,
                      child: const Text('🎈 Planning a party too? Plan it free with Hoopla'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.info});
  final InviteInfo info;

  @override
  Widget build(BuildContext context) {
    final map = info.mapUrl;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [HC.ink, Color(0xFF3B2C8F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOU\'RE INVITED', style: overline(color: HC.lime)),
          const SizedBox(height: 8),
          Text(info.title, style: display(30, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Hosted by ${info.hostName}', style: body(14, color: HC.nightMuted)),
          const SizedBox(height: 18),
          _Line(icon: Icons.event_rounded, text: info.whenLabel),
          if (info.venue.isNotEmpty || info.venueAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: map == null ? null : () => openLink(context, map),
              child: _Line(icon: Icons.place_rounded, text: info.venueAddress.isNotEmpty ? info.venueAddress : info.venue, link: map != null),
            ),
          ],
          if (info.message.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0x1FFFFFFF), borderRadius: BorderRadius.circular(16)),
              child: Text(info.message, style: body(14, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.link = false});
  final IconData icon;
  final String text;
  final bool link;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: HC.lime, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: body(15, color: Colors.white, weight: FontWeight.w600).copyWith(decoration: link ? TextDecoration.underline : null, decorationColor: Colors.white54)),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.emoji, required this.selected, required this.onTap});
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HC.ink : HC.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: selected ? HC.ink : HC.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(label, style: body(14, weight: FontWeight.w600, color: selected ? Colors.white : HC.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.min, required this.onChanged});
  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: body(15, weight: FontWeight.w600))),
          IconButton(onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
          SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center, style: display(18))),
          IconButton(onPressed: value < 50 ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add_circle_outline_rounded, color: HC.violet)),
        ],
      ),
    );
  }
}
