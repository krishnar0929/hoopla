import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_shell.dart';
import 'screens/provider_home_screen.dart';
import 'screens/provider_setup_screen.dart';
import 'screens/setup_screen.dart';
import 'services/account_service.dart';
import 'services/event_store.dart';
import 'services/referrals.dart';
import 'services/reminders.dart';
import 'services/shared_reels.dart';
import 'services/search_log.dart';
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
    SearchLog.instance.enabled = true;
  } catch (e) {
    debugPrint('Firebase not available, saving on this device. If Firebase is set up, check that '
        'Authentication → Sign-in method → Anonymous is enabled. ($e)');
    store = LocalEventStore();
  }

  await Reminders.init();

  final state = AppState(
    store,
    usingCloud: cloud,
    accounts: cloud ? AccountService() : null,
    referrals: cloud ? ReferralService() : null,
  );
  await state.load();

  // Invite links: https://hoopla-894ca.web.app/?ref=CODE
  if (kIsWeb) {
    final code = codeFromUri(Uri.base);
    if (code != null && state.referral.usedCode == null) await state.setPendingRefCode(code);
  }
  runApp(HooplaApp(state: state));
}

class HooplaApp extends StatefulWidget {
  const HooplaApp({super.key, required this.state});
  final AppState state;

  @override
  State<HooplaApp> createState() => _HooplaAppState();
}

class _HooplaAppState extends State<HooplaApp> with WidgetsBindingObserver {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _collectSharedReels());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _collectSharedReels();
  }

  /// Picks up reels shared to Hoopla from Instagram (or TikTok, YouTube) while the app was closed.
  Future<void> _collectSharedReels() async {
    final reels = await SharedReels.take();
    final added = await state.addReels(reels);
    if (added == 0) return;
    _messenger.currentState?.showSnackBar(SnackBar(
      content: Text(added == 1 ? 'Saved "${reels.first.title}". Find it in Games.' : 'Saved $added reels. Find them in Games.'),
    ));
  }

  /// Providers see their listing; everyone else plans events.
  static Widget _home(AppState s) {
    if (s.isProvider) {
      return s.provider == null ? const ProviderSetupScreen() : const ProviderHomeScreen();
    }
    return s.event == null ? const SetupScreen() : const HomeShell();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          scaffoldMessengerKey: _messenger,
          title: 'Hoopla',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: _home(state),
        ),
      ),
    );
  }
}
