import 'package:dscvr/data/discover_service.dart';
import 'package:dscvr/data/library_repository.dart';
import 'package:dscvr/data/link_service.dart';
import 'package:dscvr/data/pinda_service.dart';
import 'package:dscvr/state/library_controller.dart';
import 'package:dscvr/state/session_controller.dart';
import 'package:dscvr/state/settings_controller.dart';
import 'package:flutter/widgets.dart';

/// App-wide dependencies, available anywhere below [DscvrApp].
class Services extends InheritedWidget {
  const Services({
    super.key,
    required this.session,
    required this.settings,
    required this.discover,
    required this.links,
    required this.pinda,
    required this.library,
    required super.child,
  });

  final SessionController session;
  final SettingsController settings;
  final DiscoverService discover;
  final LinkService links;
  final PindaService pinda;

  /// Null until a user is signed in and onboarded.
  final LibraryController? library;

  LibraryRepository get repo => library!.repo;

  static Services of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<Services>();
    assert(s != null, 'Services not found in context');
    return s!;
  }

  /// Read without subscribing to rebuilds.
  static Services read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<Services>()!;

  @override
  bool updateShouldNotify(Services old) => old.library != library;
}

extension ServicesX on BuildContext {
  Services get services => Services.read(this);
  LibraryController get library => Services.read(this).library!;
}
