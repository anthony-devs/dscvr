import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get canDownload => true;

/// Triggers a browser download of [text] as [fileName].
void downloadText(String fileName, String text, {String mime = 'text/markdown'}) {
  final blob = web.Blob([utf8.encode(text).toJS].toJS, web.BlobPropertyBag(type: '$mime;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}
