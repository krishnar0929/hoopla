import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import '../models/provider_profile.dart';
import 'event_store.dart';

/// Customer = planning an event. Provider = offers a service.
enum UserRole { customer, provider }

/// Sign-in, the user's profile (users/{uid}) and provider listings (providers/{uid}).
///
/// Everyone starts as an anonymous guest. Signing in links the guest to a
/// real account where possible, so their event comes with them.
class AccountService {
  AccountService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get user => _auth.currentUser;
  bool get isSignedIn => user != null && !user!.isAnonymous;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _db.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _providerDoc(String uid) => _db.collection('providers').doc(uid);

  // ---------- sign in ----------

  Future<void> emailSignIn({required String email, required String password, required bool create}) async {
    final current = user;
    if (create) {
      if (current != null && current.isAnonymous) {
        await current.linkWithCredential(EmailAuthProvider.credential(email: email, password: password));
      } else {
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
      }
    } else {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    }
    await _auth.currentUser?.reload();
  }

  /// Google: browser pop-up on the web, Google's sign-in sheet on iPhone.
  Future<void> googleSignIn() async {
    final provider = GoogleAuthProvider()..addScope('email');
    if (kIsWeb) {
      final current = user;
      if (current != null && current.isAnonymous) {
        try {
          await current.linkWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' && e.credential != null) {
            await _auth.signInWithCredential(e.credential!);
          } else {
            rethrow;
          }
        }
      } else {
        await _auth.signInWithPopup(provider);
      }
    } else {
      // Without the iPhone Google client ID, Google's library crashes the app,
      // so stop here with a clear message instead.
      // Fix: flutterfire configure, then scripts/setup_google_ios.sh (see README).
      final clientId = DefaultFirebaseOptions.currentPlatform.iosClientId;
      if (defaultTargetPlatform == TargetPlatform.iOS && (clientId == null || clientId.isEmpty)) {
        throw FirebaseAuthException(
          code: 'google-not-set-up',
          message: 'Google sign-in isn\'t ready on iPhone yet. Please use Apple or email for now.',
        );
      }
      final account = await GoogleSignIn(clientId: clientId, scopes: const ['email']).signIn();
      if (account == null) throw FirebaseAuthException(code: 'canceled');
      final tokens = await account.authentication;
      final credential = GoogleAuthProvider.credential(idToken: tokens.idToken, accessToken: tokens.accessToken);
      final current = user;
      if (current != null && current.isAnonymous) {
        try {
          await current.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            await _auth.signInWithCredential(e.credential ?? credential);
          } else {
            rethrow;
          }
        }
      } else {
        await _auth.signInWithCredential(credential);
      }
    }
    await _auth.currentUser?.reload();
  }

  /// Sign in with Apple (iPhone).
  Future<void> appleSignIn() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    await _linkOrSignIn(provider);
    await _auth.currentUser?.reload();
  }

  Future<void> _linkOrSignIn(AuthProvider provider) async {
    final current = user;
    if (current != null && current.isAnonymous) {
      try {
        await current.linkWithProvider(provider);
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' && e.credential != null) {
          await _auth.signInWithCredential(e.credential!);
          return;
        }
        rethrow;
      }
    }
    await _auth.signInWithProvider(provider);
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email);

  /// Back to a fresh guest.
  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        // So the Google account chooser shows next time.
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await _auth.signOut();
    await _auth.signInAnonymously();
  }

  /// Deletes the user's events, profile, listing and login, then starts a fresh guest.
  Future<void> deleteAccount(EventStore store) async {
    final u = user;
    if (u == null || u.isAnonymous) return;
    // Firebase only deletes a login made in the last few minutes.
    final last = u.metadata.lastSignInTime;
    if (last == null || DateTime.now().difference(last) > const Duration(minutes: 4)) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    await store.deleteAll();
    await _providerDoc(u.uid).delete();
    await _userDoc(u.uid).delete();
    await u.delete();
    await _auth.signInAnonymously();
  }

  // ---------- profile ----------

  Future<Map<String, dynamic>?> loadProfile() async {
    final u = user;
    if (u == null || u.isAnonymous) return null;
    final snap = await _userDoc(u.uid).get();
    return snap.data();
  }

  /// Saves role, name and email. Never touches `premium`, which only you set.
  Future<void> saveProfile(UserRole role) async {
    final u = user;
    if (u == null || u.isAnonymous) return;
    await _userDoc(u.uid).set({
      'role': role.name,
      'email': u.email,
      'name': u.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------- free trial ----------

  /// Starts the one 3-day free trial of a plan ('basic' or 'pro').
  /// The start time comes from the server so it can't be faked.
  Future<void> startTrial(String plan) async {
    final u = user;
    if (u == null || u.isAnonymous) throw StateError('Sign in first.');
    await _userDoc(u.uid).set({
      'trialPlan': plan,
      'trialStartedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Ends the trial now. It can't be started again on this account.
  Future<void> cancelTrial() async {
    final u = user;
    if (u == null || u.isAnonymous) return;
    await _userDoc(u.uid).set({'trialCancelled': true}, SetOptions(merge: true));
  }

  // ---------- providers ----------

  Future<ProviderProfile?> loadProvider() async {
    final u = user;
    if (u == null || u.isAnonymous) return null;
    final snap = await _providerDoc(u.uid).get();
    final data = snap.data();
    return data == null ? null : ProviderProfile.fromMap(data);
  }

  Future<void> saveProvider(ProviderProfile p) async {
    await _providerDoc(p.uid).set({
      ...p.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Providers offering this service, verified ones first.
  Future<List<ProviderProfile>> findProviders(String serviceType) async {
    final snap = await _db.collection('providers').where('serviceType', isEqualTo: serviceType).limit(30).get();
    final list = [for (final d in snap.docs) ProviderProfile.fromMap(d.data())];
    list.sort((a, b) {
      if (a.verified != b.verified) return a.verified ? -1 : 1;
      return a.businessName.toLowerCase().compareTo(b.businessName.toLowerCase());
    });
    return list;
  }
}
