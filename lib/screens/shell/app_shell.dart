import 'dart:ui' as ui;

import 'package:dscvr/screens/add/add_material_sheet.dart';
import 'package:dscvr/screens/shell/sidebar.dart';
import 'package:dscvr/state/library_controller.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Frame around every library screen.
///
/// Wide screens: persistent sidebar + breadcrumb bar.
/// Phones: compact top bar + bottom navigation; the sidebar lives in a drawer.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  ({String? categoryId, String? topicId}) get _scope {
    final m = RegExp(r'^/c/([^/]+)(?:/t/([^/?]+))?').firstMatch(location);
    return (categoryId: m?.group(1), topicId: m?.group(2));
  }

  void _add(BuildContext context) {
    final s = _scope;
    showAddMaterial(context, categoryId: s.categoryId, topicId: s.topicId);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Between sign-out and the redirect to /login there is a frame where the
    // library is gone; render nothing rather than building pages without it.
    if (Services.of(context).library == null) return Scaffold(backgroundColor: c.background);
    final background = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c.background, c.backgroundTint],
      ),
    );

    if (context.isCompact) {
      return Scaffold(
        backgroundColor: c.background,
        extendBody: true,
        drawerScrimColor: Colors.black.withValues(alpha: c.isDark ? 0.5 : 0.22),
        drawer: Drawer(
          backgroundColor: c.background,
          shape: const RoundedSuperellipseBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(28))),
          width: 290,
          child: SafeArea(
            child: Builder(
              builder: (ctx) => Sidebar(location: location, onNavigate: () => Navigator.of(ctx).pop()),
            ),
          ),
        ),
        appBar: AppBar(
          titleSpacing: 0,
          leading: Builder(
            builder: (ctx) => AppIconButton(
              tooltip: 'Library',
              icon: const Icon(Ic.sidebar, size: 20),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: _Breadcrumb(location: location, compact: true),
          actions: [
            AppIconButton(
              tooltip: 'Search',
              onPressed: () => context.go('/search'),
              icon: const Icon(Ic.search, size: 20),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: RoundIconButton(icon: Ic.add, tooltip: 'Add material', onTap: () => _add(context), size: 34),
            ),
          ],
        ),
        body: DecoratedBox(decoration: background, child: child),
        bottomNavigationBar: _BottomNav(location: location),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => context.go('/search'),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => context.go('/search'),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: c.background,
          body: Row(
            children: [
              SizedBox(width: 256, child: Sidebar(location: location)),
              VerticalDivider(width: 1, color: c.line),
              Expanded(
                child: DecoratedBox(
                  decoration: background,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 56,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(child: _Breadcrumb(location: location)),
                              RoundIconButton(
                                icon: Ic.add,
                                tooltip: 'Add material',
                                onTap: () => _add(context),
                                size: 32,
                              ),
                              const SizedBox(width: 8),
                              RoundIconButton(
                                icon: Ic.pinda,
                                tooltip: 'Ask Pinda',
                                onTap: () => context.go('/pinda'),
                                size: 32,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.location, this.compact = false});
  final String location;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lib = Services.of(context).library!;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final c = context.colors;
        final crumbs = _crumbs(lib);
        final parts = <Widget>[];
        for (final (i, crumb) in crumbs.indexed) {
          final last = i == crumbs.length - 1;
          if (compact && !last && crumbs.length > 1) continue;
          if (parts.isNotEmpty) {
            parts.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('/', style: AppTheme.sans(fontSize: 13, color: c.inkFaint)),
              ),
            );
          }
          parts.add(
            Pressable(
              onTap: crumb.path == null || last ? null : () => context.go(crumb.path!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (crumb.dot != null) ...[ColorDot(crumb.dot!, size: 8), const SizedBox(width: 7)],
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: compact ? 200 : 260),
                    child: Text(
                      crumb.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.sans(
                        fontSize: compact ? 15 : 13,
                        fontWeight: last ? FontWeight.w600 : FontWeight.w500,
                        color: last ? c.ink : c.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Row(children: parts);
      },
    );
  }

  List<({String label, String? path, Color? dot})> _crumbs(LibraryController lib) {
    final seg = Uri.parse(location).pathSegments;
    if (seg.isEmpty) return [(label: 'Recent', path: '/recent', dot: null)];
    switch (seg.first) {
      case 'recent':
        return [(label: 'Recent', path: null, dot: null)];
      case 'reading-list':
        return [(label: 'Reading list', path: null, dot: null)];
      case 'discover':
        return [(label: 'Discover', path: null, dot: null)];
      case 'pinda':
        return [(label: 'Pinda', path: null, dot: null)];
      case 'search':
        return [(label: 'Search', path: null, dot: null)];
      case 'settings':
        return [(label: 'Settings', path: null, dot: null)];
      case 'reports':
        return [(label: 'Reports', path: null, dot: null)];
      case 'sessions':
        return [(label: 'Sessions', path: null, dot: null)];
      case 'team':
        return [(label: 'Team', path: null, dot: null)];
      case 'library':
        return [(label: 'My library', path: null, dot: null)];
      case 'c':
        final cat = seg.length > 1 ? lib.category(seg[1]) : null;
        final topic = seg.length > 3 ? lib.topic(seg[3]) : null;
        return [
          (label: 'My library', path: '/library', dot: null),
          if (cat != null) (label: cat.name, path: '/c/${cat.id}', dot: CategoryPalette.of(cat.colorIndex)),
          if (topic != null) (label: topic.name, path: null, dot: CategoryPalette.of(topic.colorIndex)),
        ];
    }
    return [(label: 'DSCVR', path: null, dot: null)];
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.location});
  final String location;

  static const _tabs = [
    ('/recent', Ic.home, 'Home'),
    ('/library', Ic.library, 'Library'),
    ('/discover', Ic.discover, 'Discover'),
    ('/pinda', Ic.pinda, 'Pinda'),
  ];

  int get _index {
    if (location.startsWith('/library') || location.startsWith('/c/') || location.startsWith('/reading-list')) return 1;
    if (location.startsWith('/discover')) return 2;
    if (location.startsWith('/pinda')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final idx = _index;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 0 ? bottom : 12),
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 60,
            decoration: ShapeDecoration(
              color: c.surface.withValues(alpha: c.isDark ? 0.72 : 0.78),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(26),
                side: BorderSide(color: c.line.withValues(alpha: 0.8)),
              ),
            ),
            padding: const EdgeInsets.all(5),
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth / _tabs.length;
              return Stack(children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  curve: const Cubic(0.3, 1.3, 0.5, 1),
                  left: idx * w,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: Container(
                    decoration: ShapeDecoration(
                      color: c.isDark ? c.chip : c.selection,
                      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(21)),
                    ),
                  ),
                ),
                Row(children: [
                  for (final (i, t) in _tabs.indexed)
                    Expanded(
                      child: Pressable(
                        scale: 0.9,
                        onTap: () => context.go(t.$1),
                        semanticLabel: t.$3,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(t.$2, size: 20, color: i == idx ? c.ink : c.inkFaint),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: AppTheme.sans(
                              fontSize: 10.5,
                              fontWeight: i == idx ? FontWeight.w600 : FontWeight.w500,
                              color: i == idx ? c.ink : c.inkFaint,
                            ),
                            child: Text(t.$3),
                          ),
                        ]),
                      ),
                    ),
                ]),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}
