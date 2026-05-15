import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
//import 'package:google_sign_in/google_sign_in.dart';
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

  // Preferences
  final bool darkMode;
  final ReaderTheme readerTheme;
  final FontSize fontSize;

  // Pinda AI
  final bool savePindaHistory;
  final PindaStyle pindaStyle;

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
    required this.createdAt,
  });

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
        'createdAt': createdAt.toIso8601String(),
      };

  factory DSCVRUser.fromMap(Map<String, dynamic> map) => DSCVRUser(
        id: map['id'] ?? '',
        displayName: map['displayName'] ?? '',
        email: map['email'] ?? '',
        avatarUrl: map['avatarUrl'],
        bio: map['bio'],
        darkMode: map['darkMode'] ?? false,
        readerTheme: ReaderTheme.values.firstWhere(
          (e) => e.name == map['readerTheme'],
          orElse: () => ReaderTheme.warm,
        ),
        fontSize: FontSize.values.firstWhere(
          (e) => e.name == map['fontSize'],
          orElse: () => FontSize.medium,
        ),
        savePindaHistory: map['savePindaHistory'] ?? true,
        pindaStyle: PindaStyle.values.firstWhere(
          (e) => e.name == map['pindaStyle'],
          orElse: () => PindaStyle.detailed,
        ),
        createdAt: map['createdAt'] != null
    ? DateTime.parse(map['createdAt'])
    : DateTime.now(),
      );

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
  Stream<DSCVRUser> get userStream {
  return _auth.authStateChanges().asyncMap(
    (firebaseUser) async {
      if (firebaseUser == null) {
        return DSCVRUser.empty();
      }

      // Try Firestore first
      final firestoreUser =
          await fetchUser(firebaseUser.uid);

      // If Firestore doc exists
      if (firestoreUser != null) {
        return firestoreUser;
      }

      // Fallback to FirebaseAuth user
      return DSCVRUser.fromFirebaseUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName:
            firebaseUser.displayName ??
            'DSCVR User',
        avatarUrl: firebaseUser.photoURL,
      );
    },
  );
}

 
  /// The currently signed-in user, or [DSCVRUser.empty()] if none.
  Future<DSCVRUser> get currentUser async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return DSCVRUser.empty();
    return await fetchUser(firebaseUser.uid) ?? DSCVRUser.empty();
  }
 
  // ─── Sign in ───────────────────────────────────────────────────────────────
 
  /// Signs in with Google. Creates a Firestore user doc on first sign-in.
   Future<DSCVRUser> signInWithGoogle() async {
    final googleUser = await _googleSignIn.authenticate();
    if (googleUser == null) throw DSCVRAuthException('Google sign-in cancelled');
 
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.idToken,
      idToken: googleAuth.idToken,
    );
 
    final result = await _auth.signInWithCredential(credential);
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
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
 
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