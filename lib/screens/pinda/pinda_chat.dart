import 'package:dscvr/models/pinda.dart';
import 'package:dscvr/state/pinda_controller.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/common.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/widgets/markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PindaAvatar extends StatelessWidget {
  const PindaAvatar({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CategoryPalette.of(0), CategoryPalette.of(2)],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(Ic.pinda, size: size * 0.58, color: c.isDark ? Colors.white : Colors.white),
    );
  }
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
  void didUpdateWidget(covariant PindaChat old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChange);
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
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
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
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: c.line),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.2 : 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 4, 6, 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
                      ListenableBuilder(
                        listenable: _input,
                        builder: (context, _) => ctl.isStreaming
                            ? IconButton.filled(
                                tooltip: 'Stop',
                                onPressed: ctl.stop,
                                style: IconButton.styleFrom(backgroundColor: c.ink, foregroundColor: c.inverseInk),
                                icon: const Icon(Ic.stop, size: 16),
                              )
                            : IconButton.filled(
                                tooltip: 'Send',
                                onPressed: _input.text.trim().isEmpty ? null : _submit,
                                style: IconButton.styleFrom(
                                  backgroundColor: c.ink,
                                  foregroundColor: c.inverseInk,
                                  disabledBackgroundColor: c.surfaceMuted,
                                  disabledForegroundColor: c.inkFaint,
                                ),
                                icon: const Icon(Ic.send, size: 16),
                              ),
                      ),
                    ]),
                  ]),
                ),
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
    final actions = context.scope == PindaScope.general
        ? const [PindaAction.explain, PindaAction.questions, PindaAction.studyGuide, PindaAction.quiz]
        : PindaAction.values;
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 20 : 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: compact ? 8 : 40),
            PindaAvatar(size: compact ? 32 : 40),
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
            IconButton(
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
              TextButton.icon(onPressed: onRetry, icon: const Icon(Ic.retry, size: 14), label: const Text('Retry')),
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
