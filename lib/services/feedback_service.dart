import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Where people reach the Hoopla team.
const supportEmail = 'northbitapps@gmail.com';
const appStoreId = '6831895941';
const appStoreUrl = 'https://apps.apple.com/app/id$appStoreId';

enum FeedbackType { idea, problem, praise, other }

extension FeedbackTypeLabel on FeedbackType {
  String get label => switch (this) {
        FeedbackType.idea => 'Idea',
        FeedbackType.problem => 'Problem',
        FeedbackType.praise => 'Praise',
        FeedbackType.other => 'Other',
      };
}

/// Saves feedback to the `feedback` collection. Read it in the Firebase console.
/// The app can add feedback but never read, change or delete it.
class FeedbackService {
  static Future<void> send({
    required FeedbackType type,
    required int rating,
    required String message,
    String? email,
    String? plan,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not connected.');
    var version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    await FirebaseFirestore.instance.collection('feedback').add({
      'uid': uid,
      'type': type.name,
      'rating': rating,
      'message': message.trim(),
      'email': (email == null || email.trim().isEmpty) ? null : email.trim(),
      'plan': plan,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'appVersion': version,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// mailto: link for "Email us", with the app version filled in.
  static Uri mailto({String subject = 'Hoopla help', String body = ''}) =>
      Uri(scheme: 'mailto', path: supportEmail, query: _query({'subject': subject, 'body': body}));

  static String _query(Map<String, String> params) => params.entries
      .where((e) => e.value.isNotEmpty)
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
}
