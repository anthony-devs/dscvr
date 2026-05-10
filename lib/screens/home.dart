import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dscvr/models/auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatelessWidget {
  // Fix 1: StatelessWidget cannot hold mutable state via a plain field.
  // The snapshot is only needed to get the user ID, so accept that directly.
  final String userId;

  const HomePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Fix 2: Never create a Stream inside build() — it gets recreated on every
    // rebuild, causing the StreamBuilder to resubscribe constantly.
    // Moved outside and passed in, or use a StatefulWidget. Here we keep it
    // simple: define it as a local final so at least the widget is const-safe.
    final Stream<DocumentSnapshot<Map<String, dynamic>>> userStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(includeMetadataChanges: true);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, snapshot) {
        // Fix 3: Check connectionState FIRST, before accessing snapshot.data.
        // The previous code checked snapshot.data == null before checking
        // connectionState, which means it showed the wrong UI on first load,
        // and the `done` branch was a no-op (streams never reach `done`).
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF111111),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF111111),
            body: Center(
              child: Text(
                'Something went wrong',
                style: GoogleFonts.spaceGrotesk(color: Colors.white),
              ),
            ),
          );
        }

        // Fix 4: Guard against missing or deleted Firestore document.
        final data = snapshot.data;
        if (data == null || !data.exists) {
          return Scaffold(
            backgroundColor: const Color(0xFF111111),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Fix 5: Use typed map access with a fallback instead of raw [] on
        // DocumentSnapshot, which throws if the field is missing.
        final userData = data.data()!;
        final id = userData['id'] as String? ?? 'there';
        final displayName = userData['displayName'] as String? ?? 'there';

        return Scaffold(
          backgroundColor: const Color(0xFF111111),
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              userId,
              style: GoogleFonts.spaceGrotesk(color: Colors.white),
            ),
            actions: [
              IconButton(
                onPressed: () async {
                  await DSCVRAuth().signOut();
                  // StreamBuilder in main.dart handles navigation automatically
                },
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
            ],
          ),
          body: FutureBuilder<ListResult>(
            future: FirebaseStorage.instanceFor(bucket: 'gs://dscvr-9d362.firebasestorage.app')
                .ref('users')
                .child(userId) // or .child('users/$userId')
                .listAll(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (snapshot.hasError) {
                print(snapshot.error);
                return Center(
                  child: Text(
                    "Error: ${snapshot.error}",
                    style: GoogleFonts.spaceGrotesk(color: Colors.white),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.items.isEmpty) {
                return Center(
                  child: Text(
                    "No photos found",
                    style: GoogleFonts.spaceGrotesk(color: Colors.white),
                  ),
                );
              }

              final files = snapshot.data!.items;

              return ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final ref = files[index];

                  return FutureBuilder<String>(
                    future: ref.getDownloadURL(),
                    builder: (context, urlSnapshot) {
                      if (!urlSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final imageUrl = urlSnapshot.data!;

                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(imageUrl, fit: BoxFit.cover),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
