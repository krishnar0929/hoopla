import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopla/services/referrals.dart';

void main() {
  group('invite codes', () {
    test('new codes are 6 easy-to-read characters', () {
      final r = Random(1);
      for (var i = 0; i < 200; i++) {
        final c = newReferralCode(r);
        expect(c.length, 6);
        expect(RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{6}$').hasMatch(c), isTrue, reason: c);
        expect(normalizeCode(c), c);
      }
    });

    test('typed codes are cleaned up', () {
      expect(normalizeCode(' k7q-2mx '), 'K7Q2MX');
      expect(normalizeCode('K7Q2M'), isNull);
      expect(normalizeCode('K7Q2MO'), isNull, reason: 'O is never used');
      expect(normalizeCode(null), isNull);
    });

    test('codes come out of invite links', () {
      expect(codeFromUri(Uri.parse('https://hoopla-894ca.web.app/?ref=k7q2mx')), 'K7Q2MX');
      expect(codeFromUri(Uri.parse('https://hoopla-894ca.web.app/')), isNull);
      expect(inviteMessage('K7Q2MX'), contains(inviteLink('K7Q2MX')));
    });
  });

  group('bonus weeks', () {
    final d = DateTime(2026, 11, 1);

    test('no friends, no bonus', () => expect(bonusEnd(const []), isNull));

    test('one friend gives one week', () => expect(bonusEnd([d]), d.add(const Duration(days: 7))));

    test('friends joining while a week runs add on the end', () {
      final end = bonusEnd([d.add(const Duration(days: 2)), d]);
      expect(end, d.add(const Duration(days: 14)));
    });

    test('a friend after the bonus ran out starts a fresh week', () {
      final later = d.add(const Duration(days: 30));
      expect(bonusEnd([d, later]), later.add(const Duration(days: 7)));
    });
  });
}
