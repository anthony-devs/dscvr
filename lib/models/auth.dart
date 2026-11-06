import 'dart:async';
import 'package:dscvr/models/edition.dart';
import 'package:dscvr/models/file.dart';
import 'package:dscvr/models/subscription.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum ReaderTheme { warm, cool, sepia }

enum FontSize { small, medium, large }

enum PindaStyle { concise, detailed }

@immutable
class DSCVRUser {
  final String id;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final List<Note>? notes;

  // Onboarding
  final String? handle;
  final String role;
  final List<String> interests;
  final bool onboarded;

  // Edition and organisation (enterprise)
  final Edition edition;
  final String? orgId;
  final String? orgRole;

  // Preferences
  final bool darkMode;
  final ReaderTheme readerTheme;
  final FontSize fontSize;

  // Pinda AI
  final bool savePindaHistory;
  final PindaStyle pindaStyle;

  // Subscription
  final Subscription subscription;

  // Metadata
  final DateTime createdAt;

  const DSCVRUser({
    required this.id,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    this.bio,
    this.darkMode = false,
    this.readerTheme = ReaderTheme.warm,
    this.fontSize = FontSize.medium,
    this.savePindaHistory = true,
    this.pindaStyle = PindaStyle.detailed,
    Subscription? subscription,
    this.notes,
    this.handle,
    this.role = 'Researcher',
    this.interests = const [],
    this.onboarded = false,
    this.edition = Edition.researchers,
    this.orgId,
    this.orgRole,
    required this.createdAt,
  }) : subscription = subscription ?? Subscription.free_;

  bool get inOrg => orgId != null && orgId!.isNotEmpty;
  bool get isOrgAdmin => inOrg && orgRole == 'admin';

