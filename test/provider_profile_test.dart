import 'package:flutter_test/flutter_test.dart';
import 'package:hoopla/models/provider_profile.dart';

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
}
