import 'dart:convert';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/paper.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

/// Fetches metadata and readable text for links and YouTube videos.
///
/// Uses the `unfurl` Cloud Function (required on web because of CORS) and
/// falls back to fetching the page directly on mobile.
class LinkService {
  LinkService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static String? youtubeId(String url) {
    final u = Uri.tryParse(url.trim());
    if (u == null) return null;
    if (u.host.contains('youtu.be')) {
      return u.pathSegments.isNotEmpty ? u.pathSegments.first : null;
    }
    if (u.host.contains('youtube.com')) {
      if (u.queryParameters['v'] != null) return u.queryParameters['v'];
      final segs = u.pathSegments;
      final i = segs.indexWhere((s) => s == 'shorts' || s == 'embed' || s == 'live');
      if (i >= 0 && i + 1 < segs.length) return segs[i + 1];
    }
    return null;
  }

  static String youtubeThumb(String id) => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';

  static String? normalize(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
    final u = Uri.tryParse(s);
    if (u == null || !u.host.contains('.')) return null;
    return u.toString();
  }

  Future<LinkPreview> unfurl(String url) async {
    if (Env.demo) {
      final host = Uri.parse(url).host.replaceFirst('www.', '');
      return LinkPreview(url: url, title: 'Saved from $host', siteName: host, description: 'Link preview is simulated in demo mode.');
    }
    try {
      final res = await _client
          .post(Uri.parse('${Env.functionsUrl}/unfurl'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode({'url': url}))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        return LinkPreview.fromMap(url, jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // try direct below
    }
    if (kIsWeb) return LinkPreview(url: url, title: Uri.parse(url).host);
    return _direct(url);
  }

  Future<LinkPreview> _direct(String url) async {
    final res = await _client.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0 DSCVR'}).timeout(const Duration(seconds: 20));
    final type = res.headers['content-type'] ?? '';
    if (type.contains('pdf')) {
      return LinkPreview(url: url, title: Uri.parse(url).pathSegments.lastOrNull ?? url, isPdf: true);
    }
    final doc = html.parse(res.body);
    String? meta(String key) {
      final el = doc.querySelector('meta[property="$key"]') ?? doc.querySelector('meta[name="$key"]');
      final v = el?.attributes['content']?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    final authors = doc
        .querySelectorAll('meta[name="citation_author"], meta[name="author"]')
        .map((e) => e.attributes['content']?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final dateStr = meta('citation_publication_date') ?? meta('article:published_time') ?? meta('citation_date');
    return LinkPreview(
      url: url,
      title: meta('citation_title') ?? meta('og:title') ?? doc.querySelector('title')?.text.trim(),
      description: meta('og:description') ?? meta('description'),
      siteName: meta('og:site_name') ?? Uri.parse(url).host.replaceFirst('www.', ''),
      image: meta('og:image'),
      authors: authors,
      year: dateStr == null ? null : int.tryParse(RegExp(r'(19|20)\d{2}').stringMatch(dateStr) ?? ''),
      text: readableText(doc),
    );
  }

  /// Very small readability pass: prefers <article>/<main>, keeps headings,
  /// paragraphs and list items, returns markdown-ish text.
  static String readableText(dom.Document doc) {
    for (final sel in ['script', 'style', 'nav', 'footer', 'header', 'aside', 'form', 'noscript']) {
      for (final e in doc.querySelectorAll(sel)) {
        e.remove();
      }
    }
    final root = doc.querySelector('article') ?? doc.querySelector('main') ?? doc.body;
    if (root == null) return '';
    final out = StringBuffer();
    for (final e in root.querySelectorAll('h1, h2, h3, p, li, blockquote')) {
      final t = e.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (t.length < 2) continue;
      switch (e.localName) {
        case 'h1':
        case 'h2':
          out.writeln('\n## $t\n');
        case 'h3':
          out.writeln('\n### $t\n');
        case 'li':
          out.writeln('- $t');
        case 'blockquote':
          out.writeln('> $t\n');
        default:
          if (t.length > 40) out.writeln('$t\n');
      }
    }
    final s = out.toString().trim();
    return s.length > 60000 ? s.substring(0, 60000) : s;
  }
}
