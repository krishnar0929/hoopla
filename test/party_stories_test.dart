import 'package:flutter_test/flutter_test.dart';
import 'package:hoopla/data/games.dart';
import 'package:hoopla/data/party_stories.dart';
import 'package:hoopla/models/event_details.dart';

void main() {
  test('20 sample stories, each complete', () {
    expect(partyStories, hasLength(20));
    final ids = <String>{};
    for (final s in partyStories) {
      expect(ids.add(s.id), isTrue, reason: 'duplicate id ${s.id}');
      expect(occasions, contains(s.occasion), reason: s.id);
      expect(s.photos, hasLength(6));
      expect(s.stars, inInclusiveRange(1, 5));
      expect(s.review, isNotEmpty);
      expect(s.gameIds, isNotEmpty);
      for (final g in s.gameIds) {
        expect(gameCatalog.any((x) => x.id == g), isTrue, reason: '${s.id} uses unknown game $g');
      }
    }
  });

  test('the first story is Vir\'s 1st birthday', () {
    expect(partyStories.first.title, "Vir's 1st birthday");
  });
}
