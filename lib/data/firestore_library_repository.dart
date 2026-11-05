import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/library_repository.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/pinda.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreLibraryRepository implements LibraryRepository {
  FirestoreLibraryRepository({
    required this.uid,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instanceFor(bucket: Env.storageBucket);

  final String uid;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> get _user => _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _categories => _user.collection('categories');
  CollectionReference<Map<String, dynamic>> get _topics => _user.collection('topics');
  CollectionReference<Map<String, dynamic>> get _items => _user.collection('materials');
  CollectionReference<Map<String, dynamic>> get _conversations => _user.collection('conversations');
  CollectionReference<Map<String, dynamic>> get _reports => _user.collection('reports');
  CollectionReference<Map<String, dynamic>> get _sessions => _user.collection('sessions');

  @override
  String newId() => _items.doc().id;

  // ── Structure ──────────────────────────────────────────────────────────────

  @override
  Stream<List<LibraryCategory>> watchCategories() => _categories.orderBy('order').snapshots().map(
      (s) => s.docs.map((d) => LibraryCategory.fromMap(d.id, d.data())).toList());

  @override
  Stream<List<Topic>> watchTopics() => _topics.orderBy('createdAt').snapshots().map(
      (s) => s.docs.map((d) => Topic.fromMap(d.id, d.data())).toList());

  @override
  Future<LibraryCategory> createCategory({
    required String name,
    String description = '',
    required int colorIndex,
  }) async {
    final ref = _categories.doc();
    final now = DateTime.now();
    final category = LibraryCategory(
      id: ref.id,
      name: name,
      description: description,
      colorIndex: colorIndex,
      order: now.millisecondsSinceEpoch,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(category.toMap());
    return category;
  }

  @override
  Future<void> updateCategory(LibraryCategory category) =>
      _categories.doc(category.id).set(category.toMap(), SetOptions(merge: true));

  @override
  Future<void> deleteCategory(String categoryId) async {
    final topics = await _topics.where('categoryId', isEqualTo: categoryId).get();
    final items = await _items.where('categoryId', isEqualTo: categoryId).get();
    for (final d in items.docs) {
      final path = d.data()['storagePath'] as String?;
      if (path != null) {
        _storage.ref(path).delete().catchError((_) {});
      }
    }
    await _deleteDocs([
      ...topics.docs.map((d) => d.reference),
      ...items.docs.map((d) => d.reference),
      _categories.doc(categoryId),
    ]);
  }

  @override
  Future<Topic> createTopic({
    required String categoryId,
    required String name,
    String description = '',
    required int colorIndex,
  }) async {
    final ref = _topics.doc();
    final now = DateTime.now();
    final topic = Topic(
      id: ref.id,
      categoryId: categoryId,
      name: name,
      description: description,
      colorIndex: colorIndex,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(topic.toMap());
    return topic;
  }

  @override
  Future<void> updateTopic(Topic topic) =>
      _topics.doc(topic.id).set(topic.toMap(), SetOptions(merge: true));

  @override
  Future<void> deleteTopic(String topicId) async {
    final items = await _items.where('topicId', isEqualTo: topicId).get();
    final batch = _db.batch();
    for (final d in items.docs) {
      batch.update(d.reference, {'topicId': null});
    }
    batch.delete(_topics.doc(topicId));
    await batch.commit();
  }

  Future<void> _deleteDocs(List<DocumentReference> refs) async {
    for (var i = 0; i < refs.length; i += 450) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(450)) {
        batch.delete(r);
      }
      await batch.commit();
    }
  }

  // ── Materials ──────────────────────────────────────────────────────────────

  @override
  Stream<List<LibraryItem>> watchItems() => _items.snapshots().map(
      (s) => s.docs.map((d) => LibraryItem.fromMap(d.id, d.data())).toList());

  @override
  Future<LibraryItem?> getItem(String id) async {
    final d = await _items.doc(id).get();
    final data = d.data();
    return data == null ? null : LibraryItem.fromMap(d.id, data);
  }

  @override
  Future<void> saveItem(LibraryItem item) =>
      _items.doc(item.id).set(item.toMap(), SetOptions(merge: true));

  @override
  Future<void> deleteItem(LibraryItem item) async {
    if (item.storagePath != null) {
      await _storage.ref(item.storagePath!).delete().catchError((_) {});
    }
    final notes = await _items.doc(item.id).collection('notes').get();
    await _deleteDocs([...notes.docs.map((d) => d.reference), _items.doc(item.id)]);
  }

  @override
  Future<void> markOpened(String id) =>
      _items.doc(id).update({'lastOpenedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> setProgress(String id, double progress) => _items.doc(id).update({
        'progress': progress.clamp(0, 1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> setReadingList(String id, bool value) =>
      _items.doc(id).update({'inReadingList': value});

  @override
  Future<void> setRating(String id, int stars) =>
      _items.doc(id).update({'rating': stars.clamp(0, 5), 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<void> attachPdf(String id, {required String storagePath, required String pdfUrl}) =>
      _items.doc(id).update({'storagePath': storagePath, 'pdfUrl': pdfUrl, 'updatedAt': FieldValue.serverTimestamp()});

  @override
  Future<(String, String)> uploadPdf({
    required String itemId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'users/$uid/materials/$itemId/$safe';
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
    return (path, await ref.getDownloadURL());
  }

  // ── Notes ──────────────────────────────────────────────────────────────────

  @override
  Stream<List<ItemNote>> watchNotes(String itemId) => _items
      .doc(itemId)
      .collection('notes')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => ItemNote.fromMap(d.id, d.data())).toList());

  @override
  Future<void> addNote(String itemId, {required String text, String? quote, int? page}) async {
    final batch = _db.batch();
    final ref = _items.doc(itemId).collection('notes').doc();
    batch.set(ref, ItemNote(id: ref.id, text: text, quote: quote, page: page, createdAt: DateTime.now()).toMap());
    batch.update(_items.doc(itemId), {'noteCount': FieldValue.increment(1)});
    await batch.commit();
  }

  @override
  Future<void> deleteNote(String itemId, String noteId) async {
    final batch = _db.batch();
    batch.delete(_items.doc(itemId).collection('notes').doc(noteId));
    batch.update(_items.doc(itemId), {'noteCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  // ── Conversations ──────────────────────────────────────────────────────────

  @override
  Stream<List<Conversation>> watchConversations() => _conversations
      .orderBy('updatedAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => Conversation.fromMap(d.id, d.data())).toList());

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) => _conversations
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList());

  @override
  Future<String> createConversation({required PindaContext context, required String title}) async {
    final ref = _conversations.doc();
    await ref.set({
      'title': title,
      'context': context.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Future<void> addMessage(String conversationId, ChatMessage message) async {
    final batch = _db.batch();
    final conv = _conversations.doc(conversationId);
    batch.set(conv.collection('messages').doc(message.id), message.toMap());
    batch.update(conv, {'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    final msgs = await _conversations.doc(conversationId).collection('messages').get();
    await _deleteDocs([...msgs.docs.map((d) => d.reference), _conversations.doc(conversationId)]);
  }

  // ── Reports ────────────────────────────────────────────────────────────────

  @override
  Stream<List<Report>> watchReports() => _reports
      .orderBy('updatedAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map((d) => Report.fromMap(d.id, d.data())).toList());

  @override
  Future<Report?> getReport(String id) async {
    final d = await _reports.doc(id).get();
    final data = d.data();
    return data == null ? null : Report.fromMap(d.id, data);
  }

  @override
  Future<void> saveReport(Report report) => _reports.doc(report.id).set(report.toMap(), SetOptions(merge: true));

  @override
  Future<void> deleteReport(String id) => _reports.doc(id).delete();

  // ── Focus sessions ─────────────────────────────────────────────────────────

  @override
  Stream<List<FocusSession>> watchSessions() => _sessions
      .orderBy('startedAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => FocusSession.fromMap(d.id, d.data())).toList());

  @override
  Future<void> saveSession(FocusSession session) =>
      _sessions.doc(session.id).set(session.toMap(), SetOptions(merge: true));

  @override
  Future<void> deleteSession(String id) => _sessions.doc(id).delete();
}
