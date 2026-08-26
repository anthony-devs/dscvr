import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:dscvr/models/file.dart';
import 'package:dscvr/screens/components/dscvr_drawer.dart';
import 'package:dscvr/screens/components/note_card.dart';

import 'dscvr_repository.dart';
import 'file_type_style.dart';

class RecentsPage extends StatefulWidget {
  // Not `const`: a caller who omits `repository` gets a fresh
  // `DscvrRepository()` per instance (assigned lazily in State.initState,
  // not here) — a const constructor would force that default to be a
  // compile-time constant, which a non-const object graph can't satisfy.
  const RecentsPage({
    super.key,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.repository,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;

  /// Inject a fake in tests; defaults to a real [DscvrRepository] otherwise.
  final DscvrRepository? repository;

  @override
  State<RecentsPage> createState() => _RecentsPageState();
}

class _RecentsPageState extends State<RecentsPage> {
  static const _maxMaterialsPreview = 4;

  bool _topicsExpanded = false;
  bool _materialsExpanded = false;
  bool _notesExpanded = true;

  late final DscvrRepository _repository;
  late Future<List<Reference>> _filesFuture;
  late Stream<List<Note>> _notesStream;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DscvrRepository();
    _filesFuture = _repository.listUserFiles(widget.userId);
    _notesStream = _repository.watchNotes(widget.userId);
  }

  @override
  void didUpdateWidget(covariant RecentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch if the page is ever reused for a different user, instead of
    // silently keeping stale data around.
    if (oldWidget.userId != widget.userId) {
      setState(() {
        _filesFuture = _repository.listUserFiles(widget.userId);
        _notesStream = _repository.watchNotes(widget.userId);
      });
    }
  }

  Future<void> _onRefresh() async {
    final refreshed = _repository.listUserFiles(widget.userId);
    // Await the new future before swapping it in and completing the
    // refresh — the original version reassigned the future without
    // awaiting it, so the pull-to-refresh spinner closed immediately
    // instead of staying open until data actually arrived.
    await refreshed;
    setState(() => _filesFuture = refreshed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      drawer: DSCVRDrawer(
        displayName: widget.displayName,
        avatarUrl: widget.avatarUrl,
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Recents',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 21,
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            _SectionHeader(
              title: 'Topics',
              isExpanded: _topicsExpanded,
              onTap: () => setState(() => _topicsExpanded = !_topicsExpanded),
            ),
            if (_topicsExpanded)
              const _InlineEmptyState(message: 'No topics yet'),

            _SectionHeader(
              title: 'Materials',
              isExpanded: _materialsExpanded,
              onTap: () =>
                  setState(() => _materialsExpanded = !_materialsExpanded),
            ),
            if (_materialsExpanded) _buildMaterials(),

            _SectionHeader(
              title: 'Notes',
              isExpanded: _notesExpanded,
              onTap: () => setState(() => _notesExpanded = !_notesExpanded),
            ),
            if (_notesExpanded) _buildNotes(),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterials() {
    return FutureBuilder<List<Reference>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _InlineLoading();
        }

        if (snapshot.hasError) {
          return _InlineErrorState(
            message: 'Couldn\'t load materials.',
            onRetry: () =>
                setState(() => _filesFuture = _repository.listUserFiles(
                      widget.userId,
                    )),
          );
        }

        final files = snapshot.data ?? const <Reference>[];
        if (files.isEmpty) {
          return const _InlineEmptyState(message: 'No materials yet');
        }

        final preview = files.take(_maxMaterialsPreview).toList();

        return Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: preview.length,
              itemBuilder: (context, index) =>
                  _MaterialCard(fileRef: preview[index]),
            ),
            if (files.length > _maxMaterialsPreview)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () {
                    // Hook up to a full materials list screen.
                  },
                  child: Text(
                    'See all ${files.length} materials',
                    style: GoogleFonts.spaceGrotesk(fontSize: 13),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNotes() {
    return StreamBuilder<List<Note>>(
      stream: _notesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _InlineLoading();
        }

        if (snapshot.hasError) {
          return _InlineErrorState(
            message: 'Couldn\'t load notes.',
            onRetry: () => setState(() {
              _notesStream = _repository.watchNotes(widget.userId);
            }),
          );
        }

        final notes = snapshot.data ?? const <Note>[];
        if (notes.isEmpty) {
          return const _InlineEmptyState(message: 'No notes yet');
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return NoteCard(
              title: note.title,
              category: note.tags?.join(', ') ?? 'Untagged',
              authors: note.owner,
              color: NoteColors.random(index),
              onTap: () {},
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.isExpanded,
    required this.onTap,
  });

  final String title;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        message,
        style: GoogleFonts.spaceGrotesk(color: Colors.black45, fontSize: 14),
      ),
    );
  }
}

class _InlineErrorState extends StatelessWidget {
  const _InlineErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.deepOrange),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.fileRef});

  final Reference fileRef;

  @override
  Widget build(BuildContext context) {
    final style = FileTypeStyle.fromFileName(fileRef.name);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: style.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.color, size: 28),
                ),
                const Spacer(),
                Text(
                  fileRef.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}