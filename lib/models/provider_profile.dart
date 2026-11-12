/// A service provider's public listing (photographer, decorator, panthulu, ...).
/// Stored at providers/{uid}.
class ProviderProfile {
  ProviderProfile({
    required this.uid,
    required this.businessName,
    required this.serviceType,
    required this.city,
    required this.phone,
    this.priceRange = '',
    this.about = '',
    this.photos = const [],
    this.instagram = '',
    this.website = '',
    this.verified = false,
  });

  /// Most photos a provider can show.
  static const maxPhotos = 12;

  final String uid;
  final String businessName;

  /// One of the helper category labels, e.g. "Photographers".
  final String serviceType;
  final String city;
  final String phone;
  final String priceRange;
  final String about;

  /// Download links of work photos (Firebase Storage), first one is the cover.
  final List<String> photos;

  /// Instagram handle without the @, e.g. "lensandlaughter".
  final String instagram;
  final String website;

  /// Set only by you (the admin) in the Firebase console.
  final bool verified;

  Uri? get instagramUrl => instagram.isEmpty ? null : Uri.https('www.instagram.com', '/$instagram/');

  Uri? get websiteUrl {
    if (website.isEmpty) return null;
    return Uri.tryParse(website.startsWith('http') ? website : 'https://$website');
  }

  /// Digits only, for call and WhatsApp links.
  String get phoneDigits => phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Fields the provider may write. `verified` is left out on purpose.
  Map<String, dynamic> toMap() => {
        'uid': uid,
        'businessName': businessName,
        'serviceType': serviceType,
        'city': city,
        'cityLower': city.trim().toLowerCase(),
        'phone': phone,
        'priceRange': priceRange,
        'about': about,
        'photos': photos,
        'instagram': instagram,
        'website': website,
      };

  factory ProviderProfile.fromMap(Map<String, dynamic> m) => ProviderProfile(
        uid: m['uid'] as String? ?? '',
        businessName: m['businessName'] as String? ?? '',
        serviceType: m['serviceType'] as String? ?? '',
        city: m['city'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        priceRange: m['priceRange'] as String? ?? '',
        about: m['about'] as String? ?? '',
        photos: [for (final x in (m['photos'] as List? ?? const [])) if (x is String) x],
        instagram: m['instagram'] as String? ?? '',
        website: m['website'] as String? ?? '',
        verified: m['verified'] as bool? ?? false,
      );
}

/// "@Lens.Laughter", "instagram.com/lens.laughter/?hl=en" → "lens.laughter".
String cleanInstagram(String input) {
  var t = input.trim();
  final m = RegExp(r'instagram\.com/([A-Za-z0-9._]+)', caseSensitive: false).firstMatch(t);
  if (m != null) t = m.group(1)!;
  t = t.replaceFirst(RegExp(r'^@+'), '');
  t = t.replaceAll(RegExp(r'[^A-Za-z0-9._]'), '');
  return t.toLowerCase();
}
