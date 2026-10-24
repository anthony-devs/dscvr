import 'dart:async';

import 'package:dscvr/data/library_repository.dart';
import 'package:dscvr/models/library.dart';
import 'package:flutter/foundation.dart';

/// Live, in-memory view of the signed-in user's library.
///
/// Subscribes once to categories, topics and materials and exposes derived
/// queries (counts, author facets, search) so screens never re-query.
class LibraryController extends ChangeNotifier {
  LibraryController(this.repo) {
    _subs = [
      repo.watchCategories().listen((v) {
        _categories = v;
        _catsLoaded = true;
        notifyListeners();
      }, onError: _onError),
      repo.watchTopics().listen((v) {
        _topics = v;
        notifyListeners();
      }, onError: _onError),
      repo.watchItems().listen((v) {
        _items = v;
        _itemsLoaded = true;
        notifyListeners();
      }, onError: _onError),
    ];
  }

  final LibraryRepository repo;
  late final List<StreamSubscription> _subs;

  List<LibraryCategory> _categories = const [];
  List<Topic> _topics = const [];
  List<LibraryItem> _items = const [];
  bool _catsLoaded = false;
  bool _itemsLoaded = false;
  Object? _error;

  List<LibraryCategory> get categories => _categories;
  List<Topic> get topics => _topics;
  List<LibraryItem> get items => _items;
  bool get loaded => _catsLoaded && _itemsLoaded;
  Object? get error => _error;

  void _onError(Object e) {
    _error = e;
    _catsLoaded = true;
    _itemsLoaded = true;
    notifyListeners();
  }

  LibraryCategory? category(String? id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Topic? topic(String? id) {
    for (final t in _topics) {
      if (t.id == id) return t;
    }
    return null;
  }

  LibraryItem? item(String? id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  List<Topic> topicsOf(String categoryId) =>
      _topics.where((t) => t.categoryId == categoryId).toList();

  List<LibraryItem> itemsIn(String categoryId, {String? topicId}) => _items
      .where((i) => i.categoryId == categoryId && (topicId == null || i.topicId == topicId))
      .toList();

  int countIn(String categoryId, {String? topicId}) =>
      itemsIn(categoryId, topicId: topicId).length;

  List<LibraryItem> get recent {
    final list = [..._items]..sort((a, b) => b.recency.compareTo(a.recency));
    return list;
  }

  List<LibraryItem> get inProgress =>
      recent.where((i) => i.progress > 0 && i.progress < 1 && i.kind != MaterialKind.note).toList();

  List<LibraryItem> get readingList =>
      recent.where((i) => i.inReadingList).toList();

  List<LibraryItem> get recentlyAdded =>
      ([..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  /// Authors across [items], most frequent first.
  static List<(String, int)> authorFacets(Iterable<LibraryItem> items) {
    final counts = <String, int>{};
    for (final i in items) {
      for (final a in i.authors) {
        if (a.trim().isEmpty) continue;
        counts[a] = (counts[a] ?? 0) + 1;
      }
    }
    final list = counts.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1));
    return list;
  }

  List<LibraryItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final terms = q.split(RegExp(r'\s+'));
    int score(LibraryItem i) {
      final title = i.title.toLowerCase();
      final authors = i.authors.join(' ').toLowerCase();
      final body = '${i.summary} ${i.content}'.toLowerCase();
      var s = 0;
      for (final t in terms) {
        if (title.contains(t)) {
          s += 5;
        } else if (authors.contains(t)) {
          s += 3;
        } else if (body.contains(t)) {
          s += 1;
        } else {
          return 0;
        }
      }
      return s;
    }

    final scored = [
      for (final i in _items)
        if (score(i) > 0) (i, score(i))
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  int nextCategoryColor() => _categories.length % 12;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
