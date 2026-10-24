import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Library structure: LibraryCategory -> Topic -> Material.
///
/// Firestore layout (all under users/{uid}):
///   categories/{id}
///   topics/{id}            (categoryId)
///   materials/{id}         (categoryId, topicId?)
///   materials/{id}/notes/{id}
///   conversations/{id}/messages/{id}

DateTime _date(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);

List<String> _strings(Object? v) =>
    (v is List) ? v.whereType<String>().toList() : const <String>[];

@immutable
class LibraryCategory {
  const LibraryCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.colorIndex = 0,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final int colorIndex;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory LibraryCategory.fromMap(String id, Map<String, dynamic> m) => LibraryCategory(
        id: id,
        name: m['name'] as String? ?? 'Untitled',
        description: m['description'] as String? ?? '',
        colorIndex: (m['colorIndex'] as num?)?.toInt() ?? 0,
        order: (m['order'] as num?)?.toInt() ?? 0,
        createdAt: _date(m['createdAt']),
        updatedAt: _date(m['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'colorIndex': colorIndex,
        'order': order,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  LibraryCategory copyWith({String? name, String? description, int? colorIndex}) =>
      LibraryCategory(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        colorIndex: colorIndex ?? this.colorIndex,
        order: order,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

@immutable
class Topic {
  const Topic({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description = '',
    this.colorIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String categoryId;
  final String name;
  final String description;
  final int colorIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Topic.fromMap(String id, Map<String, dynamic> m) => Topic(
        id: id,
        categoryId: m['categoryId'] as String? ?? '',
        name: m['name'] as String? ?? 'Untitled',
        description: m['description'] as String? ?? '',
        colorIndex: (m['colorIndex'] as num?)?.toInt() ?? 0,
        createdAt: _date(m['createdAt']),
        updatedAt: _date(m['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'categoryId': categoryId,
        'name': name,
        'description': description,
        'colorIndex': colorIndex,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  Topic copyWith({String? name, String? description, int? colorIndex}) =>
      Topic(
        id: id,
        categoryId: categoryId,
        name: name ?? this.name,
        description: description ?? this.description,
        colorIndex: colorIndex ?? this.colorIndex,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

enum MaterialKind {
  paper('Paper'),
  pdf('PDF'),
  link('Article'),
  note('Note'),
  youtube('Video');

  const MaterialKind(this.label);
  final String label;

  static MaterialKind parse(String? v) =>
      MaterialKind.values.firstWhere((e) => e.name == v,
          orElse: () => MaterialKind.link);
}

/// A single item in the library: a paper, PDF, web article, note or video.
///
/// Named [LibraryItem] rather than `Material` to avoid clashing with
/// Flutter's Material widget.
@immutable
class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.categoryId,
    this.topicId,
    this.authors = const [],
    this.year,
    this.url,
    this.pdfUrl,
    this.storagePath,
    this.fileName,
    this.summary = '',
    this.content = '',
    this.thumbnailUrl,
    this.siteName,
    this.source,
    this.externalId,
    this.progress = 0,
    this.noteCount = 0,
    this.colorIndex = 0,
    this.inReadingList = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
  });

  final String id;
  final MaterialKind kind;
  final String title;
  final String categoryId;
  final String? topicId;
  final List<String> authors;
  final int? year;

  /// Web URL for links, videos and papers; download URL for uploaded PDFs.
  final String? url;

  /// Direct PDF link (uploaded file or open-access paper PDF).
  final String? pdfUrl;
  final String? storagePath;
  final String? fileName;

  /// Abstract or short description shown on cards and given to Pinda.
  final String summary;

  /// Full text for notes (markdown) and extracted article text for links.
  final String content;
  final String? thumbnailUrl;
  final String? siteName;

  /// Where a paper came from: 'arxiv', 'semantic_scholar'.
  final String? source;
  final String? externalId;

  /// Reading progress between 0 and 1.
  final double progress;
  final int noteCount;
  final int colorIndex;
  final bool inReadingList;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;

  bool get hasPdf => (pdfUrl != null && pdfUrl!.isNotEmpty);

  String get authorLine {
    if (authors.isEmpty) return siteName ?? '';
    if (authors.length <= 5) return authors.join(', ');
    return '${authors.take(5).join(', ')}, ...';
  }

  DateTime get recency => lastOpenedAt ?? updatedAt;

  factory LibraryItem.fromMap(String id, Map<String, dynamic> m) =>
      LibraryItem(
        id: id,
        kind: MaterialKind.parse(m['kind'] as String?),
        title: m['title'] as String? ?? 'Untitled',
        categoryId: m['categoryId'] as String? ?? '',
        topicId: m['topicId'] as String?,
        authors: _strings(m['authors']),
        year: (m['year'] as num?)?.toInt(),
        url: m['url'] as String?,
        pdfUrl: m['pdfUrl'] as String?,
        storagePath: m['storagePath'] as String?,
        fileName: m['fileName'] as String?,
        summary: m['summary'] as String? ?? '',
        content: m['content'] as String? ?? '',
        thumbnailUrl: m['thumbnailUrl'] as String?,
        siteName: m['siteName'] as String?,
        source: m['source'] as String?,
        externalId: m['externalId'] as String?,
        progress: ((m['progress'] as num?)?.toDouble() ?? 0).clamp(0, 1),
        noteCount: (m['noteCount'] as num?)?.toInt() ?? 0,
        colorIndex: (m['colorIndex'] as num?)?.toInt() ?? 0,
        inReadingList: m['inReadingList'] as bool? ?? false,
        createdAt: _date(m['createdAt']),
        updatedAt: _date(m['updatedAt']),
        lastOpenedAt: _dateOrNull(m['lastOpenedAt']),
      );

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'title': title,
        'categoryId': categoryId,
        'topicId': topicId,
        'authors': authors,
        'year': year,
        'url': url,
        'pdfUrl': pdfUrl,
        'storagePath': storagePath,
        'fileName': fileName,
        'summary': summary,
        'content': content,
        'thumbnailUrl': thumbnailUrl,
        'siteName': siteName,
        'source': source,
        'externalId': externalId,
        'progress': progress,
        'noteCount': noteCount,
        'colorIndex': colorIndex,
        'inReadingList': inReadingList,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'lastOpenedAt': lastOpenedAt,
      };

  LibraryItem copyWith({
    String? title,
    String? categoryId,
    String? topicId,
    bool clearTopic = false,
    List<String>? authors,
    int? year,
    String? url,
    String? summary,
    String? content,
    double? progress,
    int? noteCount,
    int? colorIndex,
    bool? inReadingList,
    DateTime? lastOpenedAt,
  }) =>
      LibraryItem(
        id: id,
        kind: kind,
        title: title ?? this.title,
        categoryId: categoryId ?? this.categoryId,
        topicId: clearTopic ? null : (topicId ?? this.topicId),
        authors: authors ?? this.authors,
        year: year ?? this.year,
        url: url ?? this.url,
        pdfUrl: pdfUrl,
        storagePath: storagePath,
        fileName: fileName,
        summary: summary ?? this.summary,
        content: content ?? this.content,
        thumbnailUrl: thumbnailUrl,
        siteName: siteName,
        source: source,
        externalId: externalId,
        progress: progress ?? this.progress,
        noteCount: noteCount ?? this.noteCount,
        colorIndex: colorIndex ?? this.colorIndex,
        inReadingList: inReadingList ?? this.inReadingList,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      );
}

/// A margin note attached to a material.
@immutable
class ItemNote {
  const ItemNote({
    required this.id,
    required this.text,
    this.quote,
    this.page,
    required this.createdAt,
  });

  final String id;
  final String text;

  /// Optional passage the note refers to.
  final String? quote;
  final int? page;
  final DateTime createdAt;

  factory ItemNote.fromMap(String id, Map<String, dynamic> m) => ItemNote(
        id: id,
        text: m['text'] as String? ?? '',
        quote: m['quote'] as String?,
        page: (m['page'] as num?)?.toInt(),
        createdAt: _date(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'text': text,
        'quote': quote,
        'page': page,
        'createdAt': createdAt,
      };
}

/// Sort orders offered on library grids.
enum ItemSort {
  recentlyAccessed('Recently accessed'),
  recentlyAdded('Recently added'),
  title('Title'),
  year('Year');

  const ItemSort(this.label);
  final String label;

  int compare(LibraryItem a, LibraryItem b) {
    switch (this) {
      case ItemSort.recentlyAccessed:
        return b.recency.compareTo(a.recency);
      case ItemSort.recentlyAdded:
        return b.createdAt.compareTo(a.createdAt);
      case ItemSort.title:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case ItemSort.year:
        return (b.year ?? 0).compareTo(a.year ?? 0);
    }
  }
}
