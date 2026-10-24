import 'package:flutter/foundation.dart';

/// A search result from Discover (arXiv or Semantic Scholar).
@immutable
class Paper {
  const Paper({
    required this.id,
    required this.title,
    required this.source,
    this.authors = const [],
    this.year,
    this.summary = '',
    this.url,
    this.pdfUrl,
    this.venue,
    this.citations,
    this.subjects = const [],
  });

  final String id;
  final String title;
  final String source;
  final List<String> authors;
  final int? year;
  final String summary;
  final String? url;
  final String? pdfUrl;
  final String? venue;
  final int? citations;
  final List<String> subjects;

  String get sourceLabel =>
      source == 'arxiv' ? 'arXiv' : (source == 'semantic_scholar' ? 'Semantic Scholar' : source);

  factory Paper.fromMap(Map<String, dynamic> m) => Paper(
        id: m['id'] as String? ?? '',
        title: (m['title'] as String? ?? '').replaceAll(RegExp(r'\s+'), ' ').trim(),
        source: m['source'] as String? ?? '',
        authors: (m['authors'] as List?)?.whereType<String>().toList() ?? const [],
        year: (m['year'] as num?)?.toInt(),
        summary: (m['summary'] as String? ?? '').replaceAll(RegExp(r'\s+'), ' ').trim(),
        url: m['url'] as String?,
        pdfUrl: m['pdfUrl'] as String?,
        venue: m['venue'] as String?,
        citations: (m['citations'] as num?)?.toInt(),
        subjects: (m['subjects'] as List?)?.whereType<String>().toList() ?? const [],
      );
}

/// Short encyclopedia summary shown above Discover results.
@immutable
class TopicSummary {
  const TopicSummary({required this.title, required this.extract, this.url, this.thumbnail});
  final String title;
  final String extract;
  final String? url;
  final String? thumbnail;
}

/// Metadata returned when unfurling a link.
@immutable
class LinkPreview {
  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.siteName,
    this.image,
    this.authors = const [],
    this.year,
    this.text = '',
    this.isPdf = false,
  });

  final String url;
  final String? title;
  final String? description;
  final String? siteName;
  final String? image;
  final List<String> authors;
  final int? year;
  final String text;
  final bool isPdf;

  factory LinkPreview.fromMap(String url, Map<String, dynamic> m) => LinkPreview(
        url: url,
        title: m['title'] as String?,
        description: m['description'] as String?,
        siteName: m['siteName'] as String?,
        image: m['image'] as String?,
        authors: (m['authors'] as List?)?.whereType<String>().toList() ?? const [],
        year: (m['year'] as num?)?.toInt(),
        text: m['text'] as String? ?? '',
        isPdf: m['isPdf'] as bool? ?? false,
      );
}
