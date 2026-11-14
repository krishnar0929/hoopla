import 'package:flutter_test/flutter_test.dart';
import 'package:hoopla/models/event_details.dart';
import 'package:hoopla/models/provider_profile.dart';
import 'package:hoopla/services/budget_match.dart';
import 'package:hoopla/services/location_service.dart';
import 'package:hoopla/services/weather_service.dart';

EventDetails party({bool indoor = false}) => EventDetails(
      id: 'e1',
      occasion: 'Birthday',
      title: 'Party',
      date: DateTime(2026, 12, 14),
      startMinutes: 16 * 60,
      hours: 3,
      indoor: indoor,
      guests: 30,
      audience: Audience.kids,
      energy: 1,
    );

void main() {
  group('places', () {
    test('short labels like "Edison, NJ"', () {
      expect(shortLabel({'town': 'Edison', 'state': 'New Jersey', 'ISO3166-2-lvl4': 'US-NJ'}), 'Edison, NJ');
      expect(shortLabel({'city': 'Hyderabad', 'state': 'Telangana'}), 'Hyderabad, Telangana');
      expect(shortLabel({}, fallback: 'Current location'), 'Current location');
    });

    test('distance between Edison and Jersey City is about 20 miles', () {
      final d = milesBetween(40.5187, -74.4121, 40.7178, -74.0431);
      expect(d, inInclusiveRange(18, 24));
      expect(distanceLabel(3.24), '3.2 mi');
      expect(distanceLabel(21.6), '22 mi');
    });

    test('venue survives a save and load', () {
      final e = party()..venue = const Place(label: 'Edison, NJ', address: '1 Main St, Edison', lat: 40.5, lng: -74.4, countryCode: 'us');
      final back = EventDetails.fromMap(e.toMap());
      expect(back.venue?.label, 'Edison, NJ');
      expect(back.venue?.lat, 40.5);
      expect(back.venue?.usesFahrenheit, isTrue);
      expect(EventDetails.fromMap(party().toMap()).venue, isNull);
      expect(const Place(label: 'x', lat: 0, lng: 0, countryCode: 'in').usesFahrenheit, isFalse);
    });
  });

  group('weather', () {
    test('reads the forecast for the party hours', () {
      final json = {
        'daily': {
          'weather_code': [61],
          'temperature_2m_max': [64.2],
          'temperature_2m_min': [50.1],
        },
        'hourly': {
          'temperature_2m': [for (var h = 0; h < 24; h++) 50 + h * 0.5],
          'precipitation_probability': [for (var h = 0; h < 24; h++) h == 17 ? 70 : 10],
        },
      };
      final w = parseWeather(json, party(), fahrenheit: true)!;
      expect(w.rainChance, 70);
      expect(w.partyTemp, 58);
      expect(w.summary, 'Rain');
      expect(w.emoji, '🌧️');
      expect(w.advice(indoor: false), contains('tent'));
    });

    test('advice fits the day', () {
      expect(weatherAdvice(code: 0, rainChance: 0, temp: 95, fahrenheit: true, indoor: false), contains('shade'));
      expect(weatherAdvice(code: 0, rainChance: 0, temp: 72, fahrenheit: true, indoor: false), contains('Great weather'));
      expect(weatherAdvice(code: 95, rainChance: 80, temp: 70, fahrenheit: true, indoor: false), contains('Storms'));
      expect(weatherAdvice(code: 0, rainChance: 0, temp: 22, fahrenheit: false, indoor: false), contains('Great weather'));
    });

    test('the forecast shows up 16 days before', () {
      expect(forecastFrom(DateTime(2026, 12, 14)), DateTime(2026, 11, 29));
    });
  });

  group('budget', () {
    test('price ranges are read', () {
      final a = PriceRange.parse(r'$400–$900 per event')!;
      expect((a.min, a.max, a.unit), (400.0, 900.0, 'event'));
      final b = PriceRange.parse(r'$15–$30 per plate')!;
      expect(b.unit, 'plate');
      expect(b.estimate(party()), (450.0, 900.0));
      final c = PriceRange.parse(r'$25/hour')!;
      expect((c.min, c.unit), (25.0, 'hour'));
      expect(c.estimate(party()).$1, 75);
      expect(PriceRange.parse(r'$1,200–$4,000')!.max, 4000);
      expect(PriceRange.parse('Ask for a quote'), isNull);
    });

    test('providers are matched to the budget', () {
      ProviderProfile p(String price) => ProviderProfile(uid: 'x', businessName: 'X', serviceType: 'Caterers', city: '', phone: '', priceRange: price);
      expect(fitsBudget(p(r'$15–$30 per plate'), party(), 500), isTrue);
      expect(fitsBudget(p(r'$20–$40 per plate'), party(), 500), isFalse);
      expect(fitsBudget(p('Call us'), party(), 10), isTrue);
      expect(estimateLabel(p(r'$15–$30 per plate'), party()), r'About $450–$900 for 30 guests');
      expect(budgetServices['Food'], 'Caterers');
    });
  });
}
