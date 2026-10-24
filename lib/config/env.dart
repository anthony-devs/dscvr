/// Build-time configuration.
///
/// Pass values with --dart-define, for example:
///   flutter run -d chrome --dart-define=DSCVR_DEMO=true
///   flutter build web --dart-define=DSCVR_FUNCTIONS_URL=https://...
class Env {
  Env._();

  /// Runs the app against an in-memory sample library with no Firebase.
  /// Useful for design reviews, screenshots and portfolio demos.
  static const bool demo = bool.fromEnvironment('DSCVR_DEMO');

  /// Base URL of the deployed Cloud Functions (pinda, unfurl, discover).
  static const String functionsUrl = String.fromEnvironment(
    'DSCVR_FUNCTIONS_URL',
    defaultValue: 'https://us-central1-dscvr-9d362.cloudfunctions.net',
  );

  static const String storageBucket = 'gs://dscvr-9d362.firebasestorage.app';
}
