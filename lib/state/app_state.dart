import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/event_details.dart';
import '../services/event_store.dart';
import '../services/plan_generator.dart';

/// Holds the current event and saves every change.
class AppState extends ChangeNotifier {
  AppState(this.store, {this.usingCloud = false});

  final EventStore store;

  /// True when events sync to Firebase, false when saved on this device only.
  final bool usingCloud;

  EventDetails? event;

  Plan get plan => PlanGenerator.build(event!);

  Future<void> load() async {
    try {
      event = await store.loadLatest();
    } catch (e) {
      debugPrint('Could not load saved event: $e');
    }
  }

  Future<void> saveEvent(EventDetails e) async {
    e.updatedAt = DateTime.now();
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

  Future<void> _persist(EventDetails e) async {
    try {
      await store.save(e);
    } catch (err) {
      debugPrint('Could not save event: $err');
    }
  }
}

/// Makes [AppState] available to every screen.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
