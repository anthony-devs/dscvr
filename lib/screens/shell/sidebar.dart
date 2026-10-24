import 'package:dscvr/models/library.dart';
import 'package:dscvr/screens/library/dialogs.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Library sidebar: quick destinations, the category tree with counts and
/// nested topics, and account controls.
class Sidebar extends StatefulWidget {
  const Sidebar({super.key, required this.location, this.onNavigate});

  final String location;

  /// Called after navigation (used to close the drawer on phones).
  final VoidCallback? onNavigate;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  final Set<String> _expanded = {};

  String? get _activeCategory {
    final m = RegExp(r'^/c/([^/]+)').firstMatch(widget.location);
    return m?.group(1);
  }

  String? get _activeTopic {
    final m = RegExp(r'^/c/[^/]+/t/([^/?]+)').firstMatch(widget.location);
    return m?.group(1);
  }

  @override
  void didUpdateWidget(covariant Sidebar old) {
    super.didUpdateWidget(old);
    final a = _activeCategory;
    if (a != null) _expanded.add(a);
  }

  @override
  void initState() {
    super.initState();
    final a = _activeCategory;
    if (a != null) _expanded.add(a);
  }

  void _go(String path) {
    context.go(path);
    widget.onNavigate?.call();
  }

  @override
  Widget build(BuildContext context) {
    final services = Services.of(context);
    final lib = services.library!;
    final c = context.colors;
    final user = services.session.user;

    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        return Container(
          color: c.background,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 14),
              child: Row(children: [
                const Wordmark(size: 24),
                const Spacer(),
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => _go('/search'),
                  icon: const Icon(Ic.search, size: 18),
                ),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _NavRow(icon: Ic.recent, label: 'Recent', active: widget.location.startsWith('/recent'), onTap: () => _go('/recent')),
                  _NavRow(
                    icon: Ic.readingList,
                    label: 'Reading list',
                    count: lib.readingList.length,
                    active: widget.location.startsWith('/reading-list'),
                    onTap: () => _go('/reading-list'),
                  ),
                  _NavRow(icon: Ic.discover, label: 'Discover', active: widget.location.startsWith('/discover'), onTap: () => _go('/discover')),
                  _NavRow(icon: Ic.pinda, label: 'Pinda', active: widget.location.startsWith('/pinda'), onTap: () => _go('/pinda')),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 4, 6),
                    child: Row(children: [
                      InkWell(
                        onTap: () => _go('/library'),
                        child: Text('My library',
                            style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: 'New category',
                          onPressed: () => showCollectionEditor(context),
                          icon: const Icon(Ic.add, size: 15),
                        ),
                      ),
                    ]),
                  ),
                  if (lib.categories.isEmpty && lib.loaded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                      child: Text('No categories yet.', style: context.text.bodySmall),
                    ),
                  for (final cat in lib.categories) ..._categoryRows(cat),
                  const SizedBox(height: 6),
                  _NavRow(
                    label: 'New category',
                    trailingIcon: Ic.add,
                    muted: true,
                    onTap: () => showCollectionEditor(context),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            Divider(color: c.line, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(children: [
                _NavRow(icon: Ic.settings, label: 'Settings', active: widget.location.startsWith('/settings'), onTap: () => _go('/settings')),
                const SizedBox(height: 4),
                Row(children: [
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: c.chip,
                    backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                    child: user.avatarUrl == null
                        ? Text(user.initials, style: AppTheme.sans(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.ink))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w500, color: c.ink)),
                      Text(user.role, style: context.text.labelSmall),
                    ]),
                  ),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }

  List<Widget> _categoryRows(LibraryCategory cat) {
    final lib = context.library;
    final topics = lib.topicsOf(cat.id);
    final expanded = _expanded.contains(cat.id);
    final active = _activeCategory == cat.id && _activeTopic == null;
    final c = context.colors;
    return [
      _NavRow(
        leading: ColorDot(CategoryPalette.of(cat.colorIndex)),
        label: cat.name,
        count: lib.countIn(cat.id),
        active: active,
        onTap: () {
          setState(() => _expanded.add(cat.id));
          _go('/c/${cat.id}');
        },
        onLeadingTap: topics.isEmpty
            ? null
            : () => setState(() => expanded ? _expanded.remove(cat.id) : _expanded.add(cat.id)),
        expandable: topics.isNotEmpty,
        expanded: expanded,
      ),
      if (expanded && topics.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(left: 14),
          padding: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: c.line))),
          child: Column(children: [
            for (final t in topics)
              _NavRow(
                leading: ColorDot(CategoryPalette.of(t.colorIndex), size: 7),
                label: t.name,
                count: lib.countIn(cat.id, topicId: t.id),
                active: _activeTopic == t.id,
                dense: true,
                onTap: () => _go('/c/${cat.id}/t/${t.id}'),
              ),
          ]),
        ),
    ];
  }
}

class _NavRow extends StatefulWidget {
  const _NavRow({
    required this.label,
    required this.onTap,
    this.icon,
    this.leading,
    this.count,
    this.active = false,
    this.muted = false,
    this.dense = false,
    this.trailingIcon,
    this.onLeadingTap,
    this.expandable = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? leading;
  final int? count;
  final bool active;
  final bool muted;
  final bool dense;
  final IconData? trailingIcon;
  final VoidCallback? onLeadingTap;
  final bool expandable;
  final bool expanded;

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = widget.muted ? c.inkMuted : c.ink;
    Widget? lead = widget.leading ?? (widget.icon != null ? Icon(widget.icon, size: 17, color: c.inkMuted) : null);
    if (lead != null && widget.expandable && _hover) {
      lead = Icon(widget.expanded ? Ic.caretDown : Ic.caretRight, size: 12, color: c.inkMuted);
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: widget.active ? c.selection : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: widget.onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: widget.dense ? 5 : 7),
            child: Row(children: [
              if (lead != null) ...[
                GestureDetector(
                  onTap: widget.onLeadingTap,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(width: 18, child: Center(child: lead)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                        fontSize: widget.dense ? 13 : 13.5,
                        fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
                        color: color)),
              ),
              if (widget.trailingIcon != null) Icon(widget.trailingIcon, size: 14, color: c.inkMuted),
              if (widget.count != null && widget.count! > 0)
                Text('${widget.count}', style: AppTheme.sans(fontSize: 12, color: c.inkFaint)),
            ]),
          ),
        ),
      ),
    );
  }
}
