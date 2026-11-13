import 'package:flutter_test/flutter_test.dart';
import 'package:hoopla/data/helpers.dart';
import 'package:hoopla/data/sample_providers.dart';

void main() {
  test('every service type has 3 sample listings with photos', () {
    for (final c in helperCategories) {
      final list = sampleProvidersFor(c.label);
      expect(list, hasLength(3), reason: c.label);
      for (final p in list) {
        expect(p.isSample, isTrue);
        expect(p.serviceType, c.label);
        expect(p.photos, hasLength(6));
        expect(p.phone, isEmpty, reason: 'samples must never call a real number');
      }
    }
  });

  test('sample reviews and ratings match', () {
    final uid = sampleId('Photographers', 0);
    final reviews = sampleReviewsFor(uid);
    expect(reviews, hasLength(3));
    final s = sampleSummaryFor(uid);
    expect(s.count, 3);
    expect(s.average, closeTo(4.67, 0.01));
    expect(reviews.any((r) => r.reply.isNotEmpty), isTrue);
    expect(sampleSummaryFor(sampleId('Transport', 0)).count, 0);
  });
}
