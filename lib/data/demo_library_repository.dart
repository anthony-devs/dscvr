import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dscvr/data/library_repository.dart';
import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/edition.dart';
import 'package:dscvr/models/pinda.dart';
import 'package:dscvr/models/workspace.dart';

/// Holds a value and replays it to every new listener.
class _Live<T> {
  _Live(this._value);
  T _value;
  final _controller = StreamController<T>.broadcast();

  T get value => _value;
  set value(T v) {
    _value = v;
    _controller.add(v);
  }

  Stream<T> get stream async* {
    yield _value;
    yield* _controller.stream;
  }
}

/// In-memory library seeded with sample research material.
///
/// Enabled with --dart-define=DSCVR_DEMO=true. Nothing is persisted.
class DemoLibraryRepository implements LibraryRepository {
  DemoLibraryRepository() {
    _seed();
    seedReport(_items.value.where((i) => i.kind == MaterialKind.paper).take(2).map((i) => i.id).toList());
  }

  final _rand = Random(7);
  final _categories = _Live<List<LibraryCategory>>([]);
  final _topics = _Live<List<Topic>>([]);
  final _items = _Live<List<LibraryItem>>([]);
  final _notes = <String, _Live<List<ItemNote>>>{};
  final _conversations = _Live<List<Conversation>>([]);
  final _messages = <String, _Live<List<ChatMessage>>>{};
  final _reports = _Live<List<Report>>([]);
  final _sessions = _Live<List<FocusSession>>([]);
  int _counter = 0;

  @override
  String newId() => 'demo_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  _Live<List<ItemNote>> _notesFor(String id) => _notes.putIfAbsent(id, () => _Live([]));
  _Live<List<ChatMessage>> _messagesFor(String id) => _messages.putIfAbsent(id, () => _Live([]));

  @override
  Stream<List<LibraryCategory>> watchCategories() => _categories.stream;
  @override
  Stream<List<Topic>> watchTopics() => _topics.stream;
  @override
  Stream<List<LibraryItem>> watchItems() => _items.stream;

  @override
  Future<LibraryCategory> createCategory({required String name, String description = '', required int colorIndex}) async {
    final now = DateTime.now();
    final c = LibraryCategory(
        id: newId(), name: name, description: description, colorIndex: colorIndex,
        order: now.millisecondsSinceEpoch, createdAt: now, updatedAt: now);
    _categories.value = [..._categories.value, c];
    return c;
  }

  @override
  Future<void> updateCategory(LibraryCategory category) async {
    _categories.value = [for (final c in _categories.value) c.id == category.id ? category : c];
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    _categories.value = _categories.value.where((c) => c.id != categoryId).toList();
    _topics.value = _topics.value.where((t) => t.categoryId != categoryId).toList();
    _items.value = _items.value.where((i) => i.categoryId != categoryId).toList();
  }

  @override
  Future<Topic> createTopic({required String categoryId, required String name, String description = '', required int colorIndex}) async {
    final now = DateTime.now();
    final t = Topic(id: newId(), categoryId: categoryId, name: name, description: description,
        colorIndex: colorIndex, createdAt: now, updatedAt: now);
    _topics.value = [..._topics.value, t];
    return t;
  }

  @override
  Future<void> updateTopic(Topic topic) async {
    _topics.value = [for (final t in _topics.value) t.id == topic.id ? topic : t];
  }

  @override
  Future<void> deleteTopic(String topicId) async {
    _topics.value = _topics.value.where((t) => t.id != topicId).toList();
    _items.value = [
      for (final i in _items.value) i.topicId == topicId ? i.copyWith(clearTopic: true) : i
    ];
  }

  @override
  Future<LibraryItem?> getItem(String id) async {
    for (final i in _items.value) {
      if (i.id == id) return i;
    }
    return null;
  }

  @override
  Future<void> saveItem(LibraryItem item) async {
    final exists = _items.value.any((i) => i.id == item.id);
    _items.value = exists
        ? [for (final i in _items.value) i.id == item.id ? item : i]
        : [..._items.value, item];
  }

  @override
  Future<void> deleteItem(LibraryItem item) async {
    _items.value = _items.value.where((i) => i.id != item.id).toList();
  }

  void _patch(String id, LibraryItem Function(LibraryItem) f) {
    _items.value = [for (final i in _items.value) i.id == id ? f(i) : i];
  }

