import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Refer a friend: each person who joins with your code gives you both
/// a week of Pro free. Weeks stack, one per friend.
///
/// Firestore:
///   refCodes/{CODE}        {uid, createdAt}            who owns a code
///   referrals/{friendUid}  {code, referrerUid, createdAt}  one per account, ever
///   users/{uid}.refCode    the person's own code
const referralBonus = Duration(days: 7);

/// Letters and digits that can't be mixed up (no 0/O, 1/I/L).
const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const codeLength = 6;

String newReferralCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(codeLength, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
}

/// "  abc-123 " → "ABC123". Null when it can't be a Hoopla code.
String? normalizeCode(String? input) {
  if (input == null) return null;
  final c = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (c.length != codeLength) return null;
  for (final ch in c.split('')) {
    if (!_alphabet.contains(ch)) return null;
  }
  return c;
}

/// The code in an invite link like https://hoopla-894ca.web.app/?ref=ABC123.
String? codeFromUri(Uri uri) => normalizeCode(uri.queryParameters['ref']);

String inviteLink(String code) => 'https://hoopla-894ca.web.app/?ref=$code';

String inviteMessage(String code) =>
    'Planning a party? I use Hoopla for the plan, the games and finding helpers nearby. '
    'It\'s free! Join with my code $code: ${inviteLink(code)}';

/// When the free Pro runs out, given the dates each bonus week was earned.
/// Weeks earned while one is still running are added on the end.
DateTime? bonusEnd(Iterable<DateTime> grants, {Duration per = referralBonus}) {
  final sorted = grants.toList()..sort();
  DateTime? end;
  for (final g in sorted) {
    final start = (end != null && end.isAfter(g)) ? end : g;
    end = start.add(per);
  }
  return end;
}

class ReferralStatus {
  const ReferralStatus({this.code, this.friendsJoined = 0, this.usedCode, this.bonusUntil});

  /// This person's own code (null until it's made).
  final String? code;

  /// How many friends joined with the code.
  final int friendsJoined;

  /// The friend's code this person joined with, if any.
  final String? usedCode;

  /// Free Pro lasts until this time.
  final DateTime? bonusUntil;
}

class ReferralError implements Exception {
  ReferralError(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReferralService {
  ReferralService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get _user {
    final u = _auth.currentUser;
    return (u == null || u.isAnonymous) ? null : u;
  }

  /// The person's code, made the first time it's asked for.
  Future<String> ensureCode() async {
    final u = _user;
    if (u == null) throw ReferralError('Sign in to get your invite code.');
    final userRef = _db.collection('users').doc(u.uid);
    final existing = (await userRef.get()).data()?['refCode'];
    if (existing is String && existing.isNotEmpty) return existing;

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = newReferralCode();
      final codeRef = _db.collection('refCodes').doc(code);
      final made = await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(codeRef);
        if (snap.exists) return false;
        tx.set(codeRef, {'uid': u.uid, 'createdAt': FieldValue.serverTimestamp()});
        return true;
      });
      if (made) {
        await userRef.set({'refCode': code}, SetOptions(merge: true));
        return code;
      }
    }
    throw ReferralError('Could not make a code. Please try again.');
  }

  /// Joins with a friend's code. Throws [ReferralError] with a friendly message.
  Future<void> redeem(String input) async {
    final u = _user;
    if (u == null) throw ReferralError('Sign in first, then enter the code.');
    final code = normalizeCode(input);
    if (code == null) throw ReferralError('Codes are 6 letters and numbers, like K7Q2MX.');

    final mine = _db.collection('referrals').doc(u.uid);
    if ((await mine.get()).exists) throw ReferralError('You\'ve already used a friend\'s code on this account.');

    final owner = (await _db.collection('refCodes').doc(code).get()).data()?['uid'];
    if (owner is! String) throw ReferralError('We couldn\'t find that code. Check it and try again.');
    if (owner == u.uid) throw ReferralError('That\'s your own code. Share it with a friend instead!');

    await mine.set({'code': code, 'referrerUid': owner, 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<ReferralStatus> load() async {
    final u = _user;
    if (u == null) return const ReferralStatus();
    final profile = (await _db.collection('users').doc(u.uid).get()).data();
    final mine = (await _db.collection('referrals').doc(u.uid).get()).data();
    final friends = await _db.collection('referrals').where('referrerUid', isEqualTo: u.uid).limit(200).get();

    final grants = <DateTime>[];
    final myDate = mine?['createdAt'];
    if (myDate is Timestamp) grants.add(myDate.toDate());
    for (final d in friends.docs) {
      final t = d.data()['createdAt'];
      if (t is Timestamp) grants.add(t.toDate());
    }
    final code = profile?['refCode'];
    return ReferralStatus(
      code: code is String ? code : null,
      friendsJoined: friends.docs.length,
      usedCode: mine?['code'] as String?,
      bonusUntil: bonusEnd(grants),
    );
  }
}
