import 'dart:typed_data';

import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/pinda.dart';

/// Everything the UI needs to read and write a user's library.
///
/// Two implementations exist: [FirestoreLibraryRepository] for production
/// and [DemoLibraryRepository] (in-memory sample data) for previews.
abstract class LibraryRepository {
  String newId();

  // Structure
  Stream<List<LibraryCategory>> watchCategories();
  Stream<List<Topic>> watchTopics();
  Future<LibraryCategory> createCategory({
    required String name,
    String description = '',
    required int colorIndex,
  });
  Future<void> updateCategory(LibraryCategory category);

  /// Deletes the category, its topics and every material inside it.
  Future<void> deleteCategory(String categoryId);

  Future<Topic> createTopic({
    required String categoryId,
    required String name,
    String description = '',
    required int colorIndex,
  });
  Future<void> updateTopic(Topic topic);

  /// Deletes the topic. Its materials move up to the parent category.
  Future<void> deleteTopic(String topicId);

  // Materials
  Stream<List<LibraryItem>> watchItems();
  Future<LibraryItem?> getItem(String id);
  Future<void> saveItem(LibraryItem item);
  Future<void> deleteItem(LibraryItem item);
  Future<void> markOpened(String id);
  Future<void> setProgress(String id, double progress);
  Future<void> setReadingList(String id, bool value);

  /// Uploads a PDF and returns (storagePath, downloadUrl).
  Future<(String, String)> uploadPdf({
    required String itemId,
    required String fileName,
    required Uint8List bytes,
  });

  // Margin notes
  Stream<List<ItemNote>> watchNotes(String itemId);
  Future<void> addNote(String itemId, {required String text, String? quote, int? page});
  Future<void> deleteNote(String itemId, String noteId);

  // Pinda conversations
  Stream<List<Conversation>> watchConversations();
  Stream<List<ChatMessage>> watchMessages(String conversationId);
  Future<String> createConversation({required PindaContext context, required String title});
  Future<void> addMessage(String conversationId, ChatMessage message);
  Future<void> deleteConversation(String conversationId);
}
