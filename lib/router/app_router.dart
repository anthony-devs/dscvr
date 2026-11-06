import 'package:dscvr/screens/discover/discover_page.dart';
import 'package:dscvr/screens/library/home_pages.dart';
import 'package:dscvr/screens/library/shelf_page.dart';
import 'package:dscvr/screens/login.dart';
import 'package:dscvr/screens/onboarding/onboarding_page.dart';
import 'package:dscvr/screens/pinda/pinda_page.dart';
import 'package:dscvr/screens/reader/reader_page.dart';
import 'package:dscvr/screens/reports/report_editor_page.dart';
import 'package:dscvr/screens/reports/reports_page.dart';
import 'package:dscvr/screens/sessions/focus_page.dart';
import 'package:dscvr/screens/sessions/room_page.dart';
import 'package:dscvr/screens/sessions/sessions_page.dart';
import 'package:dscvr/screens/team/team_page.dart';
import 'package:dscvr/screens/plans/plans_page.dart';
import 'package:dscvr/screens/settings/settings_page.dart';
import 'package:dscvr/screens/signup.dart';
import 'package:dscvr/screens/shell/app_shell.dart';
import 'package:dscvr/models/edition.dart';
import 'package:dscvr/state/session_controller.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter buildRouter(SessionController session) {
  NoTransitionPage<void> page(GoRouterState s, Widget child) => NoTransitionPage(key: s.pageKey, child: child);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/recent',
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.subloc;
      // Remember deep links (e.g. a shared /m/abc URL) across the auth check.
      final from = state.queryParams['from'];
      String hold(String target) =>
          loc == '/' || loc == '/splash' ? target : '$target?from=${Uri.encodeComponent(state.location)}';
      switch (session.status) {
        case SessionStatus.unknown:
          return loc == '/splash' ? null : hold('/splash');
        case SessionStatus.signedOut:
          return (loc == '/login' || loc == '/signup') ? null : '/login';
        case SessionStatus.onboarding:
          return loc == '/onboarding' ? null : '/onboarding';
        case SessionStatus.ready:
          if (const {'/splash', '/login', '/signup', '/onboarding', '/'}.contains(loc)) {
            if (from != null && from.startsWith('/') && !from.startsWith('/splash')) return from;
            final u = session.user;
            if (loc == '/onboarding' && u.edition == Edition.enterprise && !u.inOrg) return '/team';
            return '/recent';
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/recent'),
      GoRoute(path: '/splash', pageBuilder: (_, s) => page(s, const SplashPage())),
      GoRoute(path: '/login', pageBuilder: (_, s) => page(s, const LoginPage())),
      GoRoute(path: '/signup', pageBuilder: (_, s) => page(s, const SignupPage())),
      GoRoute(path: '/onboarding', pageBuilder: (_, s) => page(s, const OnboardingPage())),
      GoRoute(
        path: '/m/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => MaterialPage(key: s.pageKey, child: ReaderPage(itemId: s.params['id']!, dictate: s.queryParams['dictate'] == '1')),
      ),
      GoRoute(
        path: '/reports/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => MaterialPage(
          key: s.pageKey,
          child: ReportEditorPage(reportId: s.params['id']!, draftOnOpen: s.queryParams['draft'] == '1'),
        ),
      ),
      GoRoute(
        path: '/sessions/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => MaterialPage(key: s.pageKey, child: FocusPage(sessionId: s.params['id']!)),
      ),
      GoRoute(
        path: '/rooms/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => MaterialPage(key: s.pageKey, child: RoomPage(roomId: s.params['id']!)),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.location, child: child),
        routes: [
          GoRoute(path: '/recent', pageBuilder: (_, s) => page(s, const RecentPage())),
          GoRoute(path: '/reading-list', pageBuilder: (_, s) => page(s, const ReadingListPage())),
          GoRoute(path: '/library', pageBuilder: (_, s) => page(s, const LibraryIndexPage())),
          GoRoute(path: '/search', pageBuilder: (_, s) => page(s, const SearchPage())),
          GoRoute(path: '/discover', pageBuilder: (_, s) => page(s, DiscoverPage(initialQuery: s.queryParams['q']))),
          GoRoute(path: '/pinda', pageBuilder: (_, s) => page(s, PindaPage(conversationId: s.queryParams['c']))),
          GoRoute(path: '/reports', pageBuilder: (_, s) => page(s, const ReportsPage())),
          GoRoute(path: '/sessions', pageBuilder: (_, s) => page(s, const SessionsPage())),
          GoRoute(path: '/team', pageBuilder: (_, s) => page(s, const TeamPage())),
          GoRoute(path: '/plans', pageBuilder: (_, s) => page(s, PlansPage(reference: s.queryParams['reference']))),
          GoRoute(path: '/settings', pageBuilder: (_, s) => page(s, const SettingsPage())),
          GoRoute(
            path: '/c/:cid',
            pageBuilder: (_, s) => page(s, ShelfPage(categoryId: s.params['cid']!)),
            routes: [
              GoRoute(
                path: 't/:tid',
                pageBuilder: (_, s) => page(s, ShelfPage(categoryId: s.params['cid']!, topicId: s.params['tid'])),
              ),
            ],
          ),
        ],
      ),
    ],
    errorPageBuilder: (context, s) => MaterialPage(
      child: Scaffold(
        body: EmptyState(
          icon: Ic.warning,
          title: 'Page not found',
          message: s.location,
          action: AppButton.primary(onPressed: () => context.go('/recent'), child: const Text('Go home')),
        ),
      ),
    ),
  );
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: DscvrMark(size: 44)));
}
