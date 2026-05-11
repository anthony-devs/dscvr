import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dscvr/models/auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatelessWidget {
  final String userId;

  const HomePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {},
        ),
        title: Text(
          'Materials',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () async {
              await DSCVRAuth().signOut();
            },
          ),
        ],
      ),
      body: FutureBuilder<ListResult>(
        future: FirebaseStorage.instanceFor(
          bucket: 'gs://dscvr-9d362.firebasestorage.app',
        ).ref('users').child(userId).listAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.black),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: GoogleFonts.spaceGrotesk(color: Colors.black54),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No materials yet",
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.black54,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          final files = snapshot.data!.items;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final ref = files[index];
              final fileName = ref.name;

              return MaterialCard(
                fileName: fileName,
                fileRef: ref,
              );
            },
          );
        },
      ),
    );
  }
}

class MaterialCard extends StatelessWidget {
  final String fileName;
  final Reference fileRef;

  const MaterialCard({
    Key? key,
    required this.fileName,
    required this.fileRef,
  }) : super(key: key);

  IconData _getFileIcon(String name) {
    final ext = name.toLowerCase();
    if (ext.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png')) {
      return Icons.image;
    }
    if (ext.endsWith('.txt')) return Icons.description;
    if (ext.endsWith('.mp4') || ext.endsWith('.mov')) return Icons.video_library;
    return Icons.insert_drive_file;
  }

  Color _getFileIconColor(String name) {
    final ext = name.toLowerCase();
    if (ext.endsWith('.pdf')) return const Color(0xFFE53935);
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png')) {
      return const Color(0xFF43A047);
    }
    if (ext.endsWith('.txt')) return const Color(0xFF1E88E5);
    if (ext.endsWith('.mp4') || ext.endsWith('.mov')) return const Color(0xFFFB8C00);
    return const Color(0xFF757575);
  }

  String _getCleanFileName(String fullName) {
    // Remove extension and limit length
    final nameWithoutExt = fullName.contains('.')
        ? fullName.substring(0, fullName.lastIndexOf('.'))
        : fullName;
    
    if (nameWithoutExt.length > 35) {
      return '${nameWithoutExt.substring(0, 35)}...';
    }
    return nameWithoutExt;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FullMetadata>(
      future: fileRef.getMetadata(),
      builder: (context, metaSnapshot) {
        String dateText = '';
        if (metaSnapshot.hasData && metaSnapshot.data?.timeCreated != null) {
          final created = metaSnapshot.data!.timeCreated!;
          dateText = '${created.month}/${created.day}/${created.year}';
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                // Handle tap - download or view
                final url = await fileRef.getDownloadURL();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening: $_getCleanFileName(fileName)'),
                    backgroundColor: Colors.black87,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getFileIconColor(fileName).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getFileIcon(fileName),
                        color: _getFileIconColor(fileName),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // File name
                    Expanded(
                      child: Text(
                        _getCleanFileName(fileName),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Date
                    if (dateText.isNotEmpty)
                      Text(
                        dateText,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}