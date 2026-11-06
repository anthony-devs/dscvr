import 'package:dscvr/config/env.dart';
import 'dart:async';

import 'package:dscvr/data/api.dart';
import 'package:dscvr/data/demo_library_repository.dart';
import 'package:dscvr/data/discover_service.dart';
import 'package:dscvr/data/firestore_library_repository.dart';
import 'package:dscvr/data/link_service.dart';
import 'package:dscvr/data/org_service.dart';
import 'package:dscvr/data/plan_service.dart';
import 'package:dscvr/data/pinda_service.dart';
import 'package:dscvr/data/research_service.dart';
import 'package:dscvr/data/session_service.dart';
import 'package:dscvr/data/voice_service.dart';
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
  late final DscvrApi _api = DscvrApi(token: _session.idToken);
  late final PindaService _pinda = Env.demo ? DemoPindaService() : HttpPindaService(_api);
  late final ResearchService _research = ResearchService(_api);
  late final OrgService _orgs = OrgService(_api);
  late final PlanService _plans = PlanService(_api);
  late final SessionService _sessions = SessionService(_api);
  final VoiceService _voice = VoiceService();
  StreamSubscription<void>? _deviceWatch;
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
    _onSignedIn(uid);
    // Dispose after the frame so nothing still listening crashes mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  /// Registers this device (so it can be signed out remotely) and counts
  /// today's seat for enterprise members.
  Future<void> _onSignedIn(String? uid) async {
    await _deviceWatch?.cancel();
    _deviceWatch = null;
    if (uid == null) {
      _plans.clear();
      return;
    }
    unawaited(_plans.refresh(force: true));
    try {
      _deviceWatch = await _sessions.registerDevice(uid, onRevoked: () async {
        await _session.signOut();
        final ctx = _router.routerDelegate.navigatorKey.currentContext;
        if (ctx != null && ctx.mounted) {
          Toasts.show(ctx, 'Signed out', description: 'This device was signed out from another device.');
        }
      });
    } catch (e) {
      debugPrint('Device registration failed: $e');
    }
    unawaited(_orgs.pingActivity());
  }

  @override
  void dispose() {
    _deviceWatch?.cancel();
    _voice.dispose();
    _plans.dispose();
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
      api: _api,
      research: _research,
      orgs: _orgs,
      sessions: _sessions,
      voice: _voice,
      plans: _plans,
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
