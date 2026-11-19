import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// The extension's content script marks the page when it's installed.
bool get extensionInstalled => web.document.documentElement?.getAttribute('data-dscvr-extension') != null;

/// Hands a sign-in token to the extension's content script on this page and
/// waits for it to confirm. Messages stay on this page's own origin.
Future<bool> sendTokenToExtension(String token) {
  final done = Completer<bool>();
  late final JSFunction listener;
  listener = ((web.MessageEvent e) {
    if (e.origin != web.window.location.origin) return;
    final data = e.data;
    if (data == null || !data.isA<JSObject>()) return;
    final type = (data as JSObject).getProperty<JSAny?>('type'.toJS);
    if (type.isA<JSString>() && (type as JSString).toDart == 'dscvr-extension-connected') {
      final ok = data.getProperty<JSAny?>('ok'.toJS);
      if (!done.isCompleted) done.complete(ok.isA<JSBoolean>() && (ok as JSBoolean).toDart);
    }
  }).toJS;
  web.window.addEventListener('message', listener);
  final msg = JSObject()
    ..setProperty('type'.toJS, 'dscvr-extension-token'.toJS)
    ..setProperty('token'.toJS, token.toJS);
  web.window.postMessage(msg, web.window.location.origin.toJS);
  return done.future.timeout(const Duration(seconds: 6), onTimeout: () => false).whenComplete(
        () => web.window.removeEventListener('message', listener),
      );
}
