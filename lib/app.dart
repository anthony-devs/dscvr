import 'package:dscvr/config/env.dart';
import 'package:dscvr/data/demo_library_repository.dart';
import 'package:dscvr/data/discover_service.dart';
import 'package:dscvr/data/firestore_library_repository.dart';
import 'package:dscvr/data/link_service.dart';
import 'package:dscvr/data/pinda_service.dart';
import 'package:dscvr/router/app_router.dart';
import 'package:dscvr/state/library_controller.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/state/session_controller.dart';
import 'package:dscvr/state/settings_controller.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DscvrApp extends StatefulWidget {
  const DscvrApp({super.key, required this.settings});
  final SettingsController settings;

  @override
  State<DscvrApp> createState() => _DscvrAppState();
}

class _DscvrAppState extends State<DscvrApp> {
  final _session = SessionController();
  final _discover = DiscoverService();
  final _links = LinkService();
  late final PindaService _pinda = Env.demo ? DemoPindaService() : HttpPindaService(token: _session.idToken);
  late final GoRouter _router = buildRouter(_session);

  LibraryController? _library;
  String? _libraryUid;

  @override
  void initState() {
    super.initState();
    _session.addListener(_syncLibrary);
    _syncLibrary();
  }

  /// Creates (or tears down) the per-user library when the signed-in user
  /// changes.
  void _syncLibrary() {
    final status = _session.status;
    final uid = status == SessionStatus.ready ? _session.user.id : null;
    if (uid == _libraryUid) return;
    final old = _library;
    _libraryUid = uid;
    _library = uid == null
        ? null
        : LibraryController(Env.demo ? DemoLibraryRepository() : FirestoreLibraryRepository(uid: uid));
    if (mounted) setState(() {});
    // Dispose after the frame so nothing still listening crashes mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  @override
  void dispose() {
    _session.removeListener(_syncLibrary);
    _session.dispose();
    _library?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Services(
      session: _session,
      settings: widget.settings,
      discover: _discover,
      links: _links,
      pinda: _pinda,
      library: _library,
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => MaterialApp.router(
          title: 'DSCVR',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: widget.settings.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 280),
          routerConfig: _router,
          scrollBehavior: const DscvrScrollBehavior(),
          // Sileo-style toasts float above every route, sheet and dialog.
          builder: (context, child) => Toaster(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
