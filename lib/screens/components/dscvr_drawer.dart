import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DSCVRDrawer extends StatelessWidget {
  final String displayName;
  final String userType;
  final String? avatarUrl;

  const DSCVRDrawer({
    Key? key,
    required this.displayName,
    this.userType = 'Student',
    this.avatarUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── User profile ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl!)
                        : null,
                    backgroundColor: const Color(0xFFE0E0E0),
                    child: avatarUrl == null
                        ? Text(
                            displayName[0].toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userType,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to settings
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),
            const SizedBox(height: 8),

            // ─── Navigation items ──────────────────────────────────────
            _DrawerItem(
              label: 'Recents',
              icon: Icons.schedule,
              isActive: true,
              onTap: () {
                Navigator.pop(context);
                // Navigate to Recents
              },
            ),
            _DrawerItem(
              label: 'Discover',
              icon: Icons.explore_outlined,
              onTap: () {
                Navigator.pop(context);
                // Navigate to Discover
              },
            ),
            _DrawerItem(
              label: 'Personal Space',
              icon: Icons.folder_outlined,
              onTap: () {
                Navigator.pop(context);
                // Navigate to Personal Space
              },
            ),
            _DrawerItem(
              label: 'Workspaces',
              icon: Icons.workspaces_outlined,
              onTap: () {
                Navigator.pop(context);
                // Navigate to Workspaces
              },
            ),

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Tools',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black45,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),

            _DrawerItem(
              label: 'Notebook',
              icon: Icons.edit_note,
              onTap: () {
                Navigator.pop(context);
                // Navigate to Notebook
              },
            ),
            _DrawerItem(
              label: 'Saved',
              icon: Icons.bookmark_border,
              onTap: () {
                Navigator.pop(context);
                // Navigate to Saved
              },
            ),
            _DrawerItem(
              label: 'Pinda AI',
              icon: Icons.psychology_outlined,
              onTap: () {
                Navigator.pop(context);
                // Navigate to Pinda AI
              },
            ),

            const Spacer(),

            // ─── Donate section ────────────────────────────────────────
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Donate',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Help keep the foundation going',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: Colors.black54,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.label,
    required this.icon,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: isActive ? Colors.black : Colors.black54,
      ),
      title: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          color: isActive ? Colors.black : Colors.black54,
        ),
      ),
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      onTap: onTap,
    );
  }
}