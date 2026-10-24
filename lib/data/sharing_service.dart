import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dscvr/models/sharing.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages share links in Firestore: /shares/{linkId}
class SharingService {
  SharingService({FirebaseFirestore? db}) : _db = db;
  final FirebaseFirestore? _db;

  FirebaseFirestore get _store => _db ?? FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _shares => _store.collection('shares');

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Creates a new share link and returns it.
  Future<ShareLink> createLink({
    required String targetType,
    required String targetId,
    SharePermission permission = SharePermission.view,
    String? label,
    String? password,
    Duration? expiry,
  }) async {
    final doc = _shares.doc();
    final link = ShareLink(
      id: doc.id,
      ownerId: _uid,
      targetType: targetType,
      targetId: targetId,
      permission: permission,
      createdAt: DateTime.now(),
      expiresAt: expiry != null ? DateTime.now().add(expiry) : null,
      password: password,
      label: label,
    );
    await doc.set(link.toMap());
    return link;
  }

  /// Lists all share links the current user owns.
  Future<List<ShareLink>> listMyLinks() async {
    final snap = await _shares.where('ownerId', isEqualTo: _uid).get();
    return snap.docs.map((d) => ShareLink.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Lists share links for a specific target (category or topic).
  Future<List<ShareLink>> linksFor(String targetType, String targetId) async {
    final snap = await _shares
        .where('ownerId', isEqualTo: _uid)
        .where('targetType', isEqualTo: targetType)
        .where('targetId', isEqualTo: targetId)
        .get();
    return snap.docs.map((d) => ShareLink.fromMap(d.id, d.data())).toList();
  }

  /// Updates a share link (permission, expiry, active, etc.).
  Future<void> updateLink(ShareLink link) async {
    await _shares.doc(link.id).update(link.toMap());
  }

  /// Revokes (deletes) a share link.
  Future<void> revokeLink(String linkId) async {
    await _shares.doc(linkId).delete();
  }

  /// Resolves a share link for public viewers (no auth needed, called from the
  /// shared viewer page). Returns null if invalid/expired.
  Future<ShareLink?> resolveLink(String linkId) async {
    final doc = await _shares.doc(linkId).get();
    if (!doc.exists) return null;
    final link = ShareLink.fromMap(doc.id, doc.data()!);
    if (!link.isValid) return null;
    return link;
  }
}

/// In demo mode, returns canned data.
class DemoSharingService extends SharingService {
  DemoSharingService() : super(db: null);

  final List<ShareLink> _links = [];

  @override
  Future<ShareLink> createLink({
    required String targetType,
    required String targetId,
    SharePermission permission = SharePermission.view,
    String? label,
    String? password,
    Duration? expiry,
  }) async {
    final link = ShareLink(
      id: 'demo_${_links.length + 1}',
      ownerId: 'demo_user',
      targetType: targetType,
      targetId: targetId,
      permission: permission,
      createdAt: DateTime.now(),
      expiresAt: expiry != null ? DateTime.now().add(expiry) : null,
      password: password,
      label: label,
    );
    _links.add(link);
    return link;
  }

  @override
  Future<List<ShareLink>> listMyLinks() async => List.of(_links);

  @override
  Future<List<ShareLink>> linksFor(String targetType, String targetId) async =>
      _links.where((l) => l.targetType == targetType && l.targetId == targetId).toList();

  @override
  Future<void> updateLink(ShareLink link) async {
    final i = _links.indexWhere((l) => l.id == link.id);
    if (i >= 0) _links[i] = link;
  }

  @override
  Future<void> revokeLink(String linkId) async {
    _links.removeWhere((l) => l.id == linkId);
  }

  @override
  Future<ShareLink?> resolveLink(String linkId) async {
    final match = _links.where((l) => l.id == linkId).toList();
    if (match.isEmpty) return null;
    return match.first.isValid ? match.first : null;
  }
}
