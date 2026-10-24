import 'dart:async';

import 'package:dscvr/data/library_repository.dart';
import 'package:dscvr/data/pinda_service.dart';
import 'package:dscvr/models/pinda.dart';
import 'package:flutter/foundation.dart';

/// Drives one Pinda conversation: history, streaming replies, persistence.
class PindaController extends ChangeNotifier {
  PindaController({
    required this.repo,
    required this.service,
    required PindaContext context,
    required this.styleOf,
    String? conversationId,
  })  : _context = context,
        _conversationId = conversationId {
    if (conversationId != null) _load(conversationId);
  }

  final LibraryRepository repo;
  final PindaService service;
  final String Function() styleOf;

  PindaContext _context;
  String? _conversationId;
  List<ChatMessage> _messages = [];
  StreamSubscription<String>? _stream;
  bool _loading = false;
  bool _disposed = false;

  PindaContext get context => _context;
  String? get conversationId => _conversationId;
  List<ChatMessage> get messages => _messages;
  bool get isStreaming => _stream != null;
  bool get isLoading => _loading;

  Future<void> _load(String id) async {
    _loading = true;
    _notify();
    try {
      _messages = await repo.watchMessages(id).first;
    } catch (_) {
      _messages = [];
    }
    _loading = false;
    _notify();
  }

  /// Switch what Pinda reads. Starts a fresh conversation.
  void setContext(PindaContext ctx) {
    if (ctx == _context) return;
    stop();
    _context = ctx;
    _conversationId = null;
    _messages = [];
    _notify();
  }

  void openConversation(Conversation c) {
    stop();
    _context = c.context;
    _conversationId = c.id;
    _messages = [];
    _load(c.id);
  }

  void newConversation() {
    stop();
    _conversationId = null;
    _messages = [];
    _notify();
  }

  Future<void> send(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || isStreaming) return;

    final now = DateTime.now();
    final user = ChatMessage(id: repo.newId(), role: ChatRole.user, text: prompt, createdAt: now);
    var reply = ChatMessage(
        id: repo.newId(), role: ChatRole.assistant, text: '', createdAt: now.add(const Duration(milliseconds: 1)), pending: true);
    _messages = [..._messages, user, reply];
    _notify();

    try {
      _conversationId ??= await repo.createConversation(context: _context, title: _titleFrom(prompt));
      unawaited(repo.addMessage(_conversationId!, user).catchError((_) {}));
    } catch (_) {
      // Persisting is best-effort; the chat still works.
    }

    final buffer = StringBuffer();
    final history = _messages.where((m) => !m.pending && m.error == null).toList();
    final completer = Completer<void>();
    _stream = service.reply(history: history, context: _context, style: styleOf()).listen(
      (delta) {
        buffer.write(delta);
        reply = reply.copyWith(text: buffer.toString());
        _replace(reply);
      },
      onError: (Object e) {
        reply = reply.copyWith(pending: false, error: e is PindaException ? e.message : 'Something went wrong.');
        _replace(reply);
        _stream = null;
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        reply = reply.copyWith(pending: false);
        _replace(reply);
        _stream = null;
        if (_conversationId != null && reply.text.isNotEmpty) {
          repo.addMessage(_conversationId!, reply).catchError((_) {});
        }
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );
    _notify();
    return completer.future;
  }

  void stop() {
    final s = _stream;
    if (s == null) return;
    s.cancel();
    _stream = null;
    _messages = [
      for (final m in _messages) m.pending ? m.copyWith(pending: false) : m,
    ];
    final last = _messages.isEmpty ? null : _messages.last;
    if (_conversationId != null && last != null && last.role == ChatRole.assistant && last.text.isNotEmpty) {
      repo.addMessage(_conversationId!, last).catchError((_) {});
    }
    _notify();
  }

  /// Re-asks the last question after an error.
  Future<void> retry() async {
    final lastUser = _messages.lastWhere((m) => m.role == ChatRole.user, orElse: () => _messages.first);
    _messages = _messages.where((m) => m.error == null && m.id != lastUser.id).toList();
    _notify();
    await send(lastUser.text);
  }

  void _replace(ChatMessage m) {
    _messages = [for (final x in _messages) x.id == m.id ? m : x];
    _notify();
  }

  static String _titleFrom(String prompt) {
    final firstLine = prompt.split('\n').first.trim();
    return firstLine.length > 64 ? '${firstLine.substring(0, 64)}...' : firstLine;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stream?.cancel();
    super.dispose();
  }
}
