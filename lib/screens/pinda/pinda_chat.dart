import 'package:dscvr/screens/tour/page_tour.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dscvr/data/voice_service.dart';
import 'package:dscvr/models/pinda.dart';
import 'package:dscvr/state/services.dart';
import 'package:dscvr/state/pinda_controller.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/markdown_view.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

/// Pinda's face in chat: the curled-up pangolin.
class PindaAvatar extends StatelessWidget {
  const PindaAvatar({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset('assets/brand/mark.svg', semanticsLabel: 'Pinda'),
      );
}

/// The conversation surface: messages, suggested actions and composer.
/// Used full-page on /pinda and as a side panel in the reader.
class PindaChat extends StatefulWidget {
  const PindaChat({
    super.key,
    required this.controller,
    this.compact = false,
    this.header,
    this.emptyTitle,
    this.emptyMessage,
  });

  final PindaController controller;
  final bool compact;
  final Widget? header;
  final String? emptyTitle;
  final String? emptyMessage;

  @override
  State<PindaChat> createState() => PindaChatState();
}

class PindaChatState extends State<PindaChat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  int _lastCount = 0;
  int _lastLength = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant PindaChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChange() {
    final msgs = widget.controller.messages;
    final len = msgs.isEmpty ? 0 : msgs.last.text.length;
    if (msgs.length != _lastCount || len != _lastLength) {
      _lastCount = msgs.length;
      _lastLength = len;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
        }
      });
    }
  }

  /// Puts text in the composer (e.g. a passage selected in the reader).
  void prefill(String text) {
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
    _focus.requestFocus();
  }

  void ask(String text) => widget.controller.send(text);

  void _submit() {
    final t = _input.text;
    if (t.trim().isEmpty) return;
    _input.clear();
    widget.controller.send(t);
  }

  /// Hold a conversation by voice: listen, send what was said, and the
  /// page reads the answer back.
  Future<void> _toggleMic() async {
    final voice = context.services.voice;
    if (voice.listening) {
      await voice.stop();
      return;
    }
    final ok = await voice.listen(onFinal: (text) => widget.controller.send(text, voice: true));
    if (!ok && mounted && voice.error != null) toast(context, voice.error!);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctl = widget.controller;
        final msgs = ctl.messages;
        return Column(children: [
          if (widget.header != null) widget.header!,
          Expanded(
            child: ctl.isLoading
                ? const PageSpinner()
                : msgs.isEmpty
                    ? _Empty(
                        compact: widget.compact,
                        context: ctl.context,
                        title: widget.emptyTitle,
                        message: widget.emptyMessage,
                        onAction: (a) => ctl.send(a.prompt),
                      )
                    : SelectionArea(
                        child: ListView.builder(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(widget.compact ? 16 : 24, 16, widget.compact ? 16 : 24, 16),
                          itemCount: msgs.length,
                          itemBuilder: (context, i) => Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: _MessageView(
                                message: msgs[i],
                                onRetry: ctl.retry,
                                compact: widget.compact,
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(widget.compact ? 12 : 24, 6, widget.compact ? 12 : 24, widget.compact ? 12 : 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: TourTarget(id: 'pinda.input', child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: c.line),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.2 : 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 4, 6, 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _ListeningStrip(voice: context.services.voice),
                    CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.enter): _submit,
                      },
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        style: AppTheme.sans(fontSize: 14.5, color: c.ink, height: 1.45),
                        decoration: InputDecoration(
                          hintText: 'Ask Pinda about ${ctl.context.scope == PindaScope.general ? 'anything in your library' : ctl.context.label}',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    Row(children: [
                      Icon(_scopeIcon(ctl.context.scope), size: 14, color: c.inkFaint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ctl.context.scope == PindaScope.general ? 'Your whole library' : ctl.context.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelSmall,
                        ),
                      ),
                      if (!ctl.isStreaming)
                        ListenableBuilder(
                          listenable: context.services.voice,
                          builder: (context, _) {
                            final v = context.services.voice;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: TourTarget(id: 'pinda.mic', child: AppIconButton(
                                size: 34,
                                tooltip: v.listening ? 'Stop listening' : 'Ask by voice',
                                onPressed: _toggleMic,
                                icon: Icon(v.listening ? Ic.micFill : Ic.mic, size: 17, color: v.listening ? c.danger : null),
                              )),
                            );
                          },
                        ),
                      ListenableBuilder(
                        listenable: _input,
                        builder: (context, _) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                          child: ctl.isStreaming
                              ? AppIconButton(
                                  key: const ValueKey('stop'),
                                  filled: true,
                                  size: 34,
                                  tooltip: 'Stop',
                                  onPressed: ctl.stop,
                                  icon: const Icon(Ic.stop, size: 15),
                                )
                              : AppIconButton(
                                  key: const ValueKey('send'),
                                  filled: true,
                                  size: 34,
                                  tooltip: 'Send',
                                  onPressed: _input.text.trim().isEmpty ? null : _submit,
                                  icon: const Icon(Ic.arrowUp, size: 17),
                                ),
                        ),
                      ),
                    ]),
                  ]),
                )),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

IconData _scopeIcon(PindaScope s) => switch (s) {
      PindaScope.general => Ic.library,
      PindaScope.category => Ic.folder,
      PindaScope.topic => Ic.folderOpen,
      PindaScope.material => Ic.book,
    };

