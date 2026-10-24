import 'dart:convert';

import 'package:dscvr/config/env.dart';
import 'package:dscvr/models/parliament.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Calls the Parliament Cloud Function to fact-check a claim.
class ParliamentService {
  const ParliamentService();

  /// Fact-checks [claim] with optional surrounding [context].
  /// Throws on network or auth errors.
  Future<ParliamentResult> check(String claim, {String? context}) async {
    if (Env.demo) return _demoResult(claim);

    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Sign in to use Parliament.');

    final resp = await http.post(
      Uri.parse('${Env.functionsUrl}/parliament'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'claim': claim,
        if (context != null) 'context': context,
      }),
    );

    if (resp.statusCode != 200) {
      final msg = _errorMsg(resp);
      throw Exception(msg);
    }

    return ParliamentResult.fromMap(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  String _errorMsg(http.Response r) {
    try {
      return (jsonDecode(r.body) as Map)['error'] as String? ?? 'Request failed (${r.statusCode})';
    } catch (_) {
      return 'Request failed (${r.statusCode})';
    }
  }

  /// In demo mode, return a canned result.
  ParliamentResult _demoResult(String claim) => ParliamentResult(
        claim: claim,
        votes: [
          ParliamentVote(
            role: 'Advocate',
            verdict: Verdict.supported,
            confidence: 0.82,
            reasoning: 'Multiple peer-reviewed studies corroborate this finding with consistent methodology and sample sizes.',
          ),
          ParliamentVote(
            role: 'Skeptic',
            verdict: Verdict.partiallySupported,
            confidence: 0.65,
            reasoning: 'While the core finding holds, the effect size may be overstated. Two replication studies showed smaller effects.',
          ),
          ParliamentVote(
            role: 'Analyst',
            verdict: Verdict.supported,
            confidence: 0.74,
            reasoning: 'The weight of evidence supports this claim, though with caveats about generalizability across populations.',
          ),
        ],
        consensus: Verdict.supported,
        summary: 'The claim is broadly supported by the available evidence, with caveats around effect size and '
            'generalizability. The Advocate finds strong methodological backing, while the Skeptic notes some '
            'replication concerns. Overall, the evidence leans in favor of the claim.',
      );
}
