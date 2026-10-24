import 'dart:convert';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/paper.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

enum PaperSource {
  arxiv('arXiv'),
  semanticScholar('Semantic Scholar');

  const PaperSource(this.label);
  final String label;
  String get key => this == PaperSource.arxiv ? 'arxiv' : 'semantic_scholar';
}

/// A subject feed on the Discover page, backed by an arXiv category.
class Subject {
  const Subject(this.label, this.arxivQuery);
  final String label;
  final String arxivQuery;

  static const all = <Subject>[
    Subject('Artificial Intelligence', 'cat:cs.AI'),
    Subject('Machine Learning', 'cat:cs.LG'),
    Subject('Language', 'cat:cs.CL'),
    Subject('Computer Vision', 'cat:cs.CV'),
    Subject('Neuroscience', 'cat:q-bio.NC'),
    Subject('Economics', 'cat:econ.GN OR cat:econ.TH'),
    Subject('Physics', 'cat:physics.gen-ph OR cat:quant-ph'),
    Subject('Mathematics', 'cat:math.ST OR cat:math.PR'),
    Subject('Biology', 'cat:q-bio.GN OR cat:q-bio.BM'),
    Subject('Finance', 'cat:q-fin.GN OR cat:q-fin.ST'),
  ];
}

/// Searches arXiv and Semantic Scholar.
///
/// On the web these APIs do not send CORS headers, so requests go through
/// the `discover` Cloud Function. On iOS/Android we call them directly and
/// only fall back to the function if that fails.
class DiscoverService {
  DiscoverService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<Paper>> search(String query, {PaperSource source = PaperSource.arxiv, int limit = 20}) {
    final q = source == PaperSource.arxiv ? 'all:${query.trim()}' : query.trim();
    return _fetch(source, q, sortByDate: false, limit: limit);
  }

  Future<List<Paper>> latest(Subject subject, {int limit = 20}) =>
      _fetch(PaperSource.arxiv, subject.arxivQuery, sortByDate: true, limit: limit);

  Future<List<Paper>> _fetch(PaperSource source, String q, {required bool sortByDate, required int limit}) async {
    if (Env.demo) return _demoPapers(q);

    // Always try the direct API first (works on native; may work on web
    // for endpoints that send CORS headers, e.g. Semantic Scholar v2).
    try {
      return await _direct(source, q, sortByDate: sortByDate, limit: limit);
    } catch (_) {
      // Direct call failed (CORS on web, or network on native) —
      // fall through to the Cloud Function proxy.
    }

    try {
      final uri = Uri.parse('${Env.functionsUrl}/discover').replace(queryParameters: {
        'source': source.key,
        'q': q,
        'sort': sortByDate ? 'date' : 'relevance',
        'limit': '$limit',
      });
      final res = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('Search failed (${res.statusCode})');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (data['papers'] as List).map((e) => Paper.fromMap((e as Map).cast<String, dynamic>())).toList();
    } catch (e) {
      if (kIsWeb) {
        throw Exception(
          'Could not reach ${source.label}. '
          'Deploy the discover Cloud Function, or run on a mobile device '
          'to bypass CORS restrictions.',
        );
      }
      rethrow;
    }
  }