class _Empty extends StatelessWidget {
  const _Empty({required this.compact, required this.context, required this.onAction, this.title, this.message});
  final bool compact;
  final PindaContext context;
  final ValueChanged<PindaAction> onAction;
  final String? title;
  final String? message;

  @override
  Widget build(BuildContext ctx) {
    final c = ctx.colors;
    final edition = ctx.services.session.user.edition;
    final actions = context.scope == PindaScope.general
        ? edition.pindaActions
        : [...edition.pindaActions, ...PindaAction.values.where((a) => !edition.pindaActions.contains(a))];
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 20 : 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: compact ? 8 : 40),
            PindaFigure(width: compact ? 120 : 170),
            const SizedBox(height: 16),
            Text(title ?? 'What are you trying to understand?',
                style: compact ? ctx.text.headlineSmall : ctx.text.headlineLarge),
            const SizedBox(height: 8),
            Text(
              message ??
                  (context.scope == PindaScope.general
                      ? 'Pinda reads the materials and notes in your library and answers with references to them.'
                      : 'Pinda has read ${context.label}. Ask anything, or start with one of these.'),
              style: AppTheme.sans(fontSize: 14, color: c.inkMuted, height: 1.55),
            ),
            const SizedBox(height: 22),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in actions) PillButton(label: a.label, icon: _actionIcon(a), onTap: () => onAction(a)),
            ]),
          ]),
        ),
      ),
    );
  }

  IconData _actionIcon(PindaAction a) => switch (a) {
        PindaAction.summarize => Ic.list,
        PindaAction.explain => Ic.lightning,
        PindaAction.questions => Ic.chat,
        PindaAction.studyGuide => Ic.notebook,
        PindaAction.quiz => Ic.check,
        PindaAction.factCheck => Ic.done,
      };
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message, required this.onRetry, required this.compact});
  final ChatMessage message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (message.role == ChatRole.user) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18, left: 48),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: c.line),
            ),
            child: Text(message.text, style: AppTheme.sans(fontSize: 14.5, color: c.ink, height: 1.5)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const PindaAvatar(size: 20),
          const SizedBox(width: 8),
          Text('Pinda', style: AppTheme.sans(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.ink)),
          const Spacer(),
          if (!message.pending && message.text.isNotEmpty)
            _ReadAloud(text: message.text),
          if (!message.pending && message.text.isNotEmpty)
            AppIconButton(
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message.text));
                toast(context, 'Copied');
              },
              icon: const Icon(Ic.copy, size: 15),
            ),
        ]),
        const SizedBox(height: 6),
        if (message.text.isEmpty && message.pending)
          const _Typing()
        else
          MarkdownView(message.text, scale: compact ? 0.97 : 1.0),
        if (message.error != null)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.danger.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Ic.warning, size: 16, color: c.danger),
              const SizedBox(width: 8),
              Expanded(child: Text(message.error!, style: AppTheme.sans(fontSize: 13, color: c.ink))),
              if (message.error!.contains('Upgrade for more'))
                AppButton.primary(size: BtnSize.sm, onPressed: () => GoRouter.of(context).go('/plans'), label: const Text('See plans'))
              else
                AppButton.ghost(onPressed: onRetry, icon: const Icon(Ic.retry, size: 14), label: const Text('Retry')),
            ]),
          ),
      ]),
    );
  }
}

class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 22,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => Row(children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(right: 5),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: c.inkFaint.withValues(
                    alpha: 0.3 + 0.7 * (1 - ((_anim.value * 3 - i) % 3).clamp(0, 1).toDouble())),
                shape: BoxShape.circle,
              ),
            ),
        ]),
      ),
    );
  }
}


/// Live transcript shown above the composer while listening.
class _ListeningStrip extends StatelessWidget {
  const _ListeningStrip({required this.voice});
  final VoiceService voice;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) => AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: !voice.listening
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  VoiceLevel(level: voice.level),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      voice.words.isEmpty ? 'Listening...' : voice.words,
                      style: AppTheme.sans(fontSize: 14, color: voice.words.isEmpty ? c.inkFaint : c.ink, height: 1.45),
                    ),
                  ),
                ]),
              ),
      ),
    );
  }
}

/// Three bars that follow the microphone level.
class VoiceLevel extends StatelessWidget {
  const VoiceLevel({super.key, required this.level, this.color});
  final double level;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final col = color ?? context.colors.danger;
    return SizedBox(
      height: 20,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final f in const [0.6, 1.0, 0.75])
          AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            margin: const EdgeInsets.only(right: 3),
            width: 3,
            height: 5 + 15 * (level * f).clamp(0.0, 1.0),
            decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2)),
          ),
      ]),
    );
  }
}

class _ReadAloud extends StatelessWidget {
  const _ReadAloud({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final voice = context.services.voice;
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) => AppIconButton(
        tooltip: voice.speaking ? 'Stop reading' : 'Read aloud',
        visualDensity: VisualDensity.compact,
        onPressed: () => voice.speaking ? voice.stopSpeaking() : voice.speak(text),
        icon: Icon(voice.speaking ? Ic.speakerOff : Ic.speaker, size: 15),
      ),
    );
  }
}
