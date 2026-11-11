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
    this.verified = false,
  });

  final String uid;
  final String businessName;

  /// One of the helper category labels, e.g. "Photographers".
  final String serviceType;
  final String city;
  final String phone;
  final String priceRange;
  final String about;

  /// Set only by you (the admin) in the Firebase console.
  final bool verified;

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
      };

  factory ProviderProfile.fromMap(Map<String, dynamic> m) => ProviderProfile(
        uid: m['uid'] as String? ?? '',
        businessName: m['businessName'] as String? ?? '',
        serviceType: m['serviceType'] as String? ?? '',
        city: m['city'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        priceRange: m['priceRange'] as String? ?? '',
        about: m['about'] as String? ?? '',
        verified: m['verified'] as bool? ?? false,
      );
}
