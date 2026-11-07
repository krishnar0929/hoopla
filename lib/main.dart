import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_shell.dart';
import 'screens/setup_screen.dart';
import 'services/event_store.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use Firebase when it's set up (run `flutterfire configure`);
  // otherwise keep events on this device so the app still works.
  EventStore store;
  var cloud = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
    store = FirestoreEventStore();
    cloud = true;
  } catch (e) {
    debugPrint('Firebase not set up yet, saving on this device: $e');
    store = LocalEventStore();
  }

  final state = AppState(store, usingCloud: cloud);
  await state.load();
  runApp(HooplaApp(state: state));
}

class HooplaApp extends StatelessWidget {
  const HooplaApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Hoopla',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: state.event == null ? const SetupScreen() : const HomeShell(),
        ),
      ),
    );
  }
}
