import 'dart:async';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum SessionStatus { unknown, signedOut, onboarding, ready }

/// Tracks who is signed in and whether they've finished onboarding.
/// The router listens to this to decide where to send the user.
class SessionController extends ChangeNotifier {
  SessionController() {
    if (Env.demo) {
      _user = DSCVRUser(
        id: 'demo',
        displayName: 'Anthony Ude',
        email: 'demo@dscvr.app',
        role: 'Researcher',
        onboarded: true,
        createdAt: DateTime.now(),
      );
      _status = SessionStatus.ready;
    } else {
      _auth = DSCVRAuth();
      _sub = _auth!.userStream.listen(_onUser, onError: (_) => _set(DSCVRUser.empty()));
    }
  }

  DSCVRAuth? _auth;
  StreamSubscription<DSCVRUser>? _sub;
  DSCVRUser _user = DSCVRUser.empty();
  SessionStatus _status = SessionStatus.unknown;

  DSCVRUser get user => _user;
  SessionStatus get status => _status;
  DSCVRAuth? get auth => _auth;

  void _onUser(DSCVRUser u) => _set(u);

  void _set(DSCVRUser u) {
    _user = u;
    _status = u.isEmpty
        ? SessionStatus.signedOut
        : (u.onboarded ? SessionStatus.ready : SessionStatus.onboarding);
    notifyListeners();
  }

  Future<String?> idToken() async {
    if (Env.demo) return 'demo';
    return FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<void> completeOnboarding({
    required String displayName,
    required String role,
    required List<String> interests,
  }) async {
    if (Env.demo) {
      _set(_user.copyWith(displayName: displayName, role: role, interests: interests, onboarded: true));
      return;
    }
    await _auth!.completeOnboarding(
        uid: _user.id, displayName: displayName, role: role, interests: interests);
  }

  Future<void> signOut() async {
    if (Env.demo) return;
    await _auth!.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
