import 'package:flutter_test/flutter_test.dart';
import 'package:hoopla/data/games.dart';
import 'package:hoopla/models/event_details.dart';
import 'package:hoopla/services/plan_generator.dart';

EventDetails kidsBirthday({bool indoor = true, int hours = 3, int guests = 40}) => EventDetails(
      id: 'test',
      occasion: 'Birthday',
      title: "Aarav's 1st birthday",
      date: DateTime.now().add(const Duration(days: 36)),
      startMinutes: 16 * 60,
      hours: hours,
      indoor: indoor,
      guests: guests,
      audience: Audience.kids,
      energy: 1,
    );

void main() {
  test('suggested games fit in the games time', () {
    final e = kidsBirthday();
    e.gameIds = PlanGenerator.suggestGameIds(e);
    final minutes = e.gameIds.map((id) => gameById(id)!.minutes).fold<int>(0, (a, b) => a + b);
    expect(e.gameIds, isNotEmpty);
    expect(minutes, lessThanOrEqualTo(PlanGenerator.gamesBudget(e)));
  });

  test('indoor events never get outdoor-only games', () {
    final e = kidsBirthday();
    for (final g in PlanGenerator.rankedGames(e)) {
      expect(g.indoor, isTrue, reason: g.name);
    }
  });

  test('kids party adds one icebreaker for the parents', () {
    final e = kidsBirthday();
    final ids = PlanGenerator.suggestGameIds(e);
    final adultOnly = ids.map(gameById).where((g) => g != null && !g.kids).length;
    expect(adultOnly, 1);
  });

  test('timeline fills exactly the event length', () {
    for (final hours in [2, 3, 4, 5]) {
      final e = kidsBirthday(hours: hours);
      e.gameIds = PlanGenerator.suggestGameIds(e);
      final plan = PlanGenerator.build(e);
      final last = plan.timeline.last;
      expect(last.start + last.minutes, e.startMinutes + hours * 60, reason: '$hours hours');
    }
  });

  test('games that do not fit become backups', () {
    final e = kidsBirthday(hours: 2);
    e.gameIds = gameCatalog.where((g) => g.indoor && g.kids).map((g) => g.id).toList();
    final plan = PlanGenerator.build(e);
    expect(plan.backupGames, isNotEmpty);
  });

  test('pooja happens right after welcome', () {
    final e = kidsBirthday()..occasion = 'Pooja';
    final plan = PlanGenerator.build(e);
    expect(plan.timeline[1].title, 'Pooja with panthulu');
  });

  test('event survives save and load', () {
    final e = kidsBirthday();
    e.gameIds = ['balloon_stomp'];
    e.shortlist.add(ShortlistVendor(id: '1', category: 'Photographers', name: 'Lens Studio', phone: '555'));
    final back = EventDetails.fromMap(e.toMap());
    expect(back.title, e.title);
    expect(back.gameIds, ['balloon_stomp']);
    expect(back.shortlist.single.name, 'Lens Studio');
    expect(back.audience, Audience.kids);
  });

  test('clock formats 12-hour time', () {
    expect(clock(16 * 60 + 5), '4:05');
    expect(clockAmPm(0), '12:00 AM');
    expect(clockAmPm(12 * 60 + 30), '12:30 PM');
  });
}
