import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dscvr/models/file.dart';

/// Data-access layer for the Recents page.
///
/// Keeping Firebase calls out of the widget means the UI only ever talks
/// to a small, mockable interface — easier to test and easier to change
/// later (e.g. swapping Storage for a CDN-backed file list).
class DscvrRepository {
  DscvrRepository({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  })  : _storage = storage ??
            FirebaseStorage.instanceFor(
              bucket: 'gs://dscvr-9d362.firebasestorage.app',
            ),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

  /// Lists every file a user has uploaded, most-recently-added first isn't
  /// guaranteed by Storage — sort by name/metadata upstream if ordering
  /// matters to the design.
  Future<List<Reference>> listUserFiles(String userId) async {
    final result = await _storage.ref('users').child(userId).listAll();
    return result.items;
  }

  /// Streams the user's saved notes in real time.
  Stream<List<Note>> watchNotes(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map(
      (snapshot) {
        final data = snapshot.data();
        final notesMap = data?['notes'] as Map<String, dynamic>?;
        if (notesMap == null) return const <Note>[];

        return notesMap.values
            .map((e) => Note.fromMap(e as Map<String, dynamic>))
            .toList();
      },
    );
  }
}