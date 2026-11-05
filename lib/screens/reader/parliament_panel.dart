import 'package:dscvr/data/parliament_service.dart';
import 'package:dscvr/models/parliament.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:dscvr/theme/tokens.dart';
import 'package:dscvr/widgets/icons.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:flutter/material.dart';

/// Panel that shows Parliament Fact-Check results for a highlighted claim.
class ParliamentPanel extends StatefulWidget {
  const ParliamentPanel({super.key, this.initialClaim, this.materialContext});
  final String? initialClaim;
  final String? materialContext;

  @override
  State<ParliamentPanel> createState() => ParliamentPanelState();
}

class ParliamentPanelState extends State<ParliamentPanel> {
  final _controller = TextEditingController();
  final _service = const ParliamentService();
  ParliamentResult? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialClaim != null) {
      _controller.text = widget.initialClaim!;
    }
  }

  void prefill(String claim) {
    _controller.text = claim;
    _check();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final claim = _controller.text.trim();
    if (claim.length < 5) {
      setState(() => _error = 'Enter a claim to fact-check (at least 5 characters).');
      return;
    }

    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final result = await _service.check(claim, context: widget.materialContext);
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Input area
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Fact-Check a Claim', style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w600, color: c.inkMuted, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          AppField(
            controller: _controller,
            hint: 'Paste or type a claim to evaluate...',
            maxLines: 3,
            minLines: 2,
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(
                'Parliament sends the claim to three AI perspectives for independent evaluation.',
                style: AppTheme.sans(fontSize: 11.5, color: c.inkFaint, height: 1.3),
              ),
            ),
            const SizedBox(width: 8),
            AppButton.primary(
              onPressed: _loading ? null : _check,
              size: BtnSize.sm,
              icon: _loading
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.inverseInk))
                  : const Icon(Ic.scale, size: 14),
              label: Text(_loading ? 'Checking...' : 'Check'),
            ),
          ]),
        ]),
      ),
      Divider(color: c.line, height: 1),

      // Results area
      Expanded(
        child: _error != null
            ? _ErrorView(error: _error!)
            : _result != null
                ? _ResultView(result: _result!)
                : _loading
                    ? _LoadingView()
                    : _EmptyView(),
      ),
    ]);
  }
}


class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Ic.scale, size: 32, color: c.inkFaint.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text(
            'Select text from the document and choose "Fact-check", or type a claim above.',
            textAlign: TextAlign.center,
            style: AppTheme.sans(fontSize: 13, color: c.inkFaint, height: 1.4),
          ),
        ]),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: c.ink)),
          const SizedBox(height: 18),
          Text('Convening Parliament...', style: AppTheme.serif(fontSize: 16, fontWeight: FontWeight.w600, color: c.ink)),
          const SizedBox(height: 8),
          Text(
            'Three perspectives are independently evaluating this claim.',
            textAlign: TextAlign.center,
            style: AppTheme.sans(fontSize: 13, color: c.inkMuted, height: 1.4),
          ),
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Ic.warning, size: 28, color: c.danger),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center, style: AppTheme.sans(fontSize: 13.5, color: c.inkMuted, height: 1.4)),
        ]),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final ParliamentResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Consensus badge
        _ConsensusBadge(verdict: result.consensus),
        const SizedBox(height: 14),

        // Claim
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Ic.quote, size: 14, color: c.inkFaint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.claim,
                style: AppTheme.serif(fontSize: 13.5, fontStyle: FontStyle.italic, color: c.ink, height: 1.4),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Summary
        Text(result.summary, style: AppTheme.sans(fontSize: 13.5, color: c.ink, height: 1.5)),
        const SizedBox(height: 20),

        // Individual votes
        Text('Perspectives', style: AppTheme.sans(fontSize: 12, fontWeight: FontWeight.w600, color: c.inkMuted, letterSpacing: 0.3)),
        const SizedBox(height: 10),
        for (final vote in result.votes) ...[
          _VoteCard(vote: vote),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

class _ConsensusBadge extends StatelessWidget {
  const _ConsensusBadge({required this.verdict});
  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, icon) = switch (verdict) {
      Verdict.supported => (c.success, Ic.check),
      Verdict.partiallySupported => (const Color(0xFFD4A017), Ic.minus),
      Verdict.unsupported => (c.danger, Ic.close),
      Verdict.insufficientEvidence => (c.inkMuted, Ic.question),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.1),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          verdict.label,
          style: AppTheme.sans(fontSize: 14, fontWeight: FontWeight.w600, color: color),
        ),
      ]),
    );
  }
}

class _VoteCard extends StatefulWidget {
  const _VoteCard({required this.vote});
  final ParliamentVote vote;

  @override
  State<_VoteCard> createState() => _VoteCardState();
}

class _VoteCardState extends State<_VoteCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final vote = widget.vote;
    final verdictColor = switch (vote.verdict) {
      Verdict.supported => c.success,
      Verdict.partiallySupported => const Color(0xFFD4A017),
      Verdict.unsupported => c.danger,
      Verdict.insufficientEvidence => c.inkMuted,
    };

    return Pressable(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: ShapeDecoration(
          color: c.surface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: BorderSide(color: c.line),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: verdictColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  vote.role[0],
                  style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w700, color: verdictColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(vote.role, style: AppTheme.sans(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                Text(
                  '${vote.verdict.label} (${(vote.confidence * 100).round()}%)',
                  style: AppTheme.sans(fontSize: 11.5, color: verdictColor),
                ),
              ]),
            ),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Ic.caretDown, size: 14, color: c.inkFaint),
            ),
          ]),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(vote.reasoning, style: AppTheme.sans(fontSize: 13, color: c.inkMuted, height: 1.45)),
            ),
          ),
        ]),
      ),
    );
  }
}
