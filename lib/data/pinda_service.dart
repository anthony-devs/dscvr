import 'dart:async';

import 'package:dscvr/data/api.dart';
import 'package:dscvr/models/pinda.dart';

/// Streams Pinda replies from the DSCVR server's `/pinda` endpoint.
///
/// The server holds the Claude API key, loads the requested library context
/// itself (so the client can only reference its own data) and streams the
/// answer back as Server-Sent Events.
abstract class PindaService {
  Stream<String> reply({
    required List<ChatMessage> history,
    required PindaContext context,
    required String style,
    bool voice = false,
  });
}

class PindaException implements Exception {
  const PindaException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HttpPindaService implements PindaService {
  HttpPindaService(this.api);

  final DscvrApi api;

  @override
  Stream<String> reply({
    required List<ChatMessage> history,
    required PindaContext context,
    required String style,
    bool voice = false,
  }) async* {
    final messages = [
      for (final m in history.where((m) => m.text.trim().isNotEmpty).toList().reversed.take(24).toList().reversed)
        {'role': m.role.name, 'text': m.text},
    ];
    try {
      yield* api.stream('/pinda', {
        'context': {'scope': context.scope.name, 'id': context.id},
        'style': style,
        'voice': voice,
        'messages': messages,
      });
    } on ApiException catch (e) {
      throw PindaException(e.message);
    }
  }
}

/// Offline stand-in used in demo mode. Streams a canned but context-aware
/// answer so the chat UI can be reviewed without a backend.
class DemoPindaService implements PindaService {
  @override
  Stream<String> reply({
    required List<ChatMessage> history,
    required PindaContext context,
    required String style,
    bool voice = false,
  }) async* {
    final question = history.isEmpty ? '' : history.last.text;
    final scope = switch (context.scope) {
      PindaScope.material => 'this material, **${context.label}**',
      PindaScope.topic => 'the topic **${context.label}**',
      PindaScope.category => 'everything in **${context.label}**',
      PindaScope.general => 'your whole library',
    };
    final text = '''
This is a preview response. In the live app I read $scope before answering.

**What you asked**

> ${question.length > 160 ? '${question.substring(0, 160)}...' : question}

**How I would approach it**

1. Pull the relevant passages and your margin notes.
2. Answer directly, citing the material by title.
3. Suggest one follow-up worth reading next.

Set ANTHROPIC_API_KEY on the DSCVR server to get real answers.''';
    for (final word in text.split(' ')) {
      await Future<void>.delayed(const Duration(milliseconds: 18));
      yield '$word ';
    }
  }
}