  String get firstName {
    final t = displayName.trim();
    if (t.isEmpty) return 'there';
    return t.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool get isEmpty => id.isEmpty;
  bool get isNotEmpty => id.isNotEmpty;

  factory DSCVRUser.empty() => DSCVRUser(
        id: '',
        displayName: '',
        email: '',
        createdAt: DateTime.now(),
      );

  factory DSCVRUser.fromFirebaseUser({
    required String uid,
    required String email,
    required String displayName,
    String? avatarUrl,
    String? bio
  }) =>
      DSCVRUser(
        id: uid,
        displayName: displayName,
        email: email,
        avatarUrl: avatarUrl,
        createdAt: DateTime.now(),
        bio: bio
      );

  DSCVRUser copyWith({
    String? displayName,
    String? email,
    String? avatarUrl,
    String? bio,
    bool? darkMode,
    ReaderTheme? readerTheme,
    FontSize? fontSize,
    bool? savePindaHistory,
    PindaStyle? pindaStyle,
    Subscription? subscription,
    String? handle,
    String? role,
    List<String>? interests,
    bool? onboarded,
    Edition? edition,
  }) =>
      DSCVRUser(
        id: id,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        darkMode: darkMode ?? this.darkMode,
        readerTheme: readerTheme ?? this.readerTheme,
        fontSize: fontSize ?? this.fontSize,
        savePindaHistory: savePindaHistory ?? this.savePindaHistory,
        pindaStyle: pindaStyle ?? this.pindaStyle,
        subscription: subscription ?? this.subscription,
        handle: handle ?? this.handle,
        role: role ?? this.role,
        interests: interests ?? this.interests,
        onboarded: onboarded ?? this.onboarded,
        edition: edition ?? this.edition,
        orgId: orgId,
        orgRole: orgRole,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'darkMode': darkMode,
        'readerTheme': readerTheme.name,
        'fontSize': fontSize.name,
        'savePindaHistory': savePindaHistory,
        'pindaStyle': pindaStyle.name,
        'handle': handle,
        'role': role,
        'interests': interests,
        'onboarded': onboarded,
        'edition': edition.name,
        'subscription': subscription.toMap(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory DSCVRUser.fromMap(Map<String, dynamic> map) => DSCVRUser(
        id: map['id'] ?? '',
        displayName: map['displayName'] ?? '',
        email: map['email'] ?? '',
        avatarUrl: map['avatarUrl'],
        bio: map['bio'],
        // The old code called forEach (which returns void) and crashed when
        // the field was missing. Notes are optional legacy data.
        notes: _parseNotes(map['notes']),
        handle: map['handle'] as String?,
        role: map['role'] as String? ?? 'Researcher',
        interests: (map['interests'] as List?)?.whereType<String>().toList() ?? const [],
        onboarded: map['onboarded'] as bool? ?? false,
        edition: (map['orgId'] as String?)?.isNotEmpty == true
            ? Edition.enterprise
            : Edition.parse(map['edition'] as String?, role: map['role'] as String?),
        orgId: map['orgId'] as String?,
        orgRole: map['orgRole'] as String?,
        darkMode: map['darkMode'] ?? false,
        readerTheme: ReaderTheme.values.firstWhere(
          (e) => e.name == map['readerTheme'],
          orElse: () => ReaderTheme.warm,
        ),
        fontSize: FontSize.values.firstWhere(
          (e) => e.name == map['fontSize'],
          orElse: () => FontSize.medium,
        ),
        subscription: map['subscription'] is Map
            ? Subscription.fromMap((map['subscription'] as Map).cast<String, dynamic>())
            : Subscription.free(),
        savePindaHistory: map['savePindaHistory'] ?? true,
        pindaStyle: PindaStyle.values.firstWhere(
          (e) => e.name == map['pindaStyle'],
          orElse: () => PindaStyle.detailed,
        ),
        createdAt: map['createdAt'] is String
            ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
            : map['createdAt'] is Timestamp
                ? (map['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
      );

  static List<Note>? _parseNotes(Object? raw) {
    if (raw is! Map) return null;
    final out = <Note>[];
    for (final v in raw.values) {
      if (v is Map<String, dynamic>) {
        try {
          out.add(Note.fromMap(v));
        } catch (_) {
          // Skip malformed legacy notes instead of failing the whole profile.
        }
      }
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DSCVRUser && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DSCVRUser($id, $displayName)';
}

class DSCVRAuth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 
  // ─── Stream ────────────────────────────────────────────────────────────────
 
  /// Emits a [DSCVRUser] when auth state changes, or [DSCVRUser.empty()] on sign-out.
  ///
  /// Follows the Firestore profile document live, so edits made during
  /// onboarding or in Settings show up immediately without re-login.
  /// The signed-in user, with their profile kept live from Firestore.
  ///
  /// Each auth change cancels the previous profile listener (switch-map).
  /// Using asyncExpand here would wait for the profile stream to end, which
  /// never happens, so a sign-out would never get through.
  Stream<DSCVRUser> get userStream {
    late StreamController<DSCVRUser> out;
    StreamSubscription<User?>? authSub;
    StreamSubscription<DSCVRUser>? profileSub;
    out = StreamController<DSCVRUser>(
      onListen: () {
        authSub = _auth.authStateChanges().listen((firebaseUser) {
          profileSub?.cancel();
          profileSub = null;
          if (firebaseUser == null) {
            out.add(DSCVRUser.empty());
            return;
          }
          final fallback = DSCVRUser.fromFirebaseUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            displayName: firebaseUser.displayName ?? 'DSCVR User',
            avatarUrl: firebaseUser.photoURL,
          );
          profileSub = _firestore.collection('users').doc(firebaseUser.uid).snapshots().map((doc) {
            final data = doc.data();
            if (data == null) return fallback;
            return DSCVRUser.fromMap({...data, 'id': firebaseUser.uid});
          }).listen(out.add, onError: (Object _) => out.add(fallback));
        }, onError: out.addError);
      },
      onCancel: () async {
        await profileSub?.cancel();
        await authSub?.cancel();
      },
    );
    return out.stream;
  }

  /// Saves onboarding answers and marks the profile as set up.
  Future<void> completeOnboarding({
    required String uid,
    required String displayName,
    required String role,
    required List<String> interests,
    required Edition edition,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'id': uid,
      'displayName': displayName,
      'email': _auth.currentUser?.email ?? '',
      'role': role,
      'interests': interests,
      'edition': edition.name,
      'onboarded': true,
    }, SetOptions(merge: true));
    if (displayName.isNotEmpty) {
      await _auth.currentUser?.updateDisplayName(displayName);
    }
  }

 
  /// The currently signed-in user, or [DSCVRUser.empty()] if none.
  Future<DSCVRUser> get currentUser async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return DSCVRUser.empty();
    return await fetchUser(firebaseUser.uid) ?? DSCVRUser.empty();
  }
 
  // ─── Sign in ───────────────────────────────────────────────────────────────
 
  /// Signs in with Google. Creates a Firestore user doc on first sign-in.
  ///
  /// On web this uses Firebase's popup flow (google_sign_in 7 does not
  /// support `authenticate()` on web). On mobile it uses the native sheet.
  Future<DSCVRUser> signInWithGoogle() async {
    final UserCredential result;
    try {
      if (kIsWeb) {
        result = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        await _ensureGoogleInitialized();
        final googleUser = await _googleSignIn.authenticate();
        final googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        result = await _auth.signInWithCredential(credential);
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const DSCVRAuthException('Google sign-in cancelled');
      }
      throw DSCVRAuthException(e.description ?? 'Google sign-in failed');
    } on FirebaseAuthException catch (e) {
      throw DSCVRAuthException(_firebaseAuthErrorMessage(e));
    }
    final firebaseUser = result.user!;
 
    // First sign-in — create Firestore doc
    if (result.additionalUserInfo?.isNewUser ?? false) {
      final user = DSCVRUser.fromFirebaseUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? 'DSCVR User',
        avatarUrl: firebaseUser.photoURL,
      );
      await _saveUser(user);
      return user;
    }
 
    return await fetchUser(firebaseUser.uid) ?? DSCVRUser.empty();
  } 
 
  /// Signs in with email and password.
  Future<DSCVRUser> signInWithEmail({
  required String email,
  required String password,
}) async {
  try {
    final result =
        await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return await fetchUser(
          result.user!.uid,
        ) ??
        DSCVRUser.empty();
  } on FirebaseAuthException catch (e) {
    throw DSCVRAuthException(
      _firebaseAuthErrorMessage(e),
    );
  } catch (e) {
    throw DSCVRAuthException(
      'Something went wrong',
    );
  }
}
 
  // ─── Register ──────────────────────────────────────────────────────────────
 
 String _firebaseAuthErrorMessage(
  FirebaseAuthException e,
) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'This email has already been used';

    case 'invalid-email':
      return 'Invalid email address';

    case 'weak-password':
      return 'Password is too short';

    case 'user-not-found':
      return 'No account found';

    case 'wrong-password':
      return 'Incorrect password';

    case 'invalid-credential':
      return 'Invalid email or password';

    case 'network-request-failed':
      return 'No internet connection';

    default:
      return e.message ??
          'Authentication failed';
  }
}
  /// Creates a new account with email/password and saves a Firestore user doc.
  Future<DSCVRUser> registerWithEmail({
  required String email,
  required String password,
  required String displayName,
}) async {
  try {
    final result =
        await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await result.user!
        .updateDisplayName(displayName);

    final user = DSCVRUser(
      id: result.user!.uid,
      displayName: displayName,
      email: email,
      createdAt: DateTime.now(),
    );

    // Save BEFORE stream emits fallback
    await _saveUser(user);

    return user;
  } on FirebaseAuthException catch (e) {
    throw DSCVRAuthException(
      _firebaseAuthErrorMessage(e),
    );
  } catch (e) {
    throw DSCVRAuthException(
      'Something went wrong',
    );
  }
}
 
