import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One customer's review of a provider. Stored at providers/{providerUid}/reviews/{reviewerUid},
/// so each person has at most one review per provider (editing replaces it).
class Review {
  Review({
    required this.reviewerUid,
    required this.stars,
    required this.comment,
    required this.name,
    this.eventType = '',
    this.createdAt,
    this.reply = '',
  });

  final String reviewerUid;
  final int stars;
  final String comment;

  /// Shown as "Priya S." (first name and initial).
  final String name;
  final String eventType;
  final DateTime? createdAt;

  /// The provider's answer.
  final String reply;

  factory Review.fromDoc(String id, Map<String, dynamic> m) => Review(
        reviewerUid: id,
        stars: (m['stars'] as num?)?.toInt() ?? 0,
        comment: m['comment'] as String? ?? '',
        name: m['name'] as String? ?? 'Hoopla user',
        eventType: m['eventType'] as String? ?? '',
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        reply: m['reply'] as String? ?? '',
      );
}

class RatingSummary {
  const RatingSummary(this.average, this.count);
  final double average;
  final int count;
  static const none = RatingSummary(0, 0);
}

/// "Priya Sharma" → "Priya S.", "priya@x.com" → "Priya".
String shortName(String? displayName, String? email) {
  final n = (displayName ?? '').trim();
  if (n.isNotEmpty) {
    final parts = n.split(RegExp(r'\s+'));
    return parts.length == 1 ? parts.first : '${parts.first} ${parts.last[0].toUpperCase()}.';
  }
  final e = (email ?? '').split('@').first.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (e.isEmpty) return 'Hoopla user';
  return e[0].toUpperCase() + e.substring(1).toLowerCase();
}

/// The average with one decimal for display, e.g. 4.666 → "4.7".
String ratingLabel(double average) => average.toStringAsFixed(1);

class ReviewService {
  ReviewService._();

  static CollectionReference<Map<String, dynamic>> _reviews(String providerUid) =>
      FirebaseFirestore.instance.collection('providers').doc(providerUid).collection('reviews');

  /// Average stars and how many reviews (counted on the server).
  static Future<RatingSummary> summary(String providerUid) async {
    final snap = await _reviews(providerUid).aggregate(count(), average('stars')).get();
    final n = snap.count ?? 0;
    return n == 0 ? RatingSummary.none : RatingSummary(snap.getAverage('stars') ?? 0, n);
  }

  /// Newest reviews first.
  static Future<List<Review>> load(String providerUid, {int limit = 50}) async {
    final snap = await _reviews(providerUid).orderBy('createdAt', descending: true).limit(limit).get();
    return [for (final d in snap.docs) Review.fromDoc(d.id, d.data())];
  }

  /// The signed-in person's own review of this provider, if any.
  static Future<Review?> mine(String providerUid) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || u.isAnonymous) return null;
    final d = await _reviews(providerUid).doc(u.uid).get();
    return d.exists ? Review.fromDoc(d.id, d.data()!) : null;
  }

  /// Adds or updates the signed-in person's review.
  static Future<void> save({required String providerUid, required int stars, required String comment, String eventType = ''}) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || u.isAnonymous) throw StateError('Sign in to write a review.');
    if (u.uid == providerUid) throw StateError('You can\'t review your own listing.');
    final ref = _reviews(providerUid).doc(u.uid);
    final existing = await ref.get();
    await ref.set({
      'stars': stars,
      'comment': comment.trim(),
      'name': shortName(u.displayName, u.email),
      'eventType': eventType,
      'createdAt': existing.exists ? existing.data()!['createdAt'] : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'reply': existing.data()?['reply'] ?? '',
    });
  }

  static Future<void> delete(String providerUid) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await _reviews(providerUid).doc(u.uid).delete();
  }

  /// The provider answers a review on their own listing.
  static Future<void> reply({required String providerUid, required String reviewerUid, required String text}) =>
      _reviews(providerUid).doc(reviewerUid).update({'reply': text.trim(), 'repliedAt': FieldValue.serverTimestamp()});
}
