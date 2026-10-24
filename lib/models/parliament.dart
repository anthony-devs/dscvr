/// Parliament Fact-Check: multi-model voting on a claim.
///
/// The user highlights a claim in a paper or article. Parliament sends it to
/// multiple models (or the same model with different system prompts playing
/// roles: Advocate, Skeptic, Analyst). Each "member" returns a verdict and
/// reasoning. A consensus is derived from the votes.

enum Verdict {
  supported('Supported'),
  partiallySupported('Partially supported'),
  unsupported('Unsupported'),
  insufficientEvidence('Insufficient evidence');

  const Verdict(this.label);
  final String label;

  static Verdict fromString(String s) => switch (s.toLowerCase()) {
        'supported' => Verdict.supported,
        'partially_supported' || 'partiallysupported' => Verdict.partiallySupported,
        'unsupported' => Verdict.unsupported,
        _ => Verdict.insufficientEvidence,
      };
}

/// One member's vote on the claim.
class ParliamentVote {
  const ParliamentVote({
    required this.role,
    required this.verdict,
    required this.reasoning,
    this.confidence = 0.0,
  });

  final String role; // e.g. "Advocate", "Skeptic", "Analyst"
  final Verdict verdict;
  final String reasoning;
  final double confidence; // 0..1

  factory ParliamentVote.fromMap(Map<String, dynamic> m) => ParliamentVote(
        role: m['role'] as String? ?? 'Member',
        verdict: Verdict.fromString(m['verdict'] as String? ?? ''),
        reasoning: m['reasoning'] as String? ?? '',
        confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toMap() => {
        'role': role,
        'verdict': verdict.name,
        'reasoning': reasoning,
        'confidence': confidence,
      };
}

/// The complete result of a Parliament fact-check session.
class ParliamentResult {
  const ParliamentResult({
    required this.claim,
    required this.votes,
    required this.consensus,
    required this.summary,
    this.sources = const [],
  });

  final String claim;
  final List<ParliamentVote> votes;
  final Verdict consensus;
  final String summary; // plain-language synthesis
  final List<String> sources;

  factory ParliamentResult.fromMap(Map<String, dynamic> m) => ParliamentResult(
        claim: m['claim'] as String? ?? '',
        votes: (m['votes'] as List?)?.map((v) => ParliamentVote.fromMap(v as Map<String, dynamic>)).toList() ?? [],
        consensus: Verdict.fromString(m['consensus'] as String? ?? ''),
        summary: m['summary'] as String? ?? '',
        sources: (m['sources'] as List?)?.cast<String>() ?? [],
      );

  Map<String, dynamic> toMap() => {
        'claim': claim,
        'votes': votes.map((v) => v.toMap()).toList(),
        'consensus': consensus.name,
        'summary': summary,
        'sources': sources,
      };
}
