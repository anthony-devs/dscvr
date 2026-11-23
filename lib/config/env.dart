/// Build-time configuration.
///
/// Pass values with --dart-define, for example:
///   flutter run -d chrome --dart-define=DSCVR_DEMO=true
///   flutter build web --dart-define=DSCVR_FUNCTIONS_URL=https://...
///   flutter build web --dart-define=DSCVR_SERVER_URL=https://api.askpinda.com
class Env {
  Env._();

  /// Chrome Web Store page for the DSCVR extension. Empty until the listing is
  /// live; the app then says "coming soon" instead of linking to it.
  static const String chromeExtensionUrl = String.fromEnvironment('DSCVR_CHROME_EXTENSION_URL');

  /// Runs the app against an in-memory sample library with no Firebase.
  /// On by build flag (DSCVR_DEMO=true) or by opening the app with ?demo=true,
  /// which is what the landing page's "Try the demo" button does.
  static final bool demo = const bool.fromEnvironment('DSCVR_DEMO') || _demoFromUrl();

  static bool _demoFromUrl() {
    try {
      final q = Uri.base.queryParameters['demo'];
      return q == 'true' || q == '1';
    } catch (_) {
      return false;
    }
  }

  /// Base URL of the deployed Cloud Functions (pinda, unfurl, parliament).
  static const String functionsUrl = String.fromEnvironment(
    'DSCVR_FUNCTIONS_URL',
    defaultValue: 'https://us-central1-dscvr-9d362.cloudfunctions.net',
  );

  /// Base URL of the dedicated Flask server (discover proxy, payments).
  /// This server handles CORS for web and provides added security.
  static const String _defaultServerUrl = 'https://api.askpinda.com';
  static const String _serverUrlDefine = String.fromEnvironment('DSCVR_SERVER_URL');

  /// A typo'd --dart-define (e.g. "dscvr-https://…") silently broke Discover
  /// once, so anything that isn't a clean https URL falls back to the default.
  static final String serverUrl = () {
    final raw = _serverUrlDefine.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return _defaultServerUrl;
    return raw.replaceAll(RegExp(r'/+$'), '');
  }();

  static const String storageBucket = 'gs://dscvr-9d362.firebasestorage.app';

  /// Google Pay merchant ID for payment processing.
  static const String googlePayMerchantId = String.fromEnvironment(
    'DSCVR_GPAY_MERCHANT_ID',
    defaultValue: '',
  );
}
