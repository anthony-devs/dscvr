import 'package:dscvr/app.dart';
import 'package:dscvr/config/env.dart';
import 'package:dscvr/state/settings_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clean URLs on the web (/c/econ instead of /#/c/econ). Firebase Hosting
  // rewrites every path to index.html, see firebase.json.
  usePathUrlStrategy();

  if (!Env.demo) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Keep the library readable offline: Firestore caches what the user has
    // loaded and queues writes until the connection returns.
    try {
      FirebaseFirestore.instance.settings =
          const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        // Some networks break Firestore's streaming connection. Fall back to long polling there.
        webExperimentalAutoDetectLongPolling: true,
      );
    } catch (e) {
      debugPrint('Offline cache unavailable: $e');
    }
  }

  final settings = SettingsController();
  await settings.load();

  runApp(DscvrApp(settings: settings));
}
