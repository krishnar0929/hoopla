import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/event_details.dart';
import '../models/provider_profile.dart';

/// Where a quote request is: the provider sets seen / replied / booked / declined,
/// the customer can cancel (or send it again).
enum QuoteStatus { newRequest, seen, replied, booked, declined, cancelled }

extension QuoteStatusInfo on QuoteStatus {
  String get value => this == QuoteStatus.newRequest ? 'new' : name;

  String get label => switch (this) {
        QuoteStatus.newRequest => 'Sent',
        QuoteStatus.seen => 'Seen',
        QuoteStatus.replied => 'Replied',
        QuoteStatus.booked => 'Booked',
        QuoteStatus.declined => 'Not available',
        QuoteStatus.cancelled => 'Cancelled',
      };

  /// Still waiting on someone (shown at the top, counted as open).
  bool get isOpen => this == QuoteStatus.newRequest || this == QuoteStatus.seen || this == QuoteStatus.replied;

  static QuoteStatus parse(String? s) {
    for (final q in QuoteStatus.values) {
      if (q.value == s) return q;
    }
    return QuoteStatus.newRequest;
  }
}

/// A customer asking a provider for a quote, with the event details filled in.
/// Stored at quotes/{customerUid}_{providerUid}_{eventId}: one per event and provider.
class QuoteRequest {
  QuoteRequest({
    required this.id,
    required this.customerUid,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.providerUid,
    required this.providerName,
    required this.serviceType,
    required this.eventId,
    required this.eventTitle,
    required this.occasion,
    required this.eventDate,
    required this.startMinutes,
    required this.guests,
    required this.indoor,
    required this.message,
    this.status = QuoteStatus.newRequest,
    this.reply = '',
    this.createdAt,
    this.repliedAt,
  });

  final String id;
  final String customerUid;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String providerUid;
  final String providerName;
  final String serviceType;
  final String eventId;
  final String eventTitle;
  final String occasion;

  /// yyyy-MM-dd
  final String eventDate;
  final int startMinutes;
  final int guests;
  final bool indoor;
  final String message;
  final QuoteStatus status;
  final String reply;
  final DateTime? createdAt;
  final DateTime? repliedAt;

  DateTime? get date => DateTime.tryParse(eventDate);

  /// "Sat, Dec 20 · 4:00 PM · 35 guests · indoor"
  String get eventSummary {
    final d = date;
    final time = DateFormat('h:mm a').format(DateTime(2000, 1, 1, startMinutes ~/ 60, startMinutes % 60));
    return [
      if (d != null) DateFormat('EEE, MMM d').format(d),
      time,
      '$guests guests',
      indoor ? 'indoor' : 'outdoor',
    ].join(' · ');
  }

  /// Phone digits for WhatsApp/call, or empty.
  String get phoneDigits => customerPhone.replaceAll(RegExp(r'[^0-9]'), '');

  static String docId(String customerUid, String providerUid, String eventId) => '${customerUid}_${providerUid}_$eventId';

  factory QuoteRequest.fromDoc(String id, Map<String, dynamic> m) => QuoteRequest(
        id: id,
        customerUid: m['customerUid'] as String? ?? '',
        customerName: m['customerName'] as String? ?? 'Hoopla user',
        customerEmail: m['customerEmail'] as String? ?? '',
        customerPhone: m['customerPhone'] as String? ?? '',
        providerUid: m['providerUid'] as String? ?? '',
        providerName: m['providerName'] as String? ?? '',
        serviceType: m['serviceType'] as String? ?? '',
        eventId: m['eventId'] as String? ?? '',
        eventTitle: m['eventTitle'] as String? ?? '',
        occasion: m['occasion'] as String? ?? '',
        eventDate: m['eventDate'] as String? ?? '',
        startMinutes: (m['startMinutes'] as num?)?.toInt() ?? 0,
        guests: (m['guests'] as num?)?.toInt() ?? 0,
        indoor: m['indoor'] as bool? ?? true,
        message: m['message'] as String? ?? '',
        status: QuoteStatusInfo.parse(m['status'] as String?),
        reply: m['reply'] as String? ?? '',
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        repliedAt: (m['repliedAt'] as Timestamp?)?.toDate(),
      );
}

/// The ready-made message a customer sends with a quote request.
String defaultQuoteMessage(EventDetails e, ProviderProfile p) {
  final when = DateFormat('EEE, MMM d').format(e.date);
  return 'Hi ${p.businessName}! I\'m planning "${e.title}" (${e.occasion.toLowerCase()}) on $when '
      'for about ${e.guests} guests, ${e.indoor ? 'indoors' : 'outdoors'}. '
      'Are you available, and could you share a quote?';
}

/// Lead numbers for a provider's home screen.
class LeadStats {
  const LeadStats({this.quotesThisMonth = 0, this.openQuotes = 0, this.tapsThisMonth = 0, this.totalQuotes = 0});
  final int quotesThisMonth;
  final int openQuotes;

