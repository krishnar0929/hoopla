import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_details.dart';
import '../models/provider_profile.dart';
import '../services/account_service.dart';
import '../services/event_store.dart';
import '../services/plan_generator.dart';
import '../services/referrals.dart';
import '../services/reminder_plan.dart';
import '../services/reminders.dart';

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
  AppState(this.store, {this.usingCloud = false, this.accounts, this.referrals});

  final EventStore store;

  /// True when events sync to Firebase, false when saved on this device only.
  final bool usingCloud;

  /// Sign-in and profiles. Null when Firebase isn't set up.
  final AccountService? accounts;

  /// Refer a friend. Null when Firebase isn't set up.
  final ReferralService? referrals;

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
    final paid = paidTier;
    if (onReferralBonus) return Tier.pro;
    if (onTrial && trialTier.index > paid.index) return trialTier;
    return paid;
  }

  /// The plan that's paid for (set in users/{uid}.plan).
  Tier get paidTier {
    if (!isSignedIn) return Tier.free;
    final name = profile?['plan'];
    for (final t in Tier.values) {
      if (t.name == name) return t;
    }
    // Older values from earlier test builds.
    if (name == 'host' || profile?['premium'] == true) return Tier.pro;
    return Tier.free;
  }

  // ---------- 3-day free trial ----------

  static const trialLength = Duration(days: 3);

  /// True once this account has started its one free trial.
  bool get trialUsed => isSignedIn && profile?['trialStartedAt'] != null;

  Tier get trialTier => profile?['trialPlan'] == 'pro' ? Tier.pro : Tier.basic;

  DateTime? get trialEndsAt {
    final started = profile?['trialStartedAt'];
    if (started is Timestamp) return started.toDate().add(trialLength);
    return null;
  }

  bool get onTrial {
    final ends = trialEndsAt;
    return isSignedIn && ends != null && profile?['trialCancelled'] != true && DateTime.now().isBefore(ends);
  }

  /// The trial ran out (or was cancelled) and no plan is paid for.
  bool get trialEnded => trialUsed && !onTrial && paidTier == Tier.free;

  Future<void> startTrial(Tier t) async {
    final a = accounts;
    if (a == null) return;
    await a.startTrial(t.name);
    await _loadAccount();
    notifyListeners();
  }

  Future<void> cancelTrial() async {
    final a = accounts;
    if (a == null) return;
    await a.cancelTrial();
    await _loadAccount();
    notifyListeners();
  }

  // ---------- refer a friend ----------

  /// Your code, friends who joined, and free Pro earned.
  ReferralStatus referral = const ReferralStatus();

  /// A friend's code typed (or opened from a ?ref= link) before signing in.
  String? pendingRefCode;
  static const _pendingRefKey = 'hoopla.pendingRefCode';

  /// A message to show once after sign-in applied a friend's code.
  String? _referralNotice;

  DateTime? get bonusProUntil => referral.bonusUntil;

  bool get onReferralBonus {
    final until = bonusProUntil;
    return isSignedIn && until != null && DateTime.now().isBefore(until);
  }

  Future<void> setPendingRefCode(String? code) async {
    pendingRefCode = normalizeCode(code);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pendingRefCode == null) {
        await prefs.remove(_pendingRefKey);
      } else {
        await prefs.setString(_pendingRefKey, pendingRefCode!);
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Your invite code, made the first time.
  Future<String> ensureRefCode() async {
    final r = referrals;
    if (r == null) throw ReferralError('Invites need an internet connection.');
    final code = await r.ensureCode();
    if (referral.code != code) await _loadReferral();
    notifyListeners();
    return code;
  }

  /// Joins with a friend's code. Returns an error message, or null when it worked.
  Future<String?> redeemCode(String code) async {
    final r = referrals;
    if (r == null) return 'Invites need an internet connection.';
    try {
      await r.redeem(code);
    } on ReferralError catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not apply the code. Please try again.';
    }
    await _loadReferral();
    notifyListeners();
    return null;
  }

  /// The message from applying a saved friend's code at sign-in (shown once).
  String? takeReferralNotice() {
    final n = _referralNotice;
    _referralNotice = null;
    return n;
  }

  Future<void> _loadReferral() async {
    final r = referrals;
    if (r == null || !isSignedIn) {
      referral = const ReferralStatus();
      return;
    }
    try {
      referral = await r.load();
    } catch (e) {
      debugPrint('Could not load referrals: $e');
    }
  }

  // ---------- reminders (free for everyone, phone app only) ----------

  /// null = never asked, true = on, false = turned off.
  bool? remindersEnabled;

  /// Hour of the day task reminders arrive (9 = 9 AM).
  int remindHour = 9;
  static const _remindersKey = 'hoopla.reminders';
  static const _remindHourKey = 'hoopla.remindHour';
  Timer? _reminderSync;

  bool get remindersOn => Reminders.supported && remindersEnabled == true;

  /// Turns reminders on (asking the phone for permission) or off.
  /// Returns false when the phone said no.
  Future<bool> setReminders(bool on) async {
    var ok = true;
    if (on) ok = await Reminders.requestPermission();
    remindersEnabled = on && ok;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_remindersKey, remindersEnabled!);
    } catch (_) {}
    notifyListeners();
    return ok;
  }

  Future<void> setRemindHour(int h) async {
    remindHour = h.clamp(0, 23);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_remindHourKey, remindHour);
    } catch (_) {}
    notifyListeners();
  }

  /// Every change to events reschedules the reminders (once things settle).
  @override
  void notifyListeners() {
    super.notifyListeners();
    _reminderSync?.cancel();
    _reminderSync = Timer(const Duration(milliseconds: 700), syncReminders);
  }

  Future<void> syncReminders() async {
    if (!Reminders.supported) return;
    if (!remindersOn) {
      await Reminders.cancelAll();
      return;
    }
    final now = DateTime.now();
    final all = <ReminderSpec>[
      for (final e in activeEvents) ...planReminders(e: e, tasks: PlanGenerator.build(e).tasks, now: now, hour: remindHour),
    ];
    await Reminders.replaceAll(all);
  }

  bool atLeast(Tier t) => tier.index >= t.index;

  bool get isPremium => atLeast(Tier.basic);

  Access get access {
    if (isPremium) return Access.premium;
    return isSignedIn ? Access.member : Access.guest;
  }

  /// Hoopla is free for people planning events. Providers will pay for visibility and
  /// leads instead. Paid user plans (Basic/Pro) stay in the code, switched off here.
  static const userPlansEnabled = false;

  /// Guests keep one event at a time; a free account has no limit.
  bool get canAddEvent => isSignedIn || activeEvents.isEmpty || (userPlansEnabled && access == Access.premium);

  // ---------- loading ----------

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_devTierKey);
      for (final t in Tier.values) {
        if (t.name == saved) devTier = t;
      }
      pendingRefCode = normalizeCode(prefs.getString(_pendingRefKey));
      remindersEnabled = prefs.getBool(_remindersKey);
      remindHour = prefs.getInt(_remindHourKey) ?? 9;
      final raw = prefs.getString(_pendingReelsKey);
      if (raw != null) {
        pendingReels = [
          for (final m in jsonDecode(raw) as List) SavedLink.fromMap(Map<String, dynamic>.from(m as Map)),
        ];
      }
    } catch (_) {}
    await _loadAccount();
    await _loadEvents();
    unawaited(syncReminders());
  }

  // ---------- saved reels (free for everyone) ----------

  /// Reels saved before there is an event; they join the next event created.
  List<SavedLink> pendingReels = [];
  static const _pendingReelsKey = 'hoopla.pendingReels';

  /// Saves reels to the current event (or keeps them until one exists).
  /// Returns how many were new.
  Future<int> addReels(List<SavedLink> reels) async {
    if (reels.isEmpty) return 0;
    final e = event;
    final existing = {for (final l in e?.savedLinks ?? pendingReels) l.url};
    final fresh = [for (final r in reels) if (existing.add(r.url)) r];
    if (fresh.isEmpty) return 0;
    if (e != null) {
      await update((ev) => ev.savedLinks.insertAll(0, fresh));
    } else {
      pendingReels = [...fresh, ...pendingReels];
      notifyListeners();
      await _savePendingReels();
    }
    return fresh.length;
  }

  Future<void> _savePendingReels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pendingReels.isEmpty) {
        await prefs.remove(_pendingReelsKey);
      } else {
        await prefs.setString(_pendingReelsKey, jsonEncode([for (final l in pendingReels) l.toMap()]));
      }
    } catch (_) {}
  }

  Future<void> _loadAccount() async {
    profile = null;
    provider = null;
    referral = const ReferralStatus();
    final a = accounts;
    if (a == null || !a.isSignedIn) return;
    try {
      profile = await a.loadProfile();
      if (role == UserRole.provider) provider = await a.loadProvider();
    } catch (e) {
      debugPrint('Could not load account: $e');
    }
    await _loadReferral();
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
    if (pendingReels.isNotEmpty) {
      final have = {for (final l in e.savedLinks) l.url};
      e.savedLinks.insertAll(0, [for (final l in pendingReels) if (have.add(l.url)) l]);
      pendingReels = [];
      await _savePendingReels();
    }
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
    final code = pendingRefCode;
    if (code != null && referral.usedCode == null) {
      final err = await redeemCode(code);
      _referralNotice = err ?? 'Friend\'s code applied. Welcome to Hoopla! 🎉';
    }
    if (code != null) await setPendingRefCode(null);
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
    referral = const ReferralStatus();
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
    referral = const ReferralStatus();
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
