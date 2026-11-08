import 'dart:convert';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/paper.dart';
import 'package:dscvr/models/subjects.dart';

export 'package:dscvr/models/subjects.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

enum PaperSource {
  all('All sources', 'all', 'arXiv, Semantic Scholar, OpenAlex, Europe PMC, Crossref, DOAJ, PLOS, Zenodo and more'),
  europePmc('Health & clinical', 'europepmc', 'PubMed, PMC and clinical guidelines'),
  ukCaseLaw('UK case law', 'uk_caselaw', 'Judgments from UK courts (Find Case Law)'),
  // Used for subject feeds; not offered as separate search choices.
  openAlex('OpenAlex', 'openalex', 'Journals and books in every discipline'),
  arxiv('arXiv', 'arxiv', 'Preprints in science, maths and computing'),
  semanticScholar('Semantic Scholar', 'semantic_scholar', 'Papers with citation counts');

  /// What the search box offers.
  static const searchable = [all, europePmc, ukCaseLaw];

  const PaperSource(this.label, this.key, this.blurb);
  final String label;

  /// Name the server uses for this source.
  final String key;
  final String blurb;

  static PaperSource forFeed(Feed f) => switch (f) {
        Feed.arxiv => arxiv,
        Feed.europepmc => europePmc,
        Feed.caselaw => ukCaseLaw,
        Feed.openalex => openAlex,
      };
}

/// Free legal information institutes. Their terms don't allow automated
/// search or AI use, so DSCVR opens their own search pages instead.
class LawLibrary {
  const LawLibrary(this.name, this.country, this._search);
  final String name;
  final String country;
  final String _search;

  Uri searchUri(String q) => Uri.parse(_search.replaceAll('{q}', Uri.encodeQueryComponent(q)));

  static const all = [
    LawLibrary('NigeriaLII', 'Nigeria', 'https://nigerialii.org/search/?q={q}'),
    LawLibrary('GhaLII', 'Ghana', 'https://ghalii.org/search/?q={q}'),
    LawLibrary('Kenya Law', 'Kenya', 'https://new.kenyalaw.org/search/?q={q}'),
    LawLibrary('SAFLII', 'South Africa', 'https://www.saflii.org/cgi-bin/sinosrch-adw.cgi?query={q}'),
    LawLibrary('ULII', 'Uganda', 'https://ulii.org/search/?q={q}'),
    LawLibrary('CommonLII', 'Commonwealth', 'https://www.commonlii.org/cgi-bin/sinosrch.cgi?query={q}'),
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

  Future<List<Paper>> search(String query,
      {PaperSource source = PaperSource.all, int limit = 20, bool guidelines = false, bool openAccess = false}) {
    final q = source == PaperSource.arxiv ? 'all:${query.trim()}' : query.trim();
    return _fetch(source, q, sortByDate: false, limit: limit, guidelines: guidelines, openAccess: openAccess);
  }

  /// Which sources answered the last combined search ({name: count | "busy"}).
  Map<String, Object?> lastSources = const {};

  /// Newest items in a subject from the subject's feed: arXiv preprints,
  /// Europe PMC for health, UK judgments for law, OpenAlex for the rest.
  Future<List<Paper>> latest(Subject subject, {int limit = 20, bool? guidelines}) =>
      _fetch(PaperSource.forFeed(subject.feed), subject.searchText,
          sortByDate: true, limit: limit, guidelines: guidelines ?? subject.guidelines);

  /// Results are cached for 10 minutes so switching subjects back and forth
  /// is instant and we stay well inside the providers' rate limits.
  static const _ttl = Duration(minutes: 10);
  final _cache = <String, (DateTime, List<Paper>)>{};

  Future<List<Paper>> _fetch(PaperSource source, String q,
      {required bool sortByDate, required int limit, bool guidelines = false, bool openAccess = false}) async {
    if (Env.demo) return _demoPapers(q);

    final key = '${source.key}|$q|$sortByDate|$limit|$guidelines|$openAccess';
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.$1) < _ttl) return hit.$2;

    final papers = await _fetchUncached(source, q, sortByDate: sortByDate, limit: limit, guidelines: guidelines, openAccess: openAccess);
    if (_cache.length > 100) _cache.remove(_cache.keys.first);
    _cache[key] = (DateTime.now(), papers);
    return papers;
  }

  Future<List<Paper>> _fetchUncached(PaperSource source, String q,
      {required bool sortByDate, required int limit, bool guidelines = false, bool openAccess = false}) async {
    // Browsers block direct calls to arXiv and Semantic Scholar (no CORS
    // headers, plus shared rate limits), so the web build always goes through
    // the DSCVR server. Native apps try the provider first and fall back.
    if (!kIsWeb && (source == PaperSource.arxiv || source == PaperSource.semanticScholar)) {
      try {
        return await _direct(source, q, sortByDate: sortByDate, limit: limit);
      } catch (_) {
        // Fall through to the server.
      }
    }
    return _viaServer(source, q, sortByDate: sortByDate, limit: limit, guidelines: guidelines, openAccess: openAccess);
  }

  Future<List<Paper>> _viaServer(PaperSource source, String q,
      {required bool sortByDate, required int limit, bool guidelines = false, bool openAccess = false}) async {
    final uri = Uri.parse('${Env.serverUrl}/discover').replace(queryParameters: {
      'source': source.key,
      'q': q,
      'sort': sortByDate ? 'date' : 'relevance',
      'limit': '$limit',
      if (guidelines) 'type': 'guidelines',
      if (openAccess) 'oa': '1',
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
    if (data['sources'] is Map) lastSources = (data['sources'] as Map).cast<String, Object?>();
    var papers = (data['papers'] as List).map((e) => Paper.fromMap((e as Map).cast<String, dynamic>())).toList();
    if (openAccess && source != PaperSource.all) papers = [for (final p in papers) if (p.pdfUrl != null || p.openAccess) p];
    return papers;
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
          pdfUrl: i.isEven ? 'https://arxiv.org/pdf/1706.03762' : null,
          subjects: const ['cs.LG'],
          sources: i.isEven ? const ['arxiv', 'semantic_scholar', 'openalex'] : const ['openalex', 'crossref'],
        ),
    ];
  }
}
