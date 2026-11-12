import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/event_details.dart';
import '../services/plan_generator.dart';
import '../services/reminders.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Asks once, right after the first party is planned: "Want reminders?"
/// Pass the root [NavigatorState] (it outlives the setup screen).
Future<void> askForReminders(NavigatorState nav, AppState state, {Duration delay = const Duration(milliseconds: 4400)}) async {
  if (!Reminders.supported || state.remindersEnabled != null) return;
  await Future<void>.delayed(delay); // Let the celebration finish first.
  if (!nav.mounted || state.remindersEnabled != null) return;
  final yes = await showDialog<bool>(
    context: nav.context,
    builder: (ctx) => AlertDialog(
      icon: const Text('🔔', style: TextStyle(fontSize: 40)),
      title: const Text('Never miss a thing'),
      content: const Text(
        'We\'ll remind you when it\'s time to send invites, book helpers and order the cake, '
        'plus a countdown to the big day. Free, and you can turn it off anytime.',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: HC.violet),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Remind me'),
        ),
      ],
    ),
  );
  if (yes == null) return;
  await state.setReminders(yes);
}

/// "🔔 Reminders · On at 9 AM" switch above the checklist.
class RemindersCard extends StatelessWidget {
  const RemindersCard({super.key});

  Future<void> _toggle(BuildContext context, AppState state, bool on) async {
    final ok = await state.setReminders(on);
    if (!ok && context.mounted) {
      toast(context, 'Notifications are off for Hoopla. Turn them on in your phone\'s Settings → Hoopla → Notifications.');
    }
  }

  Future<void> _pickHour(BuildContext context, AppState state) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.remindHour, minute: 0),
      helpText: 'REMIND ME AT (HOUR)',
    );
    if (t != null) await state.setRemindHour(t.hour);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!Reminders.supported) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            const Icon(Icons.notifications_none_rounded, size: 18, color: HC.muted),
            const SizedBox(width: 6),
            Expanded(child: Text('Get reminders for these on your phone with the Hoopla app.', style: body(12, color: HC.muted))),
          ],
        ),
      );
    }
    final on = state.remindersOn;
    final hourLabel = DateFormat('h a').format(DateTime(2000, 1, 1, state.remindHour));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        radius: 14,
        color: on ? HC.lime : HC.card,
        padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
        child: Row(
          children: [
            Text(on ? '🔔' : '🔕', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: on ? () => _pickHour(context, state) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reminders', style: body(14, weight: FontWeight.w600)),
                    Text(
                      on ? 'On · each to-do at $hourLabel (tap to change)' : 'Off · get a nudge when each to-do is due',
                      style: body(12, color: on ? HC.ink : HC.muted),
                    ),
                  ],
                ),
              ),
            ),
            Switch(value: on, activeTrackColor: HC.violet, onChanged: (v) => _toggle(context, state, v)),
          ],
        ),
      ),
    );
  }
}

/// Bell on a checklist task: set your own reminder time for it.
class TaskReminderButton extends StatelessWidget {
  const TaskReminderButton({super.key, required this.task, required this.event});
  final PlanTask task;
  final EventDetails event;

  Future<void> _set(BuildContext context, AppState state) async {
    final now = DateTime.now();
    final partyDay = DateTime(event.date.year, event.date.month, event.date.day);
    final current = event.taskReminders[task.id];
    final suggested = partyDay.subtract(Duration(days: task.daysBefore));
    final initial = current ?? (suggested.isAfter(now) ? suggested : now);
    final day = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(partyDay) ? partyDay : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: partyDay.isBefore(now) ? now : partyDay,
      helpText: 'REMIND ME ON',
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current != null ? TimeOfDay.fromDateTime(current) : TimeOfDay(hour: state.remindHour, minute: 0),
      helpText: 'AT',
    );
    if (time == null || !context.mounted) return;
    final when = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!when.isAfter(DateTime.now())) {
      toast(context, 'Pick a time later than now.');
      return;
    }
    if (!state.remindersOn) {
      final ok = await state.setReminders(true);
      if (!ok) {
        if (context.mounted) toast(context, 'Turn on notifications for Hoopla in your phone\'s Settings to get reminders.');
        return;
      }
    }
    await state.update((e) => e.taskReminders[task.id] = when);
    if (context.mounted) toast(context, 'We\'ll remind you ${DateFormat('EEE, MMM d · h:mm a').format(when)}.');
  }

  Future<void> _menu(BuildContext context, AppState state) async {
    final current = event.taskReminders[task.id];
    if (current == null) return _set(context, state);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HC.ground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(task.label, style: body(15, weight: FontWeight.w600)),
              subtitle: Text('Reminder: ${DateFormat('EEE, MMM d · h:mm a').format(current)}'),
            ),
            ListTile(leading: const Icon(Icons.edit_calendar_outlined), title: const Text('Change time'), onTap: () => Navigator.pop(ctx, 'change')),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: const Text('Remove my reminder'),
              subtitle: const Text('The automatic reminder comes back'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'change') await _set(context, state);
    if (choice == 'remove') await state.update((e) => e.taskReminders.remove(task.id));
  }

  @override
  Widget build(BuildContext context) {
    if (!Reminders.supported) return const SizedBox.shrink();
    final state = AppScope.of(context);
    final has = event.taskReminders.containsKey(task.id);
    return IconButton(
      tooltip: has ? 'Reminder set' : 'Set a reminder',
      visualDensity: VisualDensity.compact,
      onPressed: () => _menu(context, state),
      icon: Icon(has ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 20, color: has ? HC.violet : HC.muted),
    );
  }
}
