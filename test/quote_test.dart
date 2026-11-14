import 'package:flutter_test/flutter_test.dart';
import 'package:hoopla/models/event_details.dart';
import 'package:hoopla/models/provider_profile.dart';
import 'package:hoopla/services/quote_service.dart';

void main() {
  final event = EventDetails(
    id: 'e1',
    occasion: 'Birthday',
    title: "Aarav's 5th Birthday",
    date: DateTime(2026, 12, 20),
    startMinutes: 16 * 60,
    hours: 3,
    indoor: true,
    guests: 35,
    audience: Audience.kids,
    energy: 1,
  );
  final provider = ProviderProfile(uid: 'p1', businessName: 'Lens & Laughter Studio', serviceType: 'Photographers', city: 'Edison, NJ', phone: '');

  test('the ready-made message has the event details', () {
    final m = defaultQuoteMessage(event, provider);
    expect(m, contains('Lens & Laughter Studio'));
    expect(m, contains('Sun, Dec 20'));
    expect(m, contains('35 guests'));
    expect(m, contains('indoors'));
  });

  test('one request per customer, provider and event', () {
    expect(QuoteRequest.docId('c1', 'p1', 'e1'), 'c1_p1_e1');
  });

  test('requests read back with status and summary', () {
    final q = QuoteRequest.fromDoc('c1_p1_e1', {
      'customerUid': 'c1',
      'customerName': 'Priya S.',
      'customerPhone': '+1 (732) 555-0100',
      'providerUid': 'p1',
      'eventDate': '2026-12-20',
      'startMinutes': 16 * 60,
      'guests': 35,
      'indoor': true,
      'message': 'Hi!',
      'status': 'replied',
    });
    expect(q.status, QuoteStatus.replied);
    expect(q.status.isOpen, isTrue);
    expect(q.phoneDigits, '17325550100');
    expect(q.eventSummary, 'Sun, Dec 20 · 4:00 PM · 35 guests · indoor');
    expect(QuoteStatusInfo.parse('new'), QuoteStatus.newRequest);
    expect(QuoteStatus.newRequest.value, 'new');
    expect(QuoteStatus.booked.isOpen, isFalse);
  });
}
