import 'dart:convert';

import 'package:dscvr/data/discover_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('searchPage sends offset and reads hasMore', () async {
    final seen = <Uri>[];
    final svc = DiscoverService(client: MockClient((req) async {
      seen.add(req.url);
      final offset = int.parse(req.url.queryParameters['offset'] ?? '0');
      final papers = [
        for (var i = offset; i < offset + 20 && i < 30; i++) {'id': '$i', 'title': 'Paper $i', 'source': 'openalex'}
      ];
      return http.Response(jsonEncode({'papers': papers, 'hasMore': offset + 20 < 30, 'sources': {'openalex': 30}}), 200);
    }));
    final first = await svc.searchPage('cells');
    expect(first.papers.length, 20);
    expect(first.hasMore, isTrue);
    expect(seen.last.queryParameters.containsKey('offset'), isFalse);
    final second = await svc.searchPage('cells', offset: first.consumed);
    expect(seen.last.queryParameters['offset'], '20');
    expect(second.papers.length, 10);
    expect(second.hasMore, isFalse);
    expect(svc.lastSources, {'openalex': 30});
  });

  test('older servers without hasMore: a full page means more', () async {
    final svc = DiscoverService(client: MockClient((req) async => http.Response(
        jsonEncode({'papers': [for (var i = 0; i < 20; i++) {'id': '$i', 'title': 't$i', 'source': 'arxiv'}]}), 200)));
    final page = await svc.searchPage('x', source: PaperSource.europePmc);
    expect(page.hasMore, isTrue);
  });
}
