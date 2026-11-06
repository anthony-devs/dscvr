import 'dart:convert';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/paper.dart';
import 'package:dscvr/models/subjects.dart';

export 'package:dscvr/models/subjects.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

enum PaperSource {
  arxiv('arXiv', 'arxiv'),
  semanticScholar('Semantic Scholar', 'semantic_scholar'),
  openAlex('All fields', 'openalex');

  const PaperSource(this.label, this.key);
  final String label;

  /// Name the server uses for this source.
  final String key;
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

  /// Newest papers in a subject: arXiv preprints where arXiv covers the
  /// subject, otherwise recent journal articles from OpenAlex (any field).
  Future<List<Paper>> latest(Subject subject, {int limit = 20}) => subject.usesArxiv
      ? _fetch(PaperSource.arxiv, subject.arxiv!, sortByDate: true, limit: limit)
      : _fetch(PaperSource.openAlex, subject.label, sortByDate: true, limit: limit);

  /// Results are cached for 10 minutes so switching subjects back and forth
  /// is instant and we stay well inside the providers' rate limits.
  static const _ttl = Duration(minutes: 10);
  final _cache = <String, (DateTime, List<Paper>)>{};

  Future<List<Paper>> _fetch(PaperSource source, String q, {required bool sortByDate, required int limit}) async {
    if (Env.demo) return _demoPapers(q);

    final key = '${source.key}|$q|$sortByDate|$limit';
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.$1) < _ttl) return hit.$2;

    final papers = await _fetchUncached(source, q, sortByDate: sortByDate, limit: limit);
    if (_cache.length > 100) _cache.remove(_cache.keys.first);
    _cache[key] = (DateTime.now(), papers);
    return papers;
  }

  Future<List<Paper>> _fetchUncached(PaperSource source, String q, {required bool sortByDate, required int limit}) async {
    // Browsers block direct calls to arXiv and Semantic Scholar (no CORS
    // headers, plus shared rate limits), so the web build always goes through
    // the DSCVR server. Native apps try the provider first and fall back.
    if (!kIsWeb && source != PaperSource.openAlex) {
      try {
        return await _direct(source, q, sortByDate: sortByDate, limit: limit);
      } catch (_) {
        // Fall through to the server.
      }
    }
    return _viaServer(source, q, sortByDate: sortByDate, limit: limit);
  }

  Future<List<Paper>> _viaServer(PaperSource source, String q, {required bool sortByDate, required int limit}) async {
    final uri = Uri.parse('${Env.serverUrl}/discover').replace(queryParameters: {
      'source': source.key,
      'q': q,
      'sort': sortByDate ? 'date' : 'relevance',
      'limit': '$limit',
    });
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 25));
    } catch (e) {
      debugPrint('Discover: could not reach ${Env.serverUrl}: $e');
      throw Exception("Couldn't reach the search server. Check your connection and try again.");
    }
    if (res.statusCode == 429) {
      throw Exception('Too many searches in a short time. Wait a minute and try again.');
    }
    if (res.statusCode != 200) {
      debugPrint('Discover: ${res.statusCode} ${res.body}');
      throw Exception('${source.label} is not responding right now. Try again shortly, or switch source.');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['papers'] as List).map((e) => Paper.fromMap((e as Map).cast<String, dynamic>())).toList();
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
