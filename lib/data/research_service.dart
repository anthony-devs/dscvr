import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/api.dart';
import 'package:dscvr/data/library_repository.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/paper.dart';
import 'package:dscvr/models/workspace.dart';
import 'package:flutter/foundation.dart';

/// arXiv lookup, PDF import, related papers and community ratings.
class ResearchService {
  ResearchService(this.api);
  final DscvrApi api;

  static final _arxivId = RegExp(
    r'(?:arxiv\.org/(?:abs|pdf|html)/|arxiv:\s*)?(\d{4}\.\d{4,5}(?:v\d+)?|[a-z-]+(?:\.[A-Z]{2})?/\d{7}(?:v\d+)?)',
    caseSensitive: false,
  );

  /// The arXiv id in [text] (an id, abs/pdf URL or "arXiv:" reference).
  static String? arxivId(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final m = _arxivId.firstMatch(t);
    if (m == null) return null;
    // Avoid treating a plain search phrase with a number in it as an id.
    final looksLikeRef = t.contains('arxiv') || t.toLowerCase().startsWith('arxiv') || m.group(0) == t;
    return looksLikeRef ? m.group(1) : null;
  }

  Future<Paper> arxiv(String ref) async {
    if (Env.demo) {
      return Paper(
        id: arxivId(ref) ?? '1706.03762',
        title: 'Attention Is All You Need',
        source: 'arxiv',
        authors: const ['Ashish Vaswani', 'Noam Shazeer', 'Niki Parmar'],
        year: 2017,
        summary: 'The dominant sequence transduction models are based on complex recurrent or convolutional neural networks...',
        url: 'https://arxiv.org/abs/1706.03762',
        pdfUrl: 'https://arxiv.org/pdf/1706.03762',
      );
    }
    final body = await api.get('/arxiv', query: {'ref': ref});
    return Paper.fromMap((body['paper'] as Map).cast<String, dynamic>());
  }

  /// Copies a public PDF into the user's own storage and points the item at
  /// it, so it opens offline and Pinda can read the whole document.
  Future<bool> importPdf(LibraryRepository repo, LibraryItem item) async {
    final url = item.pdfUrl;
    if (Env.demo || url == null || url.isEmpty || item.pdfInLibrary) return false;
    try {
      final body = await api.post('/pdf/import', {'url': url, 'itemId': item.id});
      await repo.attachPdf(item.id, storagePath: body['storagePath'] as String, pdfUrl: body['url'] as String);
      return true;
    } catch (e) {
      debugPrint('PDF import failed for ${item.id}: $e');
      return false;
    }
  }

  Future<List<Paper>> related(LibraryItem item) async {
    if (Env.demo) return const [];
    final body = await api.get('/related', auth: false, query: {
      if (item.source != null) 'source': item.source!,
      if (item.externalId != null) 'externalId': item.externalId!,
      'title': item.title,
    });
    return [for (final p in (body['papers'] as List? ?? const [])) Paper.fromMap((p as Map).cast<String, dynamic>())];
  }

  Future<Map<String, PaperRating>> ratings(List<String> keys) async {
    if (keys.isEmpty || Env.demo) return const {};
    try {
      final body = await api.get('/ratings', query: {'keys': keys.take(50).join(',')});
      final m = (body['ratings'] as Map? ?? const {}).cast<String, dynamic>();
      return {for (final e in m.entries) e.key: PaperRating.fromMap((e.value as Map?)?.cast<String, dynamic>())};
    } catch (_) {
      return const {};
    }
  }

  Future<PaperRating> rate(String key, int stars, String title) async {
    if (Env.demo) return PaperRating(average: stars.toDouble(), count: 1, mine: stars);
    final body = await api.post('/ratings', {'key': key, 'stars': stars, 'title': title});
    return PaperRating.fromMap(body);
  }

  static String paperKey(Paper p) => '${p.source}:${p.id.replaceAll(RegExp(r'v\d+$'), '')}';
}
