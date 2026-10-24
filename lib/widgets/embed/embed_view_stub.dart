import 'package:flutter/widgets.dart';

class EmbedView extends StatelessWidget {
  const EmbedView({super.key, required this.url, this.isPdf = false});
  final String url;
  final bool isPdf;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
