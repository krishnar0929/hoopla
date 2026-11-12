import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_details.dart';

/// Where events are saved. Firestore when Firebase is set up,
/// otherwise on the device so the app still works offline.
abstract class EventStore {
  /// All events, newest first (active and cancelled).
  Future<List<EventDetails>> loadAll();
  Future<void> save(EventDetails event);

  /// Removes every event (used when an account is deleted).
  Future<void> deleteAll();
}

/// Saves each user's events at users/{uid}/events/{eventId}.
class FirestoreEventStore implements EventStore {
  FirestoreEventStore({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _events {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    return _db.collection('users').doc(uid).collection('events');
  }

  @override
  Future<List<EventDetails>> loadAll() async {
    final snap = await _events.orderBy('updatedAt', descending: true).limit(50).get();
    return [for (final d in snap.docs) EventDetails.fromMap(d.data())];
  }

  @override
  Future<void> save(EventDetails event) => _events.doc(event.id).set(event.toMap());

  @override
  Future<void> deleteAll() async {
    final snap = await _events.get();
    for (final d in snap.docs) {
      await d.reference.delete();
    }
  }
}

/// Keeps events on this device.
class LocalEventStore implements EventStore {
  static const _key = 'hoopla.events';
  static const _oldKey = 'hoopla.latestEvent';

  @override
  Future<List<EventDetails>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = <EventDetails>[];
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        for (final item in jsonDecode(raw) as List) {
          list.add(EventDetails.fromMap(Map<String, dynamic>.from(item as Map)));
        }
      } catch (_) {}
    } else {
      // Bring over the single event saved by the first version.
      final old = prefs.getString(_oldKey);
      if (old != null) {
        try {
          list.add(EventDetails.fromMap(Map<String, dynamic>.from(jsonDecode(old) as Map)));
        } catch (_) {}
      }
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<void> save(EventDetails event) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == event.id);
    all.insert(0, event);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final e in all) e.toMap()]));
  }

  @override
  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_oldKey);
  }
}
