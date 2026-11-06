import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/auth.dart';
import 'package:dscvr/models/edition.dart';
import 'package:dscvr/models/subscription.dart';
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
    required Edition edition,
  }) async {
    if (Env.demo) {
      _set(_user.copyWith(displayName: displayName, role: role, interests: interests, onboarded: true, edition: edition));
      return;
    }
    await _auth!.completeOnboarding(
        uid: _user.id, displayName: displayName, role: role, interests: interests, edition: edition);
  }

  Edition get edition => _user.edition;

  /// The profile is streamed live from Firestore, so server-side changes
  /// (joining or leaving an organisation) arrive on their own. This waits
  /// briefly so callers can rely on the new state being visible.
  Future<void> refreshProfile() => Future<void>.delayed(const Duration(milliseconds: 400));

  Future<void> setEdition(Edition edition) async {
    if (edition == Edition.enterprise || _user.inOrg) return;
    if (Env.demo) {
      _set(_user.copyWith(edition: edition));
      return;
    }
    await _auth!.setEdition(_user.id, edition);
  }

  /// Re-fetch the user's subscription from Firestore and update local state.
  Future<void> refreshSubscription() async {
    if (Env.demo) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final data = doc.data();
      if (data == null || data['subscription'] == null) return;
      final sub = Subscription.fromMap((data['subscription'] as Map).cast<String, dynamic>());
      _set(_user.copyWith(subscription: sub));
    } catch (_) {
      // Silently fail — subscription will refresh on next auth stream event.
    }
  }

  Future<void> signOut() async {
    if (Env.demo) return;
    await _auth!.signOut();
    // Don't wait for the auth stream: leave the signed-in screens right away.
    if (!_user.isEmpty) _set(DSCVRUser.empty());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
