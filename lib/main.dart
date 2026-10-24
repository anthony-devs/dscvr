import 'package:dscvr/app.dart';
import 'package:dscvr/config/env.dart';
import 'package:dscvr/state/settings_controller.dart';
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
  }

  final settings = SettingsController();
  await settings.load();

  runApp(DscvrApp(settings: settings));
}
