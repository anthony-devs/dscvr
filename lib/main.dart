import 'package:dscvr/models/auth.dart';
import 'package:dscvr/screens/home.dart';
import 'package:dscvr/screens/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

// Fix: MyApp must be StatefulWidget so the stream is created once in initState
// and reused across rebuilds — not recreated on every build() call.
//
// The old code did:
//   final Stream<DSCVRUser> currentUser = DSCVRAuth().userStream;
// inside build(), which created a brand-new DSCVRAuth instance (and therefore
// a brand-new stream subscription) on every rebuild. The StreamBuilder was
// never watching the same stream that login/signup were writing to.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Created once, lives for the lifetime of the app.
  final DSCVRAuth _auth = DSCVRAuth();
  late final Stream<DSCVRUser> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = _auth.userStream;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DSCVR',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StreamBuilder<DSCVRUser>(
        stream: _userStream,
        builder: (context, snapshot) {
          // Still loading first emission
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Stream error
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')),
            );
          }

          // Signed in
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return HomePage(userId: snapshot.data!.id);
          }

          // Signed out
          return const LoginPage();
        },
      ),
    );
  }
}