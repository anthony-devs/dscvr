import 'package:dscvr/data/api.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/extension_bridge/extension_bridge.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/config/env.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

/// /connect-extension: signs the DSCVR browser extension in with this account.
/// The extension opens this page; the user confirms; the page asks the server
/// for an extension token and hands it to the extension on this page.
class ConnectExtensionPage extends StatefulWidget {
  const ConnectExtensionPage({super.key});

  @override
  State<ConnectExtensionPage> createState() => _ConnectExtensionPageState();
}

enum _Stage { ready, connecting, connected, noExtension, failed }

class _ConnectExtensionPageState extends State<ConnectExtensionPage> {
  _Stage _stage = _Stage.ready;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _stage = _Stage.connecting;
      _error = null;
    });
    try {
      if (!extensionInstalled) {
        setState(() => _stage = _Stage.noExtension);
        return;
      }
      final res = await context.services.api.post('/extension/token');
      final ok = await sendTokenToExtension(res['token'] as String);
      if (mounted) setState(() => _stage = ok ? _Stage.connected : _Stage.noExtension);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.failed;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = context.services.session.user;
    final (IconData icon, String title, String message) = switch (_stage) {
      _Stage.connected => (Ic.check, 'Extension connected', 'You can close this tab. Open DSCVR from the puzzle-piece menu in your browser toolbar, or pin it for one-click saving.'),
      _Stage.noExtension => (
          Ic.warning,
          "Couldn't find the extension",
          Env.chromeExtensionUrl.isEmpty
              ? 'The DSCVR extension is coming soon to the Chrome Web Store. Once it is installed in this browser, come back here and press Try again.'
              : 'Install the DSCVR extension in this browser, then come back here and press Try again.',
        ),
      _Stage.failed => (Ic.warning, "Couldn't connect", _error ?? 'Try again in a moment.'),
      _ => (Ic.globe, 'Connect the DSCVR extension', 'Save pages and papers to your library, find free PDFs and ask Pinda about what you are reading, from any site.'),
    };
    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 40, color: _stage == _Stage.connected ? c.success : c.ink),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: context.text.headlineSmall),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: AppTheme.sans(fontSize: 14.5, color: c.inkMuted, height: 1.5)),
              if (_stage == _Stage.ready || _stage == _Stage.connecting) ...[
                const SizedBox(height: 8),
                Text('Signed in as ${user.email}', textAlign: TextAlign.center, style: AppTheme.sans(fontSize: 13, color: c.inkMuted)),
              ],
              const SizedBox(height: 24),
              if (_stage == _Stage.connected)
                AppButton.secondary(onPressed: () => context.go('/recent'), child: const Text('Go to your library'))
              else
                AppButton.primary(
                  onPressed: _stage == _Stage.connecting ? null : _connect,
                  loading: _stage == _Stage.connecting,
                  child: Text(_stage == _Stage.ready || _stage == _Stage.connecting ? 'Connect' : 'Try again'),
                ),
              if (_stage == _Stage.noExtension && Env.chromeExtensionUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                AppButton.secondary(
                  onPressed: () => launchUrl(Uri.parse(Env.chromeExtensionUrl), webOnlyWindowName: '_blank'),
                  child: const Text('Get the extension'),
                ),
              ],
              const SizedBox(height: 12),
              Text('The extension can save to your library and use Pinda. It cannot change your plan, billing or account.',
                  textAlign: TextAlign.center, style: AppTheme.sans(fontSize: 12, color: c.inkMuted, height: 1.45)),
            ]),
          ),
        ),
      ),
    );
  }
}
