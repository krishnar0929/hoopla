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
    this.facebook = '',
    this.youtube = '',
    this.tiktok = '',
    this.reviewsLink = '',
    this.featured = const [],
    this.lat,
    this.lng,
    this.verified = false,
  });

  /// Most featured post links (reels, videos) a provider can show.
  static const maxFeatured = 6;

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

  /// Facebook page, YouTube channel, TikTok: a handle or a full link.
  final String facebook;
  final String youtube;
  final String tiktok;

  /// Link to their reviews elsewhere (Google, Yelp, WeddingWire, Facebook reviews).
  final String reviewsLink;

  /// Map position of [city] (found when the listing is saved), for distance sorting.
  final double? lat;
  final double? lng;

  /// Links to their best posts: Instagram reels/posts, YouTube, TikTok videos.
  final List<String> featured;

  /// Set only by you (the admin) in the Firebase console.
  final bool verified;

  Uri? get instagramUrl => instagram.isEmpty ? null : Uri.https('www.instagram.com', '/$instagram/');

  Uri? get websiteUrl {
    if (website.isEmpty) return null;
    return Uri.tryParse(website.startsWith('http') ? website : 'https://$website');
  }

  Uri? get facebookUrl => socialUrl(facebook, 'www.facebook.com', '');
  Uri? get youtubeUrl => socialUrl(youtube, 'www.youtube.com', '@');
  Uri? get tiktokUrl => socialUrl(tiktok, 'www.tiktok.com', '@');
  Uri? get reviewsUrl => reviewsLink.isEmpty ? null : Uri.tryParse(reviewsLink.startsWith('http') ? reviewsLink : 'https://$reviewsLink');

  /// A built-in sample listing (lib/data/sample_providers.dart), not a real business.
  bool get isSample => uid.startsWith('sample-');

  /// True when the listing links anywhere outside Hoopla.
  bool get hasSocial => [instagramUrl, facebookUrl, youtubeUrl, tiktokUrl, reviewsUrl, websiteUrl].any((u) => u != null);

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
        'facebook': facebook,
        'youtube': youtube,
        'tiktok': tiktok,
        'reviewsLink': reviewsLink,
        'featured': featured,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
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
        facebook: m['facebook'] as String? ?? '',
        youtube: m['youtube'] as String? ?? '',
        tiktok: m['tiktok'] as String? ?? '',
        reviewsLink: m['reviewsLink'] as String? ?? '',
        featured: [for (final x in (m['featured'] as List? ?? const [])) if (x is String) x],
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
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

/// A full link stays as it is; a handle like "@lensandlaughter" becomes
/// https://host/<prefix>lensandlaughter. Empty input gives null.
Uri? socialUrl(String value, String host, String prefix) {
  final v = value.trim();
  if (v.isEmpty) return null;
  if (v.startsWith('http://') || v.startsWith('https://')) return Uri.tryParse(v);
  if (v.contains('.') && v.contains('/')) return Uri.tryParse('https://$v');
  final handle = v.replaceFirst(RegExp(r'^@+'), '').replaceAll(RegExp(r'\s'), '');
  if (handle.isEmpty) return null;
  return Uri.https(host, '/$prefix$handle');
}
