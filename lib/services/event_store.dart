import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_details.dart';

/// Where events are saved. Firestore when Firebase is set up,
/// otherwise on the device so the app still works offline.
abstract class EventStore {
  Future<EventDetails?> loadLatest();
  Future<void> save(EventDetails event);
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
  Future<EventDetails?> loadLatest() async {
    final snap = await _events.orderBy('updatedAt', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return EventDetails.fromMap(snap.docs.first.data());
  }

  @override
  Future<void> save(EventDetails event) => _events.doc(event.id).set(event.toMap());
}

/// Keeps the latest event on this device.
class LocalEventStore implements EventStore {
  static const _key = 'hoopla.latestEvent';

  @override
  Future<EventDetails?> loadLatest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return EventDetails.fromMap(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(EventDetails event) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(event.toMap()));
  }
}
