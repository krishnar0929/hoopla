import 'package:flutter_test/flutter_test.dart';
import 'package:hoopla/models/provider_profile.dart';
import 'package:hoopla/services/review_service.dart';

void main() {
  test('Instagram handles are cleaned up', () {
    expect(cleanInstagram('@Lens.Laughter'), 'lens.laughter');
    expect(cleanInstagram('https://www.instagram.com/lens_laughter/?hl=en'), 'lens_laughter');
    expect(cleanInstagram('  '), '');
  });

  test('photos, Instagram and website survive a save and load', () {
    final p = ProviderProfile(
      uid: 'u1',
      businessName: 'Lens & Laughter',
      serviceType: 'Photographers',
      city: 'Edison, NJ',
      phone: '+1 732 555 0100',
      photos: const ['https://a/1.jpg', 'https://a/2.jpg'],
      instagram: 'lens.laughter',
      website: 'lensandlaughter.com',
    );
    final back = ProviderProfile.fromMap(p.toMap());
    expect(back.photos, p.photos);
    expect(back.instagramUrl.toString(), 'https://www.instagram.com/lens.laughter/');
    expect(back.websiteUrl.toString(), 'https://lensandlaughter.com');
    expect(ProviderProfile.fromMap({'uid': 'x'}).photos, isEmpty);
  });

  test('social handles and links become web links', () {
    expect(socialUrl('@lensandlaughter', 'www.tiktok.com', '@').toString(), 'https://www.tiktok.com/@lensandlaughter');
    expect(socialUrl('LensLaughterStudio', 'www.facebook.com', '').toString(), 'https://www.facebook.com/LensLaughterStudio');
    expect(socialUrl('youtube.com/@lens', 'www.youtube.com', '@').toString(), 'https://youtube.com/@lens');
    expect(socialUrl('https://g.page/r/abc/review', 'x', '').toString(), 'https://g.page/r/abc/review');
    expect(socialUrl('  ', 'www.tiktok.com', '@'), isNull);
  });

  test('social links and featured posts survive a save and load', () {
    final p = ProviderProfile(
      uid: 'u1',
      businessName: 'Lens & Laughter',
      serviceType: 'Photographers',
      city: 'Edison, NJ',
      phone: '+1 732 555 0100',
      tiktok: '@lens',
      featured: const ['https://www.instagram.com/reel/abc/'],
    );
    final back = ProviderProfile.fromMap(p.toMap());
    expect(back.featured, p.featured);
    expect(back.tiktokUrl.toString(), 'https://www.tiktok.com/@lens');
    expect(back.hasSocial, isTrue);
    expect(ProviderProfile.fromMap({'uid': 'x'}).hasSocial, isFalse);
  });

  test('reviewers are shown by first name and last initial', () {
    expect(shortName('Priya Sharma', null), 'Priya S.');
    expect(shortName('Priya', null), 'Priya');
    expect(shortName(null, 'krishna.m9@gmail.com'), 'Krishnam');
    expect(shortName(null, null), 'Hoopla user');
    expect(ratingLabel(4.666), '4.7');
  });
}
