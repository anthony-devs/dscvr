import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EmbedView extends StatefulWidget {
  const EmbedView({super.key, required this.url, this.isPdf = false});
  final String url;
  final bool isPdf;

  @override
  State<EmbedView> createState() => _EmbedViewState();
}

class _EmbedViewState extends State<EmbedView> {
  WebViewController? _controller;
  bool _loading = true;

  bool get _supported =>
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (_supported) _init();
  }

  @override
  void didUpdateWidget(covariant EmbedView old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url && _controller != null) {
      _controller!.loadRequest(Uri.parse(_effectiveUrl));
    }
  }

  /// Android's WebView cannot render PDFs itself, so route them through
  /// Google's document viewer. iOS (WKWebView) renders PDFs natively.
  String get _effectiveUrl {
    if (widget.isPdf && defaultTargetPlatform == TargetPlatform.android) {
      return 'https://docs.google.com/gview?embedded=1&url=${Uri.encodeComponent(widget.url)}';
    }
    return widget.url;
  }

  void _init() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(_effectiveUrl));
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      final c = context.colors;
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Ic.external, color: c.inkMuted),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
            child: const Text('Open in browser'),
          ),
        ]),
      );
    }
    return Stack(children: [
      WebViewWidget(controller: _controller!),
      if (_loading) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    ]);
  }
}
