import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NoteCard extends StatelessWidget {
  final String title;
  final String category;
  final String authors;
  final Color color;
  final VoidCallback? onTap;

  const NoteCard({
    Key? key,
    required this.title,
    required this.category,
    required this.authors,
    required this.color,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Authors
                Text(
                  authors,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 8),
                
                // Link icon
                const Icon(
                  Icons.link,
                  size: 16,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Predefined note colors from the design
class NoteColors {
  static const green = Color(0xFFD4E9D7);
  static const blue = Color(0xFFD4E4F1);
  static const pink = Color(0xFFF3D9E1);
  static const beige = Color(0xFFEFE7D6);
  static const yellow = Color(0xFFFFF4D6);
  static const purple = Color(0xFFE8D9F3);

  static final all = [green, blue, pink, beige, yellow, purple];

  static Color random(int index) {
    return all[index % all.length];
  }
}