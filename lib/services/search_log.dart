import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Records searches and filter choices in the `search_logs` collection.
///
/// Each entry has: uid, type, query, filters, device, appVersion, ip, createdAt.
/// It goes through the `logSearch` Cloud Function so the IP address can be
/// added. If the function isn't deployed yet, the entry is written straight
/// to Firestore without the IP.
class SearchLog {
  SearchLog._();
  static final instance = SearchLog._();

  /// Turned on in main.dart once Firebase is connected.
  bool enabled = false;

  Map<String, Object?>? _device;
  String? _appVersion;
  bool _functionMissing = false;

  Future<void> log(String type, {String? query, Map<String, Object?> filters = const {}}) async {
    if (!enabled) return;
    try {
      await _loadDeviceOnce();
      final entry = <String, Object?>{
        'type': type,
        'query': query,
        'filters': filters,
        'device': _device,
        'appVersion': _appVersion,
      };

      if (!_functionMissing) {
        try {
          await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('logSearch').call(entry);
          return;
        } on FirebaseFunctionsException catch (e) {
          // not-found / unavailable / internal = function not deployed yet.
          if (e.code == 'invalid-argument' || e.code == 'unauthenticated') rethrow;
          _functionMissing = true;
        }
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('search_logs').add({
        ...entry,
        'uid': uid,
        'ip': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Search log not saved: $e');
    }
  }

  Future<void> _loadDeviceOnce() async {
    if (_device != null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _appVersion = null;
    }

    final plugin = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final w = await plugin.webBrowserInfo;
        _device = {
          'platform': 'web',
          'name': w.browserName.name,
          'model': w.platform ?? '',
          'userAgent': w.userAgent ?? '',
        };
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await plugin.iosInfo;
        _device = {
          'platform': 'ios',
          'name': i.name,
          'model': i.utsname.machine,
          'osVersion': i.systemVersion,
        };
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final a = await plugin.androidInfo;
        _device = {
          'platform': 'android',
          'name': '${a.manufacturer} ${a.model}',
          'model': a.model,
          'osVersion': a.version.release,
        };
      } else {
        _device = {'platform': defaultTargetPlatform.name};
      }
    } catch (_) {
      _device = {'platform': kIsWeb ? 'web' : defaultTargetPlatform.name};
    }
  }
}
