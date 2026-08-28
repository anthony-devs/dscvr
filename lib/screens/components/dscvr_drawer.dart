import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Every destination the drawer can navigate to, including the settings
/// shortcut. Keeping this as an enum (rather than string routes) means
/// typos in a route name can no longer slip past the compiler.
enum DrawerDestination {
  recents,
  discover,
  personalSpace,
  workspaces,
  notebook,
  saved,
  pindaAi,
  settings,
}

class DSCVRDrawer extends StatelessWidget {
  const DSCVRDrawer({
    super.key,
    required this.displayName,
    required this.currentDestination,
    required this.onNavigate,
    required this.onSignOut,
    this.userType = 'Student',
    this.avatarUrl,
  });

  final String displayName;
  final String userType;
  final String? avatarUrl;

  /// Which item should render as active. The original widget hardcoded
  /// "Recents" as always-active regardless of which page was actually
  /// showing — this makes the caller supply the real current page instead.
  final DrawerDestination currentDestination;

  /// The drawer is presentation-only: it doesn't know about Navigator
  /// routes or Firebase. The parent screen decides what "go to Discover"
  /// or "sign out" actually does — same separation used for the
  /// RecentsPage/DscvrRepository split.
  final ValueChanged<DrawerDestination> onNavigate;
  final VoidCallback onSignOut;

  static const _mainEntries = [
    _DrawerNavEntry(
      label: 'Recents',
      icon: Icons.schedule,
      destination: DrawerDestination.recents,
    ),
    _DrawerNavEntry(
      label: 'Discover',
      icon: Icons.explore_outlined,
      destination: DrawerDestination.discover,
    ),
    _DrawerNavEntry(
      label: 'Personal Space',
      icon: Icons.folder_outlined,
      destination: DrawerDestination.personalSpace,
    ),
    _DrawerNavEntry(
      label: 'Workspaces',
      icon: Icons.workspaces_outlined,
      destination: DrawerDestination.workspaces,
    ),
  ];

  static const _toolEntries = [
    _DrawerNavEntry(
      label: 'Notebook',
      icon: Icons.edit_note,
      destination: DrawerDestination.notebook,
    ),
    _DrawerNavEntry(
      label: 'Saved',
      icon: Icons.bookmark_border,
      destination: DrawerDestination.saved,
    ),
    _DrawerNavEntry(
      label: 'Pinda AI',
      icon: Icons.psychology_outlined,
      destination: DrawerDestination.pindaAi,
    ),
  ];

  String get _avatarInitial {
    final trimmed = displayName.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  void _handleNavigate(BuildContext context, DrawerDestination destination) {
    Navigator.pop(context);
    onNavigate(destination);
  }

  void _handleSignOut(BuildContext context) {
    Navigator.pop(context);
    onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfileHeader(
              displayName: displayName,
              userType: userType,
              avatarUrl: avatarUrl,
              avatarInitial: _avatarInitial,
              onSettingsTap: () =>
                  _handleNavigate(context, DrawerDestination.settings),
            ),
            const Divider(height: 1),

            // Scrollable so this never overflows on short screens or with
            // large system font sizes — the original Column+Spacer had no
            // scroll fallback if the item list ever grew.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final entry in _mainEntries)
                    _DrawerItem(
                      label: entry.label,
                      icon: entry.icon,
                      isActive: entry.destination == currentDestination,
                      onTap: () => _handleNavigate(context, entry.destination),
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
                  for (final entry in _toolEntries)
                    _DrawerItem(
                      label: entry.label,
                      icon: entry.icon,
                      isActive: entry.destination == currentDestination,
                      onTap: () => _handleNavigate(context, entry.destination),
                    ),
                ],
              ),
            ),

            _DrawerItem(
              label: 'Sign Out',
              icon: Icons.logout,
              onTap: () => _handleSignOut(context),
            ),

            const _DonateCard(),
          ],
        ),
      ),
    );
  }
}

class _DrawerNavEntry {
  const _DrawerNavEntry({
    required this.label,
    required this.icon,
    required this.destination,
  });

  final String label;
  final IconData icon;
  final DrawerDestination destination;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.userType,
    required this.avatarUrl,
    required this.avatarInitial,
    required this.onSettingsTap,
  });

  final String displayName;
  final String userType;
  final String? avatarUrl;
  final String avatarInitial;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE0E0E0),
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            // Falls back to the initial instead of a broken-image icon if
            // the URL 404s or the device is offline.
            onBackgroundImageError:
                avatarUrl != null ? (_, __) {} : null,
            child: avatarUrl == null
                ? Text(
                    avatarInitial,
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
            onPressed: onSettingsTap,
          ),
        ],
      ),
    );
  }
}

class _DonateCard extends StatelessWidget {
  const _DonateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

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