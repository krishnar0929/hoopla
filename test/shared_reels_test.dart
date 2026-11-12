import 'package:flutter_test/flutter_test.dart';
import 'package:hoopla/services/shared_reels.dart';

void main() {
  test('finds the link inside shared Instagram text', () {
    expect(
      firstLink('Check this out! https://www.instagram.com/reel/AbC123/?igsh=xyz.'),
      'https://www.instagram.com/reel/AbC123/?igsh=xyz',
    );
    expect(firstLink('no link here'), isNull);
  });

  test('recognises reel sources', () {
    expect(reelSource('https://www.instagram.com/reel/AbC123/'), 'Instagram reel');
    expect(reelSource('https://vm.tiktok.com/ZM123/'), 'TikTok');
    expect(reelSource('https://youtube.com/shorts/xyz'), 'YouTube Short');
    expect(isReelLink('https://example.com/page'), isFalse);
  });

  test('default name uses the source and date', () {
    expect(defaultTitle('https://www.instagram.com/reel/x/', now: DateTime(2026, 11, 12)), 'Instagram reel · Nov 12');
    expect(defaultTitle('https://example.com', now: DateTime(2026, 11, 12)), 'Saved video · Nov 12');
  });
}
