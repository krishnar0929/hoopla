import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_details.dart';
import '../models/provider_profile.dart';
import '../services/account_service.dart';
import '../services/event_store.dart';
import '../services/plan_generator.dart';

/// What the person can see: guest (no account), member (free account) or premium (any paid plan).
enum Access { guest, member, premium }

/// Subscription plans, lowest to highest. Each includes everything below it.
enum Tier { free, basic, pro }

extension TierLabel on Tier {
  String get label => switch (this) {
        Tier.free => 'Free',
        Tier.basic => 'Basic',
        Tier.pro => 'Pro',
      };
}

/// Holds the events, the signed-in account, and saves every change.
class AppState extends ChangeNotifier {
  AppState(this.store, {this.usingCloud = false, this.accounts});

  final EventStore store;

  /// True when events sync to Firebase, false when saved on this device only.
  final bool usingCloud;

  /// Sign-in and profiles. Null when Firebase isn't set up.
  final AccountService? accounts;

  /// All events, newest first.
  List<EventDetails> events = [];

  /// The event on screen.
  EventDetails? event;

  /// users/{uid}: role, email, premium.
  Map<String, dynamic>? profile;

  /// providers/{uid} when the user is a provider.
  ProviderProfile? provider;

  /// Test switch for plans. Only works in debug builds.
  Tier? devTier;
  static const _devTierKey = 'hoopla.devTier';

  Plan get plan => PlanGenerator.build(event!);

  List<EventDetails> get activeEvents => [for (final e in events) if (e.isActive) e];
  List<EventDetails> get cancelledEvents => [for (final e in events) if (!e.isActive) e];

  bool get isSignedIn => accounts?.isSignedIn ?? false;
  String? get email => accounts?.user?.email;

  UserRole get role => profile?['role'] == 'provider' ? UserRole.provider : UserRole.customer;
  bool get isProvider => isSignedIn && role == UserRole.provider;

  /// The plan from users/{uid}.plan ('basic' or 'pro'), set by you or later by payments.
  Tier get tier {
    if (kDebugMode && devTier != null) return devTier!;
    if (!isSignedIn) return Tier.free;
    final name = profile?['plan'];
    for (final t in Tier.values) {
      if (t.name == name) return t;
    }
    // Older values from earlier test builds.
    if (name == 'host' || profile?['premium'] == true) return Tier.pro;
    return Tier.free;
  }

  bool atLeast(Tier t) => tier.index >= t.index;

  bool get isPremium => atLeast(Tier.basic);

  Access get access {
    if (isPremium) return Access.premium;
    return isSignedIn ? Access.member : Access.guest;
  }

  /// Free plans keep one active event at a time.
  bool get canAddEvent => access == Access.premium || activeEvents.isEmpty;

  // ---------- loading ----------

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_devTierKey);
      for (final t in Tier.values) {
        if (t.name == saved) devTier = t;
      }
    } catch (_) {}
    await _loadAccount();
    await _loadEvents();
  }

  Future<void> _loadAccount() async {
    profile = null;
    provider = null;
    final a = accounts;
    if (a == null || !a.isSignedIn) return;
    try {
      profile = await a.loadProfile();
      if (role == UserRole.provider) provider = await a.loadProvider();
    } catch (e) {
      debugPrint('Could not load account: $e');
    }
  }

  Future<void> _loadEvents({String? preferId}) async {
    try {
      events = await store.loadAll();
    } catch (e) {
      debugPrint('Could not load events: $e');
      events = [];
    }
    EventDetails? pick;
    for (final e in events) {
      if (e.isActive && (preferId == null || e.id == preferId)) {
        pick = e;
        break;
      }
    }
    final active = activeEvents;
    pick ??= active.isEmpty ? null : active.first;
    event = pick;
  }

  // ---------- events ----------

  Future<void> saveEvent(EventDetails e) async {
    e.updatedAt = DateTime.now();
    events.removeWhere((x) => x.id == e.id);
    events.insert(0, e);
    event = e;
    notifyListeners();
    await _persist(e);
  }

  /// Change the current event in place, then save it.
  Future<void> update(void Function(EventDetails e) change) async {
    final e = event;
    if (e == null) return;
    change(e);
    e.updatedAt = DateTime.now();
    notifyListeners();
    await _persist(e);
  }

  void switchTo(String id) {
    for (final e in events) {
      if (e.id == id) {
        event = e;
        break;
      }
    }
    notifyListeners();
  }

  /// Moves an event to Cancelled. Shows the next active event, or the setup screen.
  Future<void> cancelEvent(String id) async {
    EventDetails? target;
    for (final e in events) {
      if (e.id == id) target = e;
    }
    if (target == null) return;
    target.status = 'cancelled';
    target.updatedAt = DateTime.now();
    if (event?.id == id) {
      final rest = activeEvents;
      event = rest.isEmpty ? null : rest.first;
    }
    notifyListeners();
    await _persist(target);
  }

  Future<void> restoreEvent(String id) async {
    for (final e in events) {
      if (e.id == id) {
        e.status = 'active';
        await saveEvent(e);
        return;
      }
    }
  }

  Future<void> _persist(EventDetails e) async {
    try {
      await store.save(e);
    } catch (err) {
      debugPrint('Could not save event: $err');
    }
  }

  // ---------- account ----------

  /// Call after a successful sign-in. Saves the role and keeps the guest's events.
  Future<void> afterSignIn(UserRole chosen, List<EventDetails> carry) async {
    final a = accounts;
    if (a == null) return;
    try {
      final existing = await a.loadProfile();
      // A provider signing in from the customer side stays a provider.
      final keepProvider = existing?['role'] == 'provider' && chosen == UserRole.customer;
      await a.saveProfile(keepProvider ? UserRole.provider : chosen);
    } catch (e) {
      debugPrint('Could not save profile: $e');
    }
    final preferId = event?.id;
    for (final e in carry) {
      await _persist(e);
    }
    await _loadAccount();
    await _loadEvents(preferId: preferId);
    notifyListeners();
  }

  Future<void> setRole(UserRole r) async {
    final a = accounts;
    if (a == null) return;
    try {
      await a.saveProfile(r);
    } catch (e) {
      debugPrint('Could not change role: $e');
    }
    await _loadAccount();
    notifyListeners();
  }

  Future<void> saveProvider(ProviderProfile p) async {
    final a = accounts!;
    await a.saveProvider(p);
    provider = await a.loadProvider();
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await accounts?.signOut();
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
    profile = null;
    provider = null;
    await _loadEvents();
    notifyListeners();
  }

  /// Returns an error message, or null when the account was deleted.
  Future<String?> deleteAccount() async {
    final a = accounts;
    if (a == null) return 'Not signed in.';
    try {
      await a.deleteAccount(store);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'For your security, sign out, sign in again, then delete your account.';
      }
      return e.message ?? e.code;
    } catch (e) {
      return 'Could not delete: $e';
    }
    profile = null;
    provider = null;
    await _loadEvents();
    notifyListeners();
    return null;
  }

  /// Debug builds only: pretend to be on a plan for testing (null = use the real plan).
  Future<void> setDevTier(Tier? t) async {
    devTier = t;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (t == null) {
        await prefs.remove(_devTierKey);
      } else {
        await prefs.setString(_devTierKey, t.name);
      }
    } catch (_) {}
  }
}

/// Makes [AppState] available to every screen.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
