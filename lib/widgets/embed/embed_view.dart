/// Embeds a web page, PDF or YouTube player.
///
/// Web: a sandboxed <iframe>. iOS/Android: a WebView. Other platforms show
/// an "open externally" fallback.
export 'embed_view_stub.dart'
    if (dart.library.js_interop) 'embed_view_web.dart'
    if (dart.library.io) 'embed_view_io.dart';
