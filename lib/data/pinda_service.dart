import 'dart:async';
import 'dart:convert';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/pinda.dart';
import 'package:http/http.dart' as http;

typedef TokenProvider = Future<String?> Function();

/// Streams Pinda replies from the `pinda` Cloud Function.
///
/// The function holds the Claude API key, loads the requested library
/// context server-side (so the client can only reference its own data) and
/// streams the answer back as Server-Sent Events:
///   data: {"type":"delta","text":"..."}
///   data: {"type":"done"}
///   data: {"type":"error","message":"..."}
abstract class PindaService {
  Stream<String> reply({
    required List<ChatMessage> history,
    required PindaContext context,
    required String style,
  });
}

class PindaException implements Exception {
  const PindaException(this.message);
  final String message;
  @override
  String toString() => message;
}

class HttpPindaService implements PindaService {
  HttpPindaService({required this.token, http.Client? client}) : _client = client ?? http.Client();

  final TokenProvider token;
  final http.Client _client;

  @override
  Stream<String> reply({
    required List<ChatMessage> history,
    required PindaContext context,
    required String style,
  }) async* {
    final idToken = await token();
    if (idToken == null) throw const PindaException('Sign in to use Pinda.');

    final request = http.Request('POST', Uri.parse('${Env.functionsUrl}/pinda'))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'Authorization': 'Bearer $idToken',
      })
      ..body = jsonEncode({
        'context': {'scope': context.scope.name, 'id': context.id},
        'style': style,
        'messages': [
          for (final m in history.where((m) => m.text.trim().isNotEmpty).toList().reversed.take(24).toList().reversed)
            {'role': m.role.name, 'text': m.text},
        ],
      });

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const PindaException('Could not reach Pinda. Check your connection and that the pinda function is deployed.');
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      String msg = 'Pinda is unavailable right now (${response.statusCode}).';
      try {
        msg = (jsonDecode(body) as Map)['error'] as String? ?? msg;
      } catch (_) {}
      throw PindaException(msg);
    }

    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty) continue;
      final Map<String, dynamic> event;
      try {
        event = jsonDecode(payload) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      switch (event['type']) {
        case 'delta':
          yield event['text'] as String? ?? '';
        case 'error':
          throw PindaException(event['message'] as String? ?? 'Pinda hit an error.');
        case 'done':
          return;
      }
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

Deploy the `pinda` function with your Claude API key to get real answers.''';
    for (final word in text.split(' ')) {
      await Future<void>.delayed(const Duration(milliseconds: 18));
      yield '$word ';
    }
  }
}
