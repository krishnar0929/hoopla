import 'package:flutter_test/flutter_test.dart';
import 'package:hoopla/models/event_details.dart';
import 'package:hoopla/services/event_parser.dart';

void main() {
  // A Tuesday.
  final now = DateTime(2026, 11, 10, 18, 30);

  test('kids birthday with date, time, place and guests', () {
    final p = EventParser.parse(
      "My son's 1st birthday, about 40 people in our backyard, Saturday Dec 12 at 4pm for 3 hours",
      now: now,
    );
    expect(p.occasion, 'Birthday');
    expect(p.title, "My son's 1st birthday");
    expect(p.guests, 40);
    expect(p.indoor, false);
    expect(p.date, DateTime(2026, 12, 12));
    expect(p.startMinutes, 16 * 60);
    expect(p.hours, 3);
    expect(p.audience, Audience.kids);
  });

  test('pooja at home with families on a weekday morning', () {
    final p = EventParser.parse('Pooja at home for 15 families on Sunday morning', now: now);
    expect(p.occasion, 'Pooja');
    expect(p.guests, 45);
    expect(p.indoor, true);
    expect(p.date, DateTime(2026, 11, 15));
    expect(p.startMinutes, 10 * 60);
    expect(p.audience, Audience.everyone);
  });

  test('office get-together with a time range', () {
    final p = EventParser.parse('Office get together, 25 adults, restaurant, 7-10pm, loud with a DJ', now: now);
    expect(p.occasion, 'Get-together');
    expect(p.guests, 25);
    expect(p.indoor, true);
    expect(p.startMinutes, 19 * 60);
    expect(p.hours, 3);
    expect(p.audience, Audience.adults);
    expect(p.energy, 2);
  });

  test('name, tomorrow and a range that starts in the morning', () {
    final p = EventParser.parse("Aarav's 5th birthday party tomorrow 11 to 2pm", now: now);
    expect(p.title, "Aarav's 5th birthday");
    expect(p.date, DateTime(2026, 11, 11));
    expect(p.startMinutes, 11 * 60);
    expect(p.hours, 3);
    expect(p.audience, Audience.kids);
  });

  test('day before month', () {
    final p = EventParser.parse('Housewarming on 5th December, around 60 guests', now: now);
    expect(p.occasion, 'Housewarming');
    expect(p.date, DateTime(2026, 12, 5));
    expect(p.guests, 60);
    expect(p.indoor, isNull);
  });

  test('a date already past rolls to next year', () {
    final p = EventParser.parse('Anniversary dinner on Jan 3', now: now);
    expect(p.occasion, 'Anniversary');
    expect(p.date, DateTime(2027, 1, 3));
    expect(p.startMinutes, 19 * 60);
  });

  test('curly apostrophes from the iPhone keyboard', () {
    final p = EventParser.parse('Meera’s 30th birthday', now: now);
    expect(p.title, "Meera's 30th birthday");
    expect(p.audience, Audience.adults);
  });

  test('words that only look like dates are ignored', () {
    final p = EventParser.parse('Birthday with decorations ready by 12', now: now);
    expect(p.date, isNull);
  });

  test('nothing recognised', () {
    expect(EventParser.parse('hello there', now: now).isEmpty, isTrue);
  });

  test('cancelled status survives save and load', () {
    final e = EventDetails(
      id: '1',
      occasion: 'Birthday',
      title: 'Test',
      date: DateTime(2026, 12, 12),
      startMinutes: 960,
      hours: 3,
      indoor: true,
      guests: 20,
      audience: Audience.kids,
      energy: 1,
    )..status = 'cancelled';
    final back = EventDetails.fromMap(e.toMap());
    expect(back.isActive, isFalse);
    expect(EventDetails.fromMap({'id': '2'}).isActive, isTrue);
  });
}