  @override
  Future<void> markOpened(String id) async => _patch(id, (i) => i.copyWith(lastOpenedAt: DateTime.now()));

  @override
  Future<void> setProgress(String id, double progress) async =>
      _patch(id, (i) => i.copyWith(progress: progress.clamp(0, 1).toDouble()));

  @override
  Future<void> setReadingList(String id, bool value) async => _patch(id, (i) => i.copyWith(inReadingList: value));

  @override
  Future<void> setRating(String id, int stars) async => _patch(id, (i) => i.copyWith(rating: stars.clamp(0, 5)));

  @override
  Future<void> attachPdf(String id, {required String storagePath, required String pdfUrl}) async {
    final i = _items.value.where((x) => x.id == id).firstOrNull;
    if (i == null) return;
    await saveItem(LibraryItem.fromMap(id, {...i.toMap(), 'storagePath': storagePath, 'pdfUrl': pdfUrl}));
  }

  @override
  Future<(String, String)> uploadPdf({required String itemId, required String fileName, required Uint8List bytes}) async {
    return ('demo/$itemId/$fileName', '');
  }

  @override
  Stream<List<ItemNote>> watchNotes(String itemId) => _notesFor(itemId).stream;

  @override
  Future<void> addNote(String itemId, {required String text, String? quote, int? page}) async {
    final live = _notesFor(itemId);
    live.value = [ItemNote(id: newId(), text: text, quote: quote, page: page, createdAt: DateTime.now()), ...live.value];
    _patch(itemId, (i) => i.copyWith(noteCount: live.value.length));
  }

  @override
  Future<void> deleteNote(String itemId, String noteId) async {
    final live = _notesFor(itemId);
    live.value = live.value.where((n) => n.id != noteId).toList();
    _patch(itemId, (i) => i.copyWith(noteCount: live.value.length));
  }

