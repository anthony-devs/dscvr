import 'package:dscvr/data/discover_service.dart';
import 'package:dscvr/data/link_service.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/state/library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryItem _item(String id, String title, List<String> authors, {String summary = ''}) {
  final now = DateTime(2026, 1, 1);
  return LibraryItem(
    id: id,
    kind: MaterialKind.paper,
    title: title,
    categoryId: 'c',
    authors: authors,
    summary: summary,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('LibraryItem', () {
    test('round-trips through a map', () {
      final item = _item('a', 'Attention Is All You Need', ['Ashish Vaswani'], summary: 'Transformers');
      final copy = LibraryItem.fromMap('a', item.toMap());
      expect(copy.title, item.title);
      expect(copy.authors, item.authors);
      expect(copy.kind, MaterialKind.paper);
      expect(copy.summary, 'Transformers');
    });

    test('clamps progress and tolerates missing fields', () {
      final item = LibraryItem.fromMap('x', {'progress': 3, 'kind': 'nonsense'});
      expect(item.progress, 1);
      expect(item.kind, MaterialKind.link);
      expect(item.title, 'Untitled');
    });

    test('abbreviates long author lists', () {
      final item = _item('a', 't', ['A', 'B', 'C', 'D', 'E', 'F']);
      expect(item.authorLine, 'A, B, C, D, E, ...');
    });
  });

  group('LibraryController helpers', () {
    test('author facets are sorted by frequency', () {
      final facets = LibraryController.authorFacets([
        _item('1', 'x', ['Kahneman', 'Tversky']),
        _item('2', 'y', ['Kahneman']),
      ]);
      expect(facets.first, ('Kahneman', 2));
      expect(facets.last, ('Tversky', 1));
    });
  });

  group('LinkService', () {
    test('extracts YouTube ids from common URL shapes', () {
      expect(LinkService.youtubeId('https://www.youtube.com/watch?v=abc123'), 'abc123');
      expect(LinkService.youtubeId('https://youtu.be/abc123'), 'abc123');
      expect(LinkService.youtubeId('https://youtube.com/shorts/abc123'), 'abc123');
      expect(LinkService.youtubeId('https://example.com/watch?v=abc'), isNull);
    });

    test('normalizes bare domains', () {
      expect(LinkService.normalize('arxiv.org/abs/1706.03762'), 'https://arxiv.org/abs/1706.03762');
      expect(LinkService.normalize('not a url'), isNull);
    });
  });

  test('parses arXiv Atom feeds', () {
    const atom = '''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>http://arxiv.org/abs/1706.03762v7</id>
    <published>2017-06-12T17:57:34Z</published>
    <title>Attention Is All
      You Need</title>
    <summary>The dominant sequence transduction models...</summary>
    <author><name>Ashish Vaswani</name></author>
    <author><name>Noam Shazeer</name></author>
    <link title="pdf" href="http://arxiv.org/pdf/1706.03762v7" rel="related" type="application/pdf"/>
    <category term="cs.CL"/>
  </entry>
</feed>''';
    final papers = DiscoverService.parseArxiv(atom);
    expect(papers, hasLength(1));
    expect(papers.first.year, 2017);
    expect(papers.first.authors, ['Ashish Vaswani', 'Noam Shazeer']);
    expect(papers.first.pdfUrl, 'https://arxiv.org/pdf/1706.03762v7');
    expect(papers.first.id, '1706.03762v7');
  });
}
