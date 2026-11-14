import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/event_details.dart';

/// Someone the host invited (from contacts, or typed in).
class Invitee {
  Invitee({required this.name, this.phone = '', this.email = '', DateTime? addedAt}) : addedAt = addedAt ?? DateTime.now();
  final String name;
  final String phone;
  final String email;
  final DateTime addedAt;

  String get phoneDigits => phone.replaceAll(RegExp(r'[^0-9+]'), '');
  String get key => phoneDigits.isNotEmpty ? phoneDigits : email.toLowerCase();

  Map<String, dynamic> toMap() => {'name': name, 'phone': phone, 'email': email, 'addedAt': addedAt.toIso8601String()};

  factory Invitee.fromMap(Map<String, dynamic> m) => Invitee(
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        email: m['email'] as String? ?? '',
        addedAt: DateTime.tryParse(m['addedAt'] as String? ?? ''),
      );
}

/// Turns pasted text ("Priya 732-555-0100, sam@x.com; +91 98480 12345") into invitees.
List<Invitee> parseInvitees(String text) {
  final out = <Invitee>[];
  for (final raw in text.split(RegExp(r'[,;\n]+'))) {
    final part = raw.trim();
    if (part.isEmpty) continue;
    final email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+').firstMatch(part)?.group(0);
    final phoneMatch = RegExp(r'\+?\d[\d\s().-]{6,}\d').firstMatch(part)?.group(0);
    if (email == null && phoneMatch == null) continue;
    var name = part;
    if (email != null) name = name.replaceAll(email, '');
    if (phoneMatch != null) name = name.replaceAll(phoneMatch, '');
    name = name.replaceAll(RegExp(r'[<>()"]'), '').trim();
    out.add(Invitee(name: name.isEmpty ? (email ?? phoneMatch!.trim()) : name, phone: phoneMatch?.trim() ?? '', email: email ?? ''));
  }
  return out;
}

enum RsvpStatus { going, maybe, no }

extension RsvpStatusLabel on RsvpStatus {
  String get label => switch (this) {
        RsvpStatus.going => 'Going',
        RsvpStatus.maybe => 'Maybe',
        RsvpStatus.no => 'Can\'t go',
      };
  String get emoji => switch (this) {
        RsvpStatus.going => '🎉',
        RsvpStatus.maybe => '🤔',
        RsvpStatus.no => '😢',
      };
}

class Rsvp {
  const Rsvp({required this.uid, required this.name, required this.status, this.adults = 1, this.kids = 0, this.note = '', this.updatedAt});
  final String uid;
  final String name;
  final RsvpStatus status;
  final int adults;
  final int kids;
  final String note;
  final DateTime? updatedAt;

  int get people => status == RsvpStatus.no ? 0 : adults + kids;

  factory Rsvp.fromDoc(String uid, Map<String, dynamic> m) => Rsvp(
        uid: uid,
        name: m['name'] as String? ?? 'Guest',
        status: RsvpStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => RsvpStatus.maybe),
        adults: (m['adults'] as num?)?.toInt() ?? 1,
        kids: (m['kids'] as num?)?.toInt() ?? 0,
        note: m['note'] as String? ?? '',
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      );
}

/// Headcount from RSVPs.
class RsvpSummary {
  const RsvpSummary({this.going = 0, this.maybe = 0, this.no = 0, this.adults = 0, this.kids = 0});
  final int going;
  final int maybe;
  final int no;

  /// People coming (adults + kids of "Going" replies).
  final int adults;
  final int kids;
  int get people => adults + kids;
  int get replies => going + maybe + no;

  factory RsvpSummary.of(List<Rsvp> list) {
    var g = 0, m = 0, n = 0, a = 0, k = 0;
    for (final r in list) {
      switch (r.status) {
        case RsvpStatus.going:
          g++;
          a += r.adults;
          k += r.kids;
        case RsvpStatus.maybe:
          m++;
        case RsvpStatus.no:
          n++;
      }
    }
    return RsvpSummary(going: g, maybe: m, no: n, adults: a, kids: k);
  }
}

/// The public invite guests open from the link (invites/{hostUid}_{eventId}).
class InviteInfo {
  const InviteInfo({
    required this.id,
    required this.hostUid,
    required this.hostName,
    required this.title,
    required this.occasion,
    required this.date,
    required this.startMinutes,
    required this.hours,
    required this.venue,
    required this.venueAddress,
    required this.message,
    this.lat,
    this.lng,
  });

  final String id;
  final String hostUid;
  final String hostName;
  final String title;
  final String occasion;
  final DateTime date;
  final int startMinutes;
  final int hours;
  final String venue;
  final String venueAddress;
  final String message;
  final double? lat;
  final double? lng;

  DateTime get start => DateTime(date.year, date.month, date.day).add(Duration(minutes: startMinutes));
  DateTime get end => start.add(Duration(hours: hours));

  String get whenLabel =>
      '${DateFormat('EEEE, MMMM d').format(date)} · ${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}';

  Uri? get mapUrl {
    final where = venueAddress.isNotEmpty ? venueAddress : venue;
    if (where.isEmpty && lat == null) return null;
    return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': lat != null ? '$lat,$lng' : where});
  }

