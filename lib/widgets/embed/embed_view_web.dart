import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class EmbedView extends StatelessWidget {
  const EmbedView({super.key, required this.url, this.isPdf = false});
  final String url;
  final bool isPdf;

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      key: ValueKey(url),
      tagName: 'iframe',
      onElementCreated: (Object el) {
        final frame = el as web.HTMLIFrameElement;
        frame.src = url;
        frame.style
          ..border = 'none'
          ..width = '100%'
          ..height = '100%';
        frame.allow = 'autoplay; encrypted-media; fullscreen; picture-in-picture';
        frame.allowFullscreen = true;
      },
    );
  }
}