  // ─── Sign out ──────────────────────────────────────────────────────────────
 
  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await _ensureGoogleInitialized();
        await _googleSignIn.signOut();
      } catch (_) {
        // Not signed in with Google; nothing to do.
      }
    }
  }

  static Future<void>? _googleInit;
  Future<void> _ensureGoogleInitialized() =>
      _googleInit ??= _googleSignIn.initialize();
 
  // ─── Password ──────────────────────────────────────────────────────────────
 
  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
 
  /// Updates the password for the currently signed-in user.
  /// Requires recent sign-in — catch [DSCVRAuthException] for re-auth prompt.
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) throw DSCVRAuthException('No user signed in');
 
    final credential = EmailAuthProvider.credential(
      email: firebaseUser.email!,
      password: currentPassword,
    );
 
    await firebaseUser.reauthenticateWithCredential(credential);
    await firebaseUser.updatePassword(newPassword);
  }
 
  // ─── Profile ───────────────────────────────────────────────────────────────
 
  /// Updates [displayName] and/or [bio] in Firestore.
  Future<DSCVRUser> updateProfile({
    required String uid,
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
 
    if (updates.isEmpty) return await currentUser;
 
    await _firestore.collection('users').doc(uid).update(updates);
 
    if (displayName != null) {
      await _auth.currentUser?.updateDisplayName(displayName);
    }
 
    return await fetchUser(uid) ?? DSCVRUser.empty();
  }
 
  /// Updates user preferences (theme, font size, Pinda settings).
  /// Switches between the Students and Researchers editions. Enterprise is
  /// set by the server when the user creates or joins an organisation.
  Future<void> setEdition(String uid, Edition edition) =>
      _firestore.collection('users').doc(uid).set({'edition': edition.name}, SetOptions(merge: true));

  Future<void> updatePreferences({
    required String uid,
    bool? darkMode,
    ReaderTheme? readerTheme,
    FontSize? fontSize,
    bool? savePindaHistory,
    PindaStyle? pindaStyle,
  }) async {
    final updates = <String, dynamic>{};
    if (darkMode != null) updates['darkMode'] = darkMode;
    if (readerTheme != null) updates['readerTheme'] = readerTheme.name;
    if (fontSize != null) updates['fontSize'] = fontSize.name;
    if (savePindaHistory != null) updates['savePindaHistory'] = savePindaHistory;
    if (pindaStyle != null) updates['pindaStyle'] = pindaStyle.name;
 
    if (updates.isEmpty) return;
    await _firestore.collection('users').doc(uid).update(updates);
  }
 
  // ─── Account ───────────────────────────────────────────────────────────────
 
  /// Permanently deletes the user's Firestore doc and Firebase Auth account.
  /// Requires recent sign-in.
  Future<void> deleteAccount(String password) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) throw DSCVRAuthException('No user signed in');
 
    final credential = EmailAuthProvider.credential(
      email: firebaseUser.email!,
      password: password,
    );
 
    await firebaseUser.reauthenticateWithCredential(credential);
    await _firestore.collection('users').doc(firebaseUser.uid).delete();
    await firebaseUser.delete();
  }
 
  // ─── Private helpers ───────────────────────────────────────────────────────
 
  Future<DSCVRUser?> fetchUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return DSCVRUser.fromMap(doc.data()!);
  }

 
  Future<void> _saveUser(DSCVRUser user) async {
    await _firestore
        .collection('users')
        .doc(user.id)
        .set(user.toMap(), SetOptions(merge: true));
  }
}
 
// ─── Exception ─────────────────────────────────────────────────────────────────
 
class DSCVRAuthException implements Exception {
  final String message;
  const DSCVRAuthException(this.message);
 
  @override
  String toString() => 'DSCVRAuthException: $message';
}