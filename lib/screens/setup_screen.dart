import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_details.dart';
import '../services/plan_generator.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// "Tell us about your event" — used to create a new event or edit one.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.existing});

  /// When set, the screen edits this event instead of creating a new one.
  final EventDetails? existing;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late String occasion;
  late final TextEditingController titleCtrl;
  late DateTime date;
  late int startMinutes;
  late int hours;
  late bool indoor;
  late int guests;
  late Audience audience;
  late int energy;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    occasion = e?.occasion ?? occasions.first;
    titleCtrl = TextEditingController(text: e?.title ?? '');
    date = e?.date ?? DateTime.now().add(const Duration(days: 30));
    startMinutes = e?.startMinutes ?? 16 * 60;
    hours = e?.hours ?? 3;
    indoor = e?.indoor ?? true;
    guests = e?.guests ?? 30;
    audience = e?.audience ?? Audience.kids;
    energy = e?.energy ?? 1;
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date.isBefore(now) ? now : date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60),
    );
    if (picked != null) setState(() => startMinutes = picked.hour * 60 + picked.minute);
  }

  Future<void> _save() async {
    setState(() => saving = true);
    final state = AppScope.of(context);
    final previous = state.event;
    final title = titleCtrl.text.trim().isEmpty ? '$occasion party' : titleCtrl.text.trim();
    final e = widget.existing ??
        EventDetails(
          id: EventDetails.newId(),
          occasion: occasion,
          title: title,
          date: date,
          startMinutes: startMinutes,
          hours: hours,
          indoor: indoor,
          guests: guests,
          audience: audience,
          energy: energy,
          // Saved reels carry over to the next party.
          savedLinks: previous == null ? null : List.of(previous.savedLinks),
        );
    e
      ..occasion = occasion
      ..title = title
      ..date = date
      ..startMinutes = startMinutes
      ..hours = hours
      ..indoor = indoor
      ..guests = guests
      ..audience = audience
      ..energy = energy;
    e.gameIds = PlanGenerator.suggestGameIds(e);
    await state.saveEvent(e);
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        )
                      else
                        const _Logo(),
                      const Spacer(),
                      if (!Navigator.of(context).canPop())
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: HC.card, shape: BoxShape.circle, border: Border.all(color: HC.line)),
                          child: const Icon(Icons.person_outline_rounded, color: HC.ink),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    children: [
                      Text(editing ? 'Update your party' : 'Throw a party.\nWe\'ll bring the fun.', style: display(32)),
                      const SizedBox(height: 8),
                      Text('Tell us a little about it — we plan the games, timeline and helpers.', style: body(14, color: HC.muted)),
                      const SizedBox(height: 22),
                      const SectionLabel("What's the occasion?"),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final o in occasions) Pill(label: o, selected: o == occasion, onTap: () => setState(() => occasion = o)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel("Who's it for?"),
                      TextField(
                        controller: titleCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        style: body(15, weight: FontWeight.w500),
                        decoration: const InputDecoration(hintText: "e.g. Aarav's 1st birthday"),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _InfoTile(label: 'Date', value: DateFormat('EEE, MMM d').format(date), onTap: _pickDate)),
                          const SizedBox(width: 10),
                          Expanded(child: _InfoTile(label: 'Start time', value: clockAmPm(startMinutes), onTap: _pickTime)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel('How long?'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final h in [2, 3, 4, 5]) Pill(label: '$h hrs', selected: h == hours, onTap: () => setState(() => hours = h)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel('Where?'),
                      Segmented(options: const ['Indoor', 'Outdoor'], selected: indoor ? 0 : 1, onChanged: (i) => setState(() => indoor = i == 0)),
                      const SizedBox(height: 20),
                      const SectionLabel('Who\'s coming?'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final a in Audience.values) Pill(label: a.label, selected: a == audience, onTap: () => setState(() => audience = a)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CardBox(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Guests', style: body(12, color: HC.muted)),
                                  Text.rich(TextSpan(children: [
                                    TextSpan(text: '$guests ', style: display(28)),
                                    TextSpan(text: 'people', style: body(14, color: HC.muted, weight: FontWeight.w500)),
                                  ])),
                                ],
                              ),
                            ),
                            _StepButton(icon: Icons.remove_rounded, label: 'Fewer guests', dark: false, onTap: () => setState(() => guests = (guests - 5).clamp(2, 1000).toInt())),
                            const SizedBox(width: 8),
                            _StepButton(icon: Icons.add_rounded, label: 'More guests', dark: true, onTap: () => setState(() => guests = (guests + 5).clamp(2, 1000).toInt())),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SectionLabel('Party energy'),
                      Segmented(options: energyLevels, selected: energy, height: 40, onChanged: (i) => setState(() => energy = i)),
                      const SizedBox(height: 8),
                      Text(_energyLine(energy), style: body(13, color: HC.muted)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: HC.violet,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: saving ? null : _save,
                      icon: const Icon(Icons.auto_awesome_rounded, color: HC.lime),
                      label: Text(editing ? 'Update my plan' : 'Plan my party', style: display(18, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _energyLine(int e) => const [
        'Relaxed games and good conversation.',
        'Plenty of laughs, nothing gets knocked over.',
        'Music up, games on — the neighbors will hear.',
        'Full energy. Someone may end up with cake on their face.',
      ][e];
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: HC.ink, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.celebration_outlined, color: HC.lime, size: 20),
        ),
        const SizedBox(width: 10),
        Text('Hoopla', style: display(22)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardBox(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: body(12, color: HC.muted)),
          const SizedBox(height: 2),
          Text(value, style: body(15, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.dark, required this.onTap});
  final IconData icon;
  final String label;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? HC.ink : HC.ground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: dark ? BorderSide.none : const BorderSide(color: HC.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Tooltip(
          message: label,
          child: SizedBox(width: 46, height: 46, child: Icon(icon, color: dark ? Colors.white : HC.ink)),
        ),
      ),
    );
  }
}