  /// Calls, WhatsApp, Instagram and website taps from customers this month.
  final int tapsThisMonth;
  final int totalQuotes;
}

class QuoteService {
  QuoteService._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _quotes => _db.collection('quotes');

  static User? get _user {
    final u = FirebaseAuth.instance.currentUser;
    return (u == null || u.isAnonymous) ? null : u;
  }

  /// Sends a quote request (or sends a cancelled/declined one again).
  /// Returns false when one is already open with this provider for this event.
  static Future<bool> send({
    required EventDetails event,
    required ProviderProfile provider,
    required String message,
    required String name,
    required String phone,
  }) async {
    final u = _user;
    if (u == null) throw StateError('Sign in first.');
    final ref = _quotes.doc(QuoteRequest.docId(u.uid, provider.uid, event.id));
    DocumentSnapshot<Map<String, dynamic>>? existing;
    try {
      existing = await ref.get();
    } on FirebaseException catch (e) {
      // The rules hide documents that don't exist yet.
      if (e.code != 'permission-denied') rethrow;
    }
    final text = message.trim().length > 1500 ? message.trim().substring(0, 1500) : message.trim();
    if (existing != null && existing.exists) {
      final status = QuoteStatusInfo.parse(existing.data()?['status'] as String?);
      if (status.isOpen || status == QuoteStatus.booked) return false;
      await ref.update({'status': 'new', 'message': text, 'reply': '', 'updatedAt': FieldValue.serverTimestamp()});
      return true;
    }
    await ref.set({
      'customerUid': u.uid,
      'customerName': name.trim().isEmpty ? 'Hoopla user' : name.trim(),
      'customerEmail': u.email ?? '',
      'customerPhone': phone.trim(),
      'providerUid': provider.uid,
      'providerName': provider.businessName,
      'serviceType': provider.serviceType,
      'eventId': event.id,
      'eventTitle': event.title,
      'occasion': event.occasion,
      'eventDate': DateFormat('yyyy-MM-dd').format(event.date),
      'startMinutes': event.startMinutes,
      'guests': event.guests,
      'indoor': event.indoor,
      'message': text,
      'status': 'new',
      'reply': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Remember the phone for next time.
    if (phone.trim().isNotEmpty) {
      await _db.collection('users').doc(u.uid).set({'phone': phone.trim()}, SetOptions(merge: true));
    }
    return true;
  }

  static List<QuoteRequest> _sorted(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = [for (final d in snap.docs) QuoteRequest.fromDoc(d.id, d.data())];
    list.sort((a, b) => (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100)));
    return list;
  }

  /// The customer's own requests, newest first.
  static Future<List<QuoteRequest>> mine() async {
    final u = _user;
    if (u == null) return const [];
    return _sorted(await _quotes.where('customerUid', isEqualTo: u.uid).limit(200).get());
  }

  /// A provider's leads, newest first.
  static Future<List<QuoteRequest>> inbox() async {
    final u = _user;
    if (u == null) return const [];
    return _sorted(await _quotes.where('providerUid', isEqualTo: u.uid).limit(300).get());
  }

  /// Provider: mark seen / booked / declined, or reply.
  static Future<void> respond(QuoteRequest q, {QuoteStatus? status, String? reply}) {
    final data = <String, Object?>{'updatedAt': FieldValue.serverTimestamp()};
    if (reply != null) {
      data['reply'] = reply.trim();
      data['repliedAt'] = FieldValue.serverTimestamp();
      data['status'] = (status ?? QuoteStatus.replied).value;
    } else if (status != null) {
      data['status'] = status.value;
    }
    return _quotes.doc(q.id).update(data);
  }

  /// Customer: cancel a request.
  static Future<void> cancel(QuoteRequest q) =>
      _quotes.doc(q.id).update({'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});

  /// Counts a call / WhatsApp / Instagram / website tap so providers see their leads.
  /// Never blocks or fails the tap itself.
  static Future<void> logTap(ProviderProfile p, String kind) async {
    if (p.isSample) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == p.uid) return;
    try {
      await _db.collection('leadTaps').add({
        'uid': uid,
        'providerUid': p.uid,
        'kind': kind,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<LeadStats> stats() async {
    final u = _user;
    if (u == null) return const LeadStats();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final quotes = await inbox();
    var taps = 0;
    try {
      final snap = await _db.collection('leadTaps').where('providerUid', isEqualTo: u.uid).limit(1000).get();
      for (final d in snap.docs) {
        final t = (d.data()['createdAt'] as Timestamp?)?.toDate();
        if (t != null && !t.isBefore(monthStart)) taps++;
      }
    } catch (_) {}
    return LeadStats(
      totalQuotes: quotes.length,
      quotesThisMonth: quotes.where((q) => q.createdAt != null && !q.createdAt!.isBefore(monthStart)).length,
      openQuotes: quotes.where((q) => q.status == QuoteStatus.newRequest || q.status == QuoteStatus.seen).length,
      tapsThisMonth: taps,
    );
  }
}
