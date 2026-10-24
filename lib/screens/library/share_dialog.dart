import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/sharing_service.dart';
import 'package:dscvr/models/sharing.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A dialog for creating, viewing and managing share links.
///
/// Usage:
///   showAdaptiveSheet(context, builder: (_) => ShareDialog(
///     targetType: 'category',
///     targetId: categoryId,
///     targetName: category.name,
///   ));
class ShareDialog extends StatefulWidget {
  const ShareDialog({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    this.sharingService,
  });

  final String targetType;
  final String targetId;
  final String targetName;
  final SharingService? sharingService;

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  late final SharingService _service;
  List<ShareLink>? _links;
  bool _creating = false;
  SharePermission _newPermission = SharePermission.view;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.sharingService ?? (Env.demo ? DemoSharingService() : SharingService());
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    try {
      final links = await _service.linksFor(widget.targetType, widget.targetId);
      if (mounted) setState(() => _links = links);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load share links.');
    }
  }

  Future<void> _createLink() async {
    setState(() => _creating = true);
    try {
      final link = await _service.createLink(
        targetType: widget.targetType,
        targetId: widget.targetId,
        permission: _newPermission,
        label: '${widget.targetName} — ${_newPermission.label}',
      );
      if (mounted) {
        setState(() {
          _links = [link, ...?_links];
          _creating = false;
        });
        _copyUrl(link.shareUrl);
      }
    } catch (e) {
      if (mounted) setState(() { _creating = false; _error = 'Failed to create link.'; });
    }
  }

  Future<void> _revokeLink(ShareLink link) async {
    try {
      await _service.revokeLink(link.id);
      if (mounted) setState(() => _links?.removeWhere((l) => l.id == link.id));
    } catch (_) {}
  }

  void _copyUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    Toasts.show(context, 'Link copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Row(children: [
            Icon(Ic.share, size: 18, color: c.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Share "${widget.targetName}"',
                style: AppTheme.sans(fontSize: 16, fontWeight: FontWeight.w600, color: c.ink),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            Pressable(
              onTap: () => Navigator.of(context).pop(),
              child: Icon(Ic.close, size: 18, color: c.inkMuted),
            ),
          ]),
          const SizedBox(height: 20),

          // Create new link
          Container(
            padding: const EdgeInsets.all(14),
            decoration: ShapeDecoration(
              color: c.surfaceMuted,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Create a link', style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
              const SizedBox(height: 10),
              _PermissionPicker(
                value: _newPermission,
                onChanged: (p) => setState(() => _newPermission = p),
              ),
              const SizedBox(height: 12),
              AppButton.primary(
                onPressed: _creating ? null : _createLink,
                loading: _creating,
                expand: true,
                icon: const Icon(Ic.linkSimple, size: 14),
                label: const Text('Create link'),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Existing links
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: AppTheme.sans(fontSize: 12.5, color: c.danger)),
            ),

          if (_links == null)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_links!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No links yet. Create one above to share this ${widget.targetType}.',
                style: AppTheme.sans(fontSize: 13, color: c.inkFaint),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Text('Active links', style: AppTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted, letterSpacing: 0.3)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _links!.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) => _LinkTile(
                  link: _links![i],
                  onCopy: () => _copyUrl(_links![i].shareUrl),
                  onRevoke: () => _revokeLink(_links![i]),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permission picker
// ─────────────────────────────────────────────────────────────────────────────

class _PermissionPicker extends StatelessWidget {
  const _PermissionPicker({required this.value, required this.onChanged});
  final SharePermission value;
  final ValueChanged<SharePermission> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Segmented<SharePermission>(
      value: value,
      onChanged: onChanged,
      options: const [
        (SharePermission.view, 'View', Ic.eye),
        (SharePermission.comment, 'Comment', Ic.chatCircle),
        (SharePermission.fork, 'Fork', Ic.gitFork),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual link tile
// ─────────────────────────────────────────────────────────────────────────────

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.link, required this.onCopy, required this.onRevoke});
  final ShareLink link;
  final VoidCallback onCopy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final permIcon = switch (link.permission) {
      SharePermission.view => Ic.eye,
      SharePermission.comment => Ic.chatCircle,
      SharePermission.fork => Ic.gitFork,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          side: BorderSide(color: c.line),
        ),
      ),
      child: Row(children: [
        Icon(permIcon, size: 15, color: c.inkMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(
              link.permission.label,
              style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w500, color: c.ink),
            ),
            Text(
              _ago(link.createdAt),
              style: AppTheme.sans(fontSize: 11, color: c.inkFaint),
            ),
          ]),
        ),
        Pressable(
          onTap: onCopy,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Ic.copy, size: 15, color: c.inkMuted),
          ),
        ),
        Pressable(
          onTap: onRevoke,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Ic.trash, size: 15, color: c.danger),
          ),
        ),
      ]),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'just now';
  }
}
