import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/plan_generator.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/locked.dart';
import '../widgets/reminder_ui.dart';
import 'account_sheet.dart';
import 'event_actions.dart';
import 'setup_screen.dart';

/// The generated plan: timeline, checklist and budget.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.onNavigate});

  /// Switch to another tab (1 = Nearby).
  final ValueChanged<int> onNavigate;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final e = state.event!;
    final plan = state.plan;
    final days = e.daysToGo;
    final access = state.access;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: HC.ink,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RoundIcon(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit event details',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SetupScreen(existing: e))),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: const CircleBorder(),
                    child: PopupMenuButton<String>(
                      tooltip: 'Event options',
                      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
                      onSelected: (v) {
                        switch (v) {
                          case 'new':
                            startNewEvent(context);
                          case 'events':
                            showMyEvents(context);
                          case 'cancel':
                            confirmCancelEvent(context, e);
                        }
                      },
                      itemBuilder: (_) => [
                        _menuItem('new', Icons.add_rounded, 'Start new event'),
                        _menuItem('events', Icons.event_note_outlined, 'My events (${state.events.length})'),
                        _menuItem('cancel', Icons.event_busy_outlined, 'Cancel this event', danger: true),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: HC.lime, borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      days > 1 ? '$days days to go' : days == 1 ? 'Tomorrow!' : days == 0 ? 'Today!' : 'Party done',
                      style: body(13, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RoundIcon(
                    icon: state.isSignedIn ? Icons.person_rounded : Icons.person_outline_rounded,
                    tooltip: 'Account',
                    onTap: () => showAccountSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(e.title, style: display(30, color: Colors.white)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in [
                    DateFormat('EEE, MMM d').format(e.date),
                    '${clock(e.startMinutes)}–${clockAmPm(e.startMinutes + e.hours * 60)}',
                    e.indoor ? 'Indoor' : 'Outdoor',
                    '${e.guests} guests',
                  ])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Text(t, style: body(12, color: Colors.white)),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Segmented(options: const ['Timeline', 'Checklist', 'Budget'], selected: tab, height: 40, onChanged: (i) => setState(() => tab = i)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: switch (tab) {
            0 => _Timeline(plan: plan, showOnly: access == Access.guest ? 3 : null),
            1 => access == Access.guest
                ? const LockedCard(
                    needs: Access.member,
                    title: 'Your checklist',
                    message: 'Sign in free to get a to-do list with due dates for invites, bookings and supplies.',
                  )
                : const _Checklist(),
            _ => access == Access.premium
                ? const _Budget()
                : const LockedCard(
                    needs: Access.premium,
                    title: 'Budget planner',
                    message: 'Basic and up split your budget into food, decor, photos, cake and return gifts.',
                  ),
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: CardBox(
            color: HC.lime,
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('This plan needs ${plan.helpers.length} helpers', style: body(14, weight: FontWeight.w600)),
                      Text(plan.helpers.join(' · '), style: body(12, color: const Color(0xFF2F3A10))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: HC.ink, minimumSize: const Size(0, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => widget.onNavigate(1),
                  child: Text('Find nearby', style: body(13, color: Colors.white, weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {bool danger = false}) {
  final color = danger ? const Color(0xFFB42318) : HC.ink;
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: body(14, color: color)),
      ],
    ),
  );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon, color: Colors.white, size: 20)),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.plan, this.showOnly});
  final Plan plan;

  /// Guests see only the first few steps; the rest is blurred.
  final int? showOnly;

  static Color _dot(StepKind k) => switch (k) {
        StepKind.game => HC.coral,
        StepKind.moment || StepKind.welcome => HC.violet,
        _ => HC.ink,
      };

  @override
  Widget build(BuildContext context) {
    final steps = plan.timeline;
    final limit = showOnly;
    if (limit != null && steps.length > limit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in steps.take(limit)) _row(s),
          ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.6,
                  child: Column(children: [for (final s in steps.skip(limit).take(2)) _row(s)]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          LockedCard(
            needs: Access.member,
            title: '${steps.length - limit} more steps in your plan',
            message: 'Sign in free to see the full timeline, every game and your checklist.',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in steps) _row(s),
        if (plan.backupGames.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 80, top: 4),
            child: Text('Backup games if there\'s time: ${plan.backupGames.map((g) => g.name).join(', ')}', style: body(12, color: HC.muted)),
          ),
      ],
    );
  }

  Widget _row(TimelineStep s) {
    return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 48,
                  child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(clock(s.start), style: body(12, color: HC.muted, weight: FontWeight.w600))),
                ),
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: _dot(s.kind), borderRadius: BorderRadius.circular(3))),
                      Expanded(child: Container(width: 2, color: HC.line)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CardBox(
                      radius: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title, style: body(14, weight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(s.subtitle, style: body(12, color: HC.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final e = state.event!;
    final tasks = state.plan.tasks;
    final fmt = DateFormat('MMM d');
    return Column(
      children: [
        const RemindersCard(),
        for (final t in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CardBox(
              radius: 14,
              padding: const EdgeInsets.fromLTRB(4, 2, 14, 2),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: HC.violet,
                value: e.doneTasks.contains(t.id),
                onChanged: (v) => state.update((ev) {
                  if (v == true) {
                    ev.doneTasks.add(t.id);
                  } else {
                    ev.doneTasks.remove(t.id);
                  }
                }),
                title: Text(t.label,
                    style: body(14, weight: FontWeight.w500, color: e.doneTasks.contains(t.id) ? HC.muted : HC.ink).copyWith(
                      decoration: e.doneTasks.contains(t.id) ? TextDecoration.lineThrough : null,
                    )),
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('By ${fmt.format(e.date.subtract(Duration(days: t.daysBefore)))}', style: body(12, color: HC.muted)),
                    if (!e.doneTasks.contains(t.id)) TaskReminderButton(task: t, event: e),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Budget extends StatefulWidget {
  const _Budget();

  @override
  State<_Budget> createState() => _BudgetState();
}

class _BudgetState extends State<_Budget> {
  TextEditingController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ctrl == null) {
      final b = AppScope.of(context).event?.budget;
      _ctrl = TextEditingController(text: b == null ? '' : b.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final total = state.event!.budget;
    final money = NumberFormat.decimalPattern();
    return CardBox(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your total budget', style: body(12, color: HC.muted)),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: display(24),
            decoration: const InputDecoration(hintText: 'Enter an amount'),
            onChanged: (v) => state.update((e) => e.budget = double.tryParse(v)),
          ),
          const SizedBox(height: 12),
          Text('Suggested split', style: overline()),
          for (final line in state.plan.budget)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0EEF7)))),
              child: Row(
                children: [
                  Expanded(child: Text(line.label, style: body(14))),
                  Text(
                    total == null ? '${(line.share * 100).round()}%' : money.format((total * line.share).round()),
                    style: body(14, color: HC.muted, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
