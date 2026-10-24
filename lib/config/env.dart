/// Build-time configuration.
///
/// Pass values with --dart-define, for example:
///   flutter run -d chrome --dart-define=DSCVR_DEMO=true
///   flutter build web --dart-define=DSCVR_FUNCTIONS_URL=https://...
///   flutter build web --dart-define=DSCVR_SERVER_URL=https://dscvr-server.up.railway.app
class Env {
  Env._();

  /// Runs the app against an in-memory sample library with no Firebase.
  /// Useful for design reviews, screenshots and portfolio demos.
  static const bool demo = bool.fromEnvironment('DSCVR_DEMO');

  /// Base URL of the deployed Cloud Functions (pinda, unfurl, parliament).
  static const String functionsUrl = String.fromEnvironment(
    'DSCVR_FUNCTIONS_URL',
    defaultValue: 'https://us-central1-dscvr-9d362.cloudfunctions.net',
  );

  /// Base URL of the dedicated Flask server (discover proxy, payments).
  /// This server handles CORS for web and provides added security.
  static const String serverUrl = String.fromEnvironment(
    'DSCVR_SERVER_URL',
    defaultValue: 'https://dscvr-server.up.railway.app',
  );

  static const String storageBucket = 'gs://dscvr-9d362.firebasestorage.app';

  /// Google Pay merchant ID for payment processing.
  static const String googlePayMerchantId = String.fromEnvironment(
    'DSCVR_GPAY_MERCHANT_ID',
    defaultValue: '',
  );
}