  /// "Add to Google Calendar" link (local time, so it shows at the party's time).
  Uri get googleCalendarUrl {
    String t(DateTime d) => DateFormat("yyyyMMdd'T'HHmmss").format(d);
    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title,
      'dates': '${t(start)}/${t(end)}',
      'details': '${message.isEmpty ? '' : '$message\n\n'}Invited by $hostName on Hoopla',
      'location': venueAddress.isNotEmpty ? venueAddress : venue,
    });
  }

  factory InviteInfo.fromDoc(String id, Map<String, dynamic> m) => InviteInfo(
        id: id,
        hostUid: m['hostUid'] as String? ?? '',
        hostName: m['hostName'] as String? ?? 'Your host',
        title: m['title'] as String? ?? 'A party',
        occasion: m['occasion'] as String? ?? '',
        date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
        startMinutes: (m['startMinutes'] as num?)?.toInt() ?? 0,
        hours: (m['hours'] as num?)?.toInt() ?? 3,
        venue: m['venue'] as String? ?? '',
        venueAddress: m['venueAddress'] as String? ?? '',
        message: m['message'] as String? ?? '',
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );
}

String inviteIdFor(String hostUid, String eventId) => '${hostUid}_$eventId';

String inviteUrl(String inviteId) => 'https://hoopla-894ca.web.app/?invite=$inviteId';

/// The text sent with every invite.
String inviteText(EventDetails e, String url, {String hostName = '', String message = ''}) {
  final when = '${DateFormat('EEE, MMM d').format(e.date)} at ${DateFormat('h:mm a').format(DateTime(2000, 1, 1, e.startMinutes ~/ 60, e.startMinutes % 60))}';
  final where = e.venue == null ? '' : '\n📍 ${e.venue!.address.isNotEmpty ? e.venue!.address : e.venue!.label}';
  return [
    '🎉 You\'re invited: ${e.title}!',
    '🗓 $when$where',
    if (message.trim().isNotEmpty) '\n${message.trim()}',
    '\nPlease RSVP here: $url',
    if (hostName.isNotEmpty) '— $hostName',
  ].join('\n');
}

class InviteService {
  InviteService._();

  static final _db = FirebaseFirestore.instance;
  static DocumentReference<Map<String, dynamic>> _doc(String id) => _db.collection('invites').doc(id);

  /// Creates or updates the public invite for an event. Returns its id.
  static Future<String> publish(EventDetails e, {required String hostName, required String message}) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null || u.isAnonymous) throw StateError('Sign in to send invites.');
    final id = inviteIdFor(u.uid, e.id);
    await _doc(id).set({
      'hostUid': u.uid,
      'eventId': e.id,
      'hostName': hostName,
      'title': e.title,
      'occasion': e.occasion,
      'date': DateFormat('yyyy-MM-dd').format(e.date),
      'startMinutes': e.startMinutes,
      'hours': e.hours,
      'venue': e.venue?.label ?? '',
      'venueAddress': e.venue?.address ?? '',
      'lat': e.venue?.lat,
      'lng': e.venue?.lng,
      'message': message.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  static Future<InviteInfo?> load(String id) async {
    final snap = await _doc(id).get();
    final data = snap.data();
    return data == null ? null : InviteInfo.fromDoc(id, data);
  }

  /// Every reply, newest first (host only).
  static Future<List<Rsvp>> rsvps(String inviteId) async {
    final snap = await _doc(inviteId).collection('rsvps').limit(500).get();
    final list = [for (final d in snap.docs) Rsvp.fromDoc(d.id, d.data())];
    list.sort((a, b) => (b.updatedAt ?? DateTime(2100)).compareTo(a.updatedAt ?? DateTime(2100)));
    return list;
  }

  /// This device's own reply, if any.
  static Future<Rsvp?> mine(String inviteId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final d = await _doc(inviteId).collection('rsvps').doc(uid).get();
      return d.exists ? Rsvp.fromDoc(uid, d.data()!) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> reply(String inviteId, {required String name, required RsvpStatus status, int adults = 1, int kids = 0, String note = ''}) async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      await FirebaseAuth.instance.signInAnonymously();
      uid = FirebaseAuth.instance.currentUser!.uid;
    }
    await _doc(inviteId).collection('rsvps').doc(uid).set({
      'name': name.trim(),
      'status': status.name,
      'adults': status == RsvpStatus.no ? 0 : adults,
      'kids': status == RsvpStatus.no ? 0 : kids,
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Text-message link to many numbers at once (iPhone and Android differ).
  static Uri smsTo(List<String> numbers, String body) {
    final list = numbers.where((n) => n.isNotEmpty).toList();
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (ios) {
      if (list.length <= 1) return Uri.parse('sms:${list.isEmpty ? '' : list.first}&body=${Uri.encodeComponent(body)}');
      return Uri.parse('sms:/open?addresses=${list.join(',')}&body=${Uri.encodeComponent(body)}');
    }
    return Uri.parse('sms:${list.join(';')}?body=${Uri.encodeComponent(body)}');
  }

  /// Email to many people at once (BCC, so guests don't see each other's addresses).
  static Uri emailTo(List<String> emails, String subject, String body) => Uri(
        scheme: 'mailto',
        query: [
          if (emails.isNotEmpty) 'bcc=${emails.join(',')}',
          'subject=${Uri.encodeComponent(subject)}',
          'body=${Uri.encodeComponent(body)}',
        ].join('&'),
      );
}