  Future<List<Paper>> _direct(PaperSource source, String q, {required bool sortByDate, required int limit}) async {
    if (source == PaperSource.arxiv) {
      final uri = Uri.https('export.arxiv.org', '/api/query', {
        'search_query': q,
        'start': '0',
        'max_results': '$limit',
        'sortBy': sortByDate ? 'submittedDate' : 'relevance',
        'sortOrder': 'descending',
      });
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('arXiv ${res.statusCode}');
      return parseArxiv(res.body);
    }
    final uri = Uri.https('api.semanticscholar.org', '/graph/v1/paper/search', {
      'query': q,
      'limit': '$limit',
      'fields': 'title,authors,year,abstract,url,openAccessPdf,venue,citationCount,externalIds',
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('Semantic Scholar ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ((data['data'] as List?) ?? const []).map((raw) {
      final p = (raw as Map).cast<String, dynamic>();
      return Paper(
        id: p['paperId'] as String? ?? '',
        title: p['title'] as String? ?? '',
        source: 'semantic_scholar',
        authors: [for (final a in (p['authors'] as List? ?? const [])) (a as Map)['name'] as String? ?? ''],
        year: (p['year'] as num?)?.toInt(),
        summary: p['abstract'] as String? ?? '',
        url: p['url'] as String?,
        pdfUrl: (p['openAccessPdf'] as Map?)?['url'] as String?,
        venue: p['venue'] as String?,
        citations: (p['citationCount'] as num?)?.toInt(),
      );
    }).toList();
  }

  static List<Paper> parseArxiv(String body) {
    final doc = XmlDocument.parse(body);
    return doc.findAllElements('entry').map((e) {
      String text(String name) => e.getElement(name)?.innerText.trim() ?? '';
      final id = text('id');
      String? pdf;
      for (final link in e.findElements('link')) {
        if (link.getAttribute('title') == 'pdf') pdf = link.getAttribute('href');
      }
      final published = text('published');
      return Paper(
        id: id.split('/abs/').last,
        title: text('title'),
        source: 'arxiv',
        authors: [for (final a in e.findElements('author')) a.getElement('name')?.innerText.trim() ?? ''],
        year: int.tryParse(published.length >= 4 ? published.substring(0, 4) : ''),
        summary: text('summary'),
        url: id.replaceFirst('http://', 'https://'),
        pdfUrl: pdf?.replaceFirst('http://', 'https://'),
        subjects: [for (final c in e.findElements('category')) c.getAttribute('term') ?? ''],
      );
    }).toList();
  }

  /// Short encyclopedia summary for a search term (Wikipedia allows CORS).
  Future<TopicSummary?> summary(String term) async {
    if (Env.demo || term.trim().isEmpty) return null;
    try {
      final title = Uri.encodeComponent(term.trim().replaceAll(' ', '_'));
      final res = await _client
          .get(Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$title?redirect=true'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      if (m['type'] == 'disambiguation') return null;
      return TopicSummary(
        title: m['title'] as String? ?? term,
        extract: m['extract'] as String? ?? '',
        url: ((m['content_urls'] as Map?)?['desktop'] as Map?)?['page'] as String?,
        thumbnail: (m['thumbnail'] as Map?)?['source'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  List<Paper> _demoPapers(String q) {
    const samples = [
      ('Scaling Laws for Neural Language Models', ['Jared Kaplan', 'Sam McCandlish', 'Tom Henighan'], 2020,
          'We study empirical scaling laws for language model performance on the cross-entropy loss.'),
      ('Training Compute-Optimal Large Language Models', ['Jordan Hoffmann', 'Sebastian Borgeaud', 'Arthur Mensch'], 2022,
          'We investigate the optimal model size and number of tokens for training a transformer language model under a given compute budget.'),
      ('Denoising Diffusion Probabilistic Models', ['Jonathan Ho', 'Ajay Jain', 'Pieter Abbeel'], 2020,
          'We present high quality image synthesis results using diffusion probabilistic models.'),
      ('Constitutional AI: Harmlessness from AI Feedback', ['Yuntao Bai', 'Saurav Kadavath', 'Sandipan Kundu'], 2022,
          'We experiment with methods for training a harmless AI assistant through self-improvement.'),
      ('BERT: Pre-training of Deep Bidirectional Transformers', ['Jacob Devlin', 'Ming-Wei Chang', 'Kenton Lee', 'Kristina Toutanova'], 2018,
          'We introduce a new language representation model which stands for Bidirectional Encoder Representations from Transformers.'),
      ('Playing Atari with Deep Reinforcement Learning', ['Volodymyr Mnih', 'Koray Kavukcuoglu', 'David Silver'], 2013,
          'We present the first deep learning model to successfully learn control policies directly from high-dimensional sensory input.'),
    ];
    return [
      for (final (i, s) in samples.indexed)
        Paper(
          id: 'demo-$i-${q.hashCode}',
          title: s.$1,
          source: 'arxiv',
          authors: s.$2,
          year: s.$3,
          summary: s.$4,
          url: 'https://arxiv.org',
          subjects: const ['cs.LG'],
        ),
    ];
  }
}
