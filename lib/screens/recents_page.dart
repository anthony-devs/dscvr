import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dscvr/models/file.dart';
import 'package:dscvr/screens/components/dscvr_drawer.dart';
import 'package:dscvr/screens/components/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_storage/firebase_storage.dart';

class RecentsPage extends StatefulWidget {
  final String userId;
  final String displayName;
  final String? avatarUrl;

  const RecentsPage({
    Key? key,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  }) : super(key: key);

  @override
  State<RecentsPage> createState() => _RecentsPageState();
}

class _RecentsPageState extends State<RecentsPage> {
  bool topicsExpanded = false;
  bool materialsExpanded = false;
  bool notesExpanded = true;

  late Future<ListResult> _filesFuture;
  late Stream<List<Note>> _notesStream;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  void _loadFiles() {
    _filesFuture = FirebaseStorage.instanceFor(
      bucket: 'gs://dscvr-9d362.firebasestorage.app',
    ).ref('users').child(widget.userId).listAll();

    _notesStream = FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      if (data == null || !data.containsKey('notes')) return <Note>[];

      final notesMap = data['notes'] as Map<String, dynamic>;
      return notesMap.values
          .map((e) => Note.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> _onRefresh() async {
    setState(() => _loadFiles());
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
      body: FutureBuilder<ListResult>(
        future: _filesFuture,
        builder: (context, asyncSnapshot) {
          if (asyncSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (asyncSnapshot.hasError) {
            return Center(
              child: Text(
                asyncSnapshot.error.toString(),
                style: const TextStyle(color: Colors.deepOrange),
              ),
            );
          }

          final files = asyncSnapshot.data!.items;

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // ─── Topics ──────────────────────────────────────────────
                _SectionHeader(
                  title: 'Topics',
                  isExpanded: topicsExpanded,
                  onTap: () =>
                      setState(() => topicsExpanded = !topicsExpanded),
                ),
                if (topicsExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text(
                      'No topics yet',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.black45,
                        fontSize: 14,
                      ),
                    ),
                  ),

                // ─── Materials ───────────────────────────────────────────
                _SectionHeader(
                  title: 'Materials',
                  isExpanded: materialsExpanded,
                  onTap: () =>
                      setState(() => materialsExpanded = !materialsExpanded),
                ),
                if (materialsExpanded)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: files.length > 4 ? 4 : files.length,
                    itemBuilder: (context, index) {
                      final ref = files[index];
                      return _MaterialCard(fileRef: ref);
                    },
                  ),

                // ─── Notes ───────────────────────────────────────────────
                _SectionHeader(
                  title: 'Notes',
                  isExpanded: notesExpanded,
                  onTap: () =>
                      setState(() => notesExpanded = !notesExpanded),
                ),
                if (notesExpanded)
                  StreamBuilder<List<Note>>(
                    stream: _notesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            snapshot.error.toString(),
                            style:
                                const TextStyle(color: Colors.deepOrange),
                          ),
                        );
                      }

                      final notes = snapshot.data ?? [];

                      if (notes.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Text(
                            'No notes yet',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.black45,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.isExpanded,
    required this.onTap,
  });

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
              isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final Reference fileRef;

  const _MaterialCard({required this.fileRef});

  IconData _getFileIcon(String name) {
    final ext = name.toLowerCase();
    if (ext.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png')) return Icons.image;
    if (ext.endsWith('.txt')) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getFileIconColor(String name) {
    final ext = name.toLowerCase();
    if (ext.endsWith('.pdf')) return const Color(0xFFE53935);
    if (ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png')) return const Color(0xFF43A047);
    if (ext.endsWith('.txt')) return const Color(0xFF1E88E5);
    return const Color(0xFF757575);
  }

  @override
  Widget build(BuildContext context) {
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
                    color: _getFileIconColor(fileRef.name).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getFileIcon(fileRef.name),
                    color: _getFileIconColor(fileRef.name),
                    size: 28,
                  ),
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