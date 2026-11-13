import 'package:intl/intl.dart';

import '../models/event_details.dart';
import 'plan_generator.dart';

/// One reminder to show on the phone at [when].
class ReminderSpec {
  const ReminderSpec({required this.eventId, required this.key, required this.when, required this.title, required this.body});
  final String eventId;

  /// What it's about, e.g. "tasks_2026-11-20", "custom_menu", "week", "eve", "day".
  final String key;
  final DateTime when;
  final String title;
  final String body;

  @override
  String toString() => '$key @ $when: $title / $body';
}

/// All reminders for one event, soonest first. Nothing in the past.
///
/// - Checklist tasks remind at [hour] on their due day (tasks due the same day are grouped).
/// - Tasks already overdue get one catch-up reminder at the next [hour].
/// - A task with its own reminder ([EventDetails.taskReminders]) uses that time instead.
/// - Countdown: 1 week before, the evening before (6 PM), and the morning of the party.
List<ReminderSpec> planReminders({
  required EventDetails e,
  required List<PlanTask> tasks,
  required DateTime now,
  int hour = 9,
}) {
  final partyDay = DateTime(e.date.year, e.date.month, e.date.day);
  final start = partyDay.add(Duration(minutes: e.startMinutes));
  if (!e.isActive || !start.isAfter(now)) return const [];

  DateTime at(DateTime day, [int h = -1]) => DateTime(day.year, day.month, day.day, h < 0 ? hour : h);
  DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
  final name = e.title.trim().isEmpty ? 'your party' : e.title.trim();
  final dateLabel = DateFormat('EEE, MMM d').format(partyDay);

  String toGo(DateTime day) {
    final days = partyDay.difference(dayOf(day)).inDays;
    if (days <= 0) return 'party day';
    if (days == 1) return 'party is tomorrow';
    if (days % 7 == 0) return '${days ~/ 7} week${days == 7 ? '' : 's'} to go';
    return '$days days to go';
  }

  final out = <ReminderSpec>[];
  final undone = [for (final t in tasks) if (!e.doneTasks.contains(t.id)) t];

  // Reminders the user set themselves.
  for (final t in undone) {
    final when = e.taskReminders[t.id];
    if (when == null || !when.isAfter(now)) continue;
    out.add(ReminderSpec(
      eventId: e.id,
      key: 'custom_${t.id}',
      when: when,
      title: '🔔 ${t.label}',
      body: 'Reminder for $name on $dateLabel.',
    ));
  }

  // Automatic task reminders, grouped by day.
  final nextSlot = now.isBefore(at(now)) ? at(now) : at(now.add(const Duration(days: 1)));
  final byDay = <DateTime, List<PlanTask>>{};
  for (final t in undone) {
    if (e.taskReminders.containsKey(t.id)) continue;
    var when = at(partyDay.subtract(Duration(days: t.daysBefore)));
    if (!when.isAfter(now)) when = nextSlot; // Overdue: one catch-up reminder.
    if (!when.isBefore(start)) continue;
    byDay.putIfAbsent(when, () => []).add(t);
  }
  for (final entry in byDay.entries) {
    final list = entry.value;
    final when = entry.key;
    final body = list.length == 1
        ? '${list.first.label} · ${toGo(when)}'
        : '${list.length} things to do: ${list.take(3).map((t) => t.label).join(', ')}${list.length > 3 ? '…' : ''} · ${toGo(when)}';
    out.add(ReminderSpec(
      eventId: e.id,
      key: 'tasks_${DateFormat('yyyy-MM-dd').format(when)}',
      when: when,
      title: list.length == 1 ? '✅ Time to do this for $name' : '✅ To do for $name',
      body: body,
    ));
  }

  // Countdown.
  out.add(ReminderSpec(
    eventId: e.id,
    key: 'week',
    when: at(partyDay.subtract(const Duration(days: 7))),
    title: '🎉 1 week to go!',
    body: '$name is on $dateLabel. ${undone.isEmpty ? 'Your checklist is all done. Nice!' : '${undone.length} thing${undone.length == 1 ? '' : 's'} left on your checklist.'}',
  ));
  out.add(ReminderSpec(
    eventId: e.id,
    key: 'eve',
    when: at(partyDay.subtract(const Duration(days: 1)), 18),
    title: '🎈 Tomorrow\'s the big day!',
    body: undone.isEmpty
        ? 'Everything\'s ticked off for $name. Get some rest!'
        : 'Last check for $name: ${undone.length} thing${undone.length == 1 ? '' : 's'} left. Charge your phone for Party mode!',
  ));
  final morning = at(partyDay);
  final twoBefore = start.subtract(const Duration(hours: 2));
  out.add(ReminderSpec(
    eventId: e.id,
    key: 'day',
    when: morning.isBefore(twoBefore) ? morning : twoBefore,
    title: '🥳 It\'s party day!',
    body: '$name starts at ${DateFormat('h:mm a').format(start)}. Open Party mode for games, the timer and scores.',
  ));

  final upcoming = [for (final r in out) if (r.when.isAfter(now.add(const Duration(minutes: 1)))) r];
  upcoming.sort((a, b) => a.when.compareTo(b.when));
  return upcoming;
}
