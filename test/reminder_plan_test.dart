import 'package:flutter_test/flutter_test.dart';
import 'package:hoopla/models/event_details.dart';
import 'package:hoopla/services/plan_generator.dart';
import 'package:hoopla/services/reminder_plan.dart';

EventDetails party(DateTime date) => EventDetails(
      id: 'e1',
      occasion: 'Birthday',
      title: "Ravi's 5th Birthday",
      date: date,
      startMinutes: 16 * 60,
      hours: 3,
      indoor: true,
      guests: 30,
      audience: Audience.kids,
      energy: 1,
    );

void main() {
  const tasks = [
    PlanTask('invites', 'Send invites', 28),
    PlanTask('menu', 'Finalize the menu', 14),
    PlanTask('gifts', 'Buy return gifts', 7),
    PlanTask('rsvp', 'Confirm head count', 5),
  ];
  final now = DateTime(2026, 11, 1, 12);

  test('each task reminds at 9 AM on its due day, plus a countdown', () {
    final e = party(DateTime(2026, 12, 20));
    final r = planReminders(e: e, tasks: tasks, now: now);
    final keys = [for (final x in r) x.key];
    expect(keys, containsAll(['week', 'eve', 'day']));
    final menu = r.firstWhere((x) => x.body.startsWith('Finalize the menu'));
    expect(menu.when, DateTime(2026, 12, 6, 9));
    expect(menu.body, contains('2 weeks to go'));
    // Sorted, and nothing in the past.
    for (var i = 1; i < r.length; i++) {
      expect(r[i].when.isBefore(r[i - 1].when), isFalse);
    }
    expect(r.every((x) => x.when.isAfter(now)), isTrue);
  });

  test('tasks already overdue get one catch-up reminder the next morning', () {
    final e = party(DateTime(2026, 11, 12));
    final r = planReminders(e: e, tasks: tasks, now: now);
    final catchUp = r.where((x) => x.when == DateTime(2026, 11, 2, 9)).toList();
    expect(catchUp, hasLength(1));
    expect(catchUp.first.body, contains('Send invites'));
    expect(catchUp.first.body, contains('Finalize the menu'));
  });

  test('done tasks are skipped and custom times win', () {
    final e = party(DateTime(2026, 12, 20))
      ..doneTasks.add('invites')
      ..taskReminders['menu'] = DateTime(2026, 11, 20, 18, 30);
    final r = planReminders(e: e, tasks: tasks, now: now);
    expect(r.any((x) => x.body.contains('Send invites')), isFalse);
    final custom = r.firstWhere((x) => x.key == 'custom_menu');
    expect(custom.when, DateTime(2026, 11, 20, 18, 30));
    expect(r.where((x) => x.body.startsWith('Finalize the menu')), isEmpty);
  });

  test('party-day reminder comes before the party starts', () {
    final e = party(DateTime(2026, 12, 20))..startMinutes = 10 * 60;
    final day = planReminders(e: e, tasks: tasks, now: now).firstWhere((x) => x.key == 'day');
    expect(day.when, DateTime(2026, 12, 20, 8));
  });

  test('past or cancelled parties have no reminders', () {
    expect(planReminders(e: party(DateTime(2026, 10, 1)), tasks: tasks, now: now), isEmpty);
    expect(planReminders(e: party(DateTime(2026, 12, 20))..status = 'cancelled', tasks: tasks, now: now), isEmpty);
  });

  test('custom reminders survive a save and load', () {
    final e = party(DateTime(2026, 12, 20))..taskReminders['menu'] = DateTime(2026, 11, 20, 18, 30);
    final back = EventDetails.fromMap(e.toMap());
    expect(back.taskReminders['menu'], DateTime(2026, 11, 20, 18, 30));
  });
}