  @override
  Stream<List<Conversation>> watchConversations() => _conversations.stream;

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) => _messagesFor(conversationId).stream;

  @override
  Future<String> createConversation({required PindaContext context, required String title}) async {
    final id = newId();
    _conversations.value = [
      Conversation(id: id, title: title, context: context, updatedAt: DateTime.now()),
      ..._conversations.value,
    ];
    return id;
  }

  @override
  Future<void> addMessage(String conversationId, ChatMessage message) async {
    final live = _messagesFor(conversationId);
    live.value = [...live.value.where((m) => m.id != message.id), message];
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    _conversations.value = _conversations.value.where((c) => c.id != conversationId).toList();
    _messages.remove(conversationId);
  }

  // ── Seed data ──────────────────────────────────────────────────────────────

  void _seed() {
    final now = DateTime.now();
    LibraryCategory cat(String id, String name, int color, String desc, int order) => LibraryCategory(
        id: id, name: name, description: desc, colorIndex: color, order: order,
        createdAt: now, updatedAt: now);
    Topic topic(String id, String cat, String name, int color) => Topic(
        id: id, categoryId: cat, name: name, colorIndex: color, createdAt: now, updatedAt: now);

    _categories.value = [
      cat('cs', 'Computer Science', 2,
          'Papers and articles across computer science, with a focus on machine learning, representation learning and the systems that make modern AI work.', 1),
      cat('econ', 'Economics', 0,
          'Markets, incentives and the behavioural foundations of economic decision-making.', 2),
      cat('neuro', 'Neuroscience', 5, 'How brains learn, decide and remember.', 3),
      cat('psych', 'Psychology', 1, 'Judgment, heuristics and the psychology of choice.', 4),
      cat('bio', 'Biology', 10, 'Molecular foundations of life.', 5),
      cat('info', 'Information Theory', 8, 'Communication, entropy and coding.', 6),
    ];
    _topics.value = [
      topic('ml', 'cs', 'Machine learning', 7),
      topic('llm', 'cs', 'LLMs', 4),
      topic('vision', 'cs', 'Vision', 9),
      topic('behav', 'econ', 'Behavioural', 6),
      topic('markets', 'econ', 'Markets', 1),
    ];

    LibraryItem item(String id, String title, List<String> authors, int year, String cat,
        {String? topic, MaterialKind kind = MaterialKind.paper, String summary = '', String? url,
        double progress = 0, int notes = 0, int daysAgo = 3, bool readingList = false, String content = '', String? arxiv, String? pdfUrl}) {
      return LibraryItem(
        id: id, kind: kind, title: title, authors: authors, year: year, categoryId: cat, topicId: topic,
        summary: summary, url: url, pdfUrl: pdfUrl, content: content, progress: progress, noteCount: notes,
        colorIndex: _rand.nextInt(10), inReadingList: readingList,
        createdAt: now.subtract(Duration(days: daysAgo + 10)),
        updatedAt: now.subtract(Duration(days: daysAgo)),
        lastOpenedAt: now.subtract(Duration(days: daysAgo, hours: _rand.nextInt(20))),
        source: kind == MaterialKind.paper ? 'arxiv' : null,
        externalId: arxiv,
        siteName: kind == MaterialKind.paper ? 'arXiv' : null,
      );
    }

    _items.value = [
      item('p1', 'Attention Is All You Need',
          ['Ashish Vaswani', 'Noam Shazeer', 'Niki Parmar', 'Jakob Uszkoreit', 'Llion Jones', 'Aidan N. Gomez', 'Lukasz Kaiser', 'Illia Polosukhin'],
          2017, 'cs', topic: 'llm', url: 'https://arxiv.org/abs/1706.03762', arxiv: '1706.03762', progress: 0.85, notes: 4, daysAgo: 0, readingList: true,
          summary: 'Introduces the Transformer, a sequence transduction architecture based solely on attention mechanisms, dispensing with recurrence and convolutions entirely.'),
      item('p2', 'Deep Residual Learning for Image Recognition',
          ['Kaiming He', 'Xiangyu Zhang', 'Shaoqing Ren', 'Jian Sun'], 2015, 'cs', topic: 'vision',
          url: 'https://arxiv.org/abs/1512.03385', arxiv: '1512.03385', progress: 0.4, notes: 2, daysAgo: 1,
          summary: 'Presents a residual learning framework to ease the training of networks substantially deeper than those used previously.'),
      item('p3', 'Language Models are Few-Shot Learners',
          ['Tom B. Brown', 'Benjamin Mann', 'Nick Ryder', 'Melanie Subbiah', 'Jared Kaplan', 'Prafulla Dhariwal'], 2020, 'cs', topic: 'llm',
          url: 'https://arxiv.org/abs/2005.14165', arxiv: '2005.14165', progress: 0.15, notes: 1, daysAgo: 2, readingList: true,
          summary: 'Shows that scaling up language models greatly improves task-agnostic, few-shot performance.'),
      item('p4', 'Mastering the game of Go with deep neural networks and tree search',
          ['David Silver', 'Aja Huang', 'Chris J. Maddison', 'Arthur Guez'], 2016, 'cs', topic: 'ml',
          progress: 1, notes: 6, daysAgo: 5,
          summary: 'Combines deep neural networks with Monte Carlo tree search to defeat a human professional at the full game of Go.'),
      item('p5', 'Dropout: A Simple Way to Prevent Neural Networks from Overfitting',
          ['Nitish Srivastava', 'Geoffrey Hinton', 'Alex Krizhevsky', 'Ilya Sutskever', 'Ruslan Salakhutdinov'], 2014, 'cs', topic: 'ml',
          progress: 0, daysAgo: 8, pdfUrl: 'https://arxiv.org/pdf/1207.0580'),
      item('p6', 'Notes on scaling laws', [], 2026, 'cs', topic: 'llm', kind: MaterialKind.note, daysAgo: 0, progress: 0,
          content: '## Scaling laws\n\nLoss falls as a **power law** in parameters, data and compute.\n\n- Compute-optimal training balances model size and tokens\n- Emergent abilities are often a measurement artefact\n\n> Revisit after reading Chinchilla.',
          summary: 'Loss falls as a power law in parameters, data and compute.'),
      item('e1', 'The Market for "Lemons": Quality Uncertainty and the Market Mechanism', ['George A. Akerlof'], 1970, 'econ', topic: 'markets',
          progress: 1, notes: 3, daysAgo: 4,
          summary: 'Shows how asymmetric information about quality can cause markets to unravel.'),
      item('e2', 'Efficient Capital Markets: II', ['Eugene F. Fama'], 1991, 'econ', topic: 'markets', progress: 0.3, daysAgo: 6),
      item('e3', 'Experimental Tests of the Endowment Effect and the Coase Theorem',
          ['Daniel Kahneman', 'Jack L. Knetsch', 'Richard H. Thaler'], 1990, 'econ', topic: 'behav', progress: 0.6, notes: 2, daysAgo: 3, readingList: true),
      item('e4', 'The Network Origins of Aggregate Fluctuations',
          ['Daron Acemoglu', 'Vasco M. Carvalho', 'Asuman Ozdaglar', 'Alireza Tahbaz-Salehi'], 2012, 'econ', progress: 0.9, notes: 6, daysAgo: 9),
      item('e5', 'Prospect Theory: An Analysis of Decision under Risk', ['Daniel Kahneman', 'Amos Tversky'], 1979, 'econ', topic: 'behav',
          progress: 0.2, daysAgo: 12),
      item('n1', 'The Neural Basis of Loss Aversion in Decision-Making Under Risk',
          ['Sabrina M. Tom', 'Craig R. Fox', 'Christopher Trepel', 'Russell A. Poldrack'], 2007, 'neuro', progress: 0.75, notes: 4, daysAgo: 1),
      item('n2', 'Long-lasting potentiation of synaptic transmission in the dentate area',
          ['T. V. P. Bliss', 'T. Lømo'], 1973, 'neuro', progress: 0, daysAgo: 20),
      item('n3', 'How the brain decides — lecture', ['Stanford Online'], 2022, 'neuro', kind: MaterialKind.youtube,
          url: 'https://www.youtube.com/watch?v=aircAruvnKk', daysAgo: 2, progress: 0.5),
      item('y1', 'Judgment under Uncertainty: Heuristics and Biases', ['Amos Tversky', 'Daniel Kahneman'], 1974, 'psych',
          progress: 0.5, notes: 1, daysAgo: 7),
      item('b1', 'Molecular Structure of Nucleic Acids', ['J. D. Watson', 'F. H. C. Crick'], 1953, 'bio', progress: 1, daysAgo: 15),
      item('i1', 'A Mathematical Theory of Communication', ['Claude E. Shannon'], 1948, 'info', progress: 0.35, notes: 2, daysAgo: 4, readingList: true),
    ];

    _notesFor('p1').value = [
      ItemNote(id: 'nn1', text: 'Multi-head attention lets the model attend to different subspaces at once.',
          quote: 'Multi-head attention allows the model to jointly attend to information from different representation subspaces.',
          createdAt: now.subtract(const Duration(hours: 3))),
      ItemNote(id: 'nn2', text: 'Positional encodings are sinusoidal, not learned. Why?', createdAt: now.subtract(const Duration(days: 1))),
    ];
  }

  // ── Reports ──────────────────────────────────────────────────────────────

  @override
  Stream<List<Report>> watchReports() => _reports.stream;

  @override
  Future<Report?> getReport(String id) async => _reports.value.where((r) => r.id == id).firstOrNull;

  @override
  Future<void> saveReport(Report report) async {
    _reports.value = [report, ..._reports.value.where((r) => r.id != report.id)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> deleteReport(String id) async => _reports.value = _reports.value.where((r) => r.id != id).toList();

  // ── Focus sessions ───────────────────────────────────────────────────────

  @override
  Stream<List<FocusSession>> watchSessions() => _sessions.stream;

  @override
  Future<void> saveSession(FocusSession session) async {
    _sessions.value = [session, ..._sessions.value.where((x) => x.id != session.id)]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  @override
  Future<void> deleteSession(String id) async => _sessions.value = _sessions.value.where((x) => x.id != id).toList();

  /// A sample report so the Reports screen isn't empty in previews.
  void seedReport(List<String> sourceIds) {
    final now = DateTime.now().subtract(const Duration(hours: 3));
    _reports.value = [
      Report(
        id: 'demo_report_1',
        title: 'Efficient attention: a short review',
        kind: ReportKind.literatureReview,
        sourceIds: sourceIds,
        body: '''# Efficient attention: a short review

## Overview

Self-attention scales quadratically with sequence length, which drives most of the cost of long-context models [1]. Two lines of work respond to this: changing *how* attention is computed, and changing *what* is attended to [2].

## How the approaches differ

| Approach | Idea | Trade-off |
| --- | --- | --- |
| IO-aware kernels | Tile the computation to stay in fast memory | Exact, but hardware-specific |
| Sparse patterns | Attend to a structured subset of tokens | Cheaper, may miss long-range links |

## Gaps

None of the sources measure quality on documents longer than 64k tokens.

## Sources

[1] Attention Is All You Need, Vaswani et al. (2017)
[2] FlashAttention, Dao et al. (2022)
''',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
