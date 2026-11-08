import 'dart:async';
import 'dart:convert';

import 'package:dscvr/config/env.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef TokenProvider = Future<String?> Function();

class ApiException implements Exception {
  const ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Talks to the DSCVR server: JSON calls and Server-Sent Event streams.
///
/// Every signed-in call carries the Firebase ID token; the server verifies it
/// and only ever reads the caller's own data.
class DscvrApi {
  DscvrApi({required this.token, http.Client? client}) : _client = client ?? http.Client();

  final TokenProvider token;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${Env.serverUrl}$path').replace(queryParameters: query == null || query.isEmpty ? null : query);

  Future<Map<String, String>> _headers({bool auth = true, bool json = false}) async {
    final h = <String, String>{if (json) 'Content-Type': 'application/json'};
    if (auth) {
      final t = await token();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query, bool auth = true}) async {
    final http.Response res;
    try {
      res = await _client.get(_uri(path, query), headers: await _headers(auth: auth)).timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('GET $path failed: $e');
      throw const ApiException("Couldn't reach DSCVR. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final http.Response res;
    try {
      res = await _client
          .post(_uri(path), headers: await _headers(json: true), body: jsonEncode(body ?? const {}))
          .timeout(const Duration(seconds: 120));
    } catch (e) {
      debugPrint('POST $path failed: $e');
      throw const ApiException("Couldn't reach DSCVR. Check your connection and try again.");
    }
    return _decode(res);
  }

  /// Raw bytes (PDFs) from a signed-in endpoint.
  Future<List<int>> getBytes(String path, {Map<String, String>? query}) async {
    final http.Response res;
    try {
      res = await _client.get(_uri(path, query), headers: await _headers()).timeout(const Duration(seconds: 90));
    } catch (e) {
      throw const ApiException("Couldn't reach DSCVR. Check your connection and try again.");
    }
    if (res.statusCode != 200) _decode(res);
    return res.bodyBytes;
  }

  /// Headers for widgets that fetch by themselves (the PDF viewer).
  Future<Map<String, String>> authHeaders() => _headers();

  Uri uri(String path, [Map<String, String>? query]) => _uri(path, query);

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> body = const {};
    try {
      body = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(body['error'] as String? ?? _fallback(res.statusCode), status: res.statusCode);
  }

  static String _fallback(int status) => switch (status) {
        401 => 'Sign in again to continue.',
        403 => "You don't have access to that.",
        404 => 'Not found.',
        429 => 'Too many requests. Wait a moment and try again.',
        _ => 'Something went wrong on our side ($status).',
      };

  /// POSTs and yields text deltas from a `text/event-stream` reply:
  ///   data: {"type":"delta","text":"..."} / {"type":"done"} / {"type":"error","message":"..."}
  Stream<String> stream(String path, Map<String, dynamic> body) async* {
    final request = http.Request('POST', _uri(path))
      ..headers.addAll({...await _headers(json: true), 'Accept': 'text/event-stream'})
      ..body = jsonEncode(body);

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(const Duration(seconds: 45));
    } catch (e) {
      debugPrint('STREAM $path failed: $e');
      throw const ApiException("Couldn't reach Pinda. Check your connection and try again.");
    }
    if (response.statusCode != 200) {
      final text = await response.stream.bytesToString();
      String msg = _fallback(response.statusCode);
      try {
        msg = (jsonDecode(text) as Map)['error'] as String? ?? msg;
      } catch (_) {}
      throw ApiException(msg, status: response.statusCode);
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
          throw ApiException(event['message'] as String? ?? 'Pinda hit an error.');
        case 'done':
          return;
      }
    }
  }
}
