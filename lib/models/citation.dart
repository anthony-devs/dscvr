import 'package:dscvr/models/library.dart';
import 'package:dscvr/models/paper.dart';
import 'package:intl/intl.dart';

/// Citation styles. Judgments use case-citation forms in every style.
enum CiteStyle {
  apa('APA 7'),
  harvard('Harvard'),
  vancouver('Vancouver'),
  mla('MLA 9'),
  chicago('Chicago (author-date)'),
  oscola('OSCOLA'),
  nigerian('Nigerian legal');

  const CiteStyle(this.label);
  final String label;

  bool get isLegal => this == oscola || this == nigerian;
}

/// Everything a citation needs, from a search result or a library item.
class CiteSource {
  const CiteSource({
    required this.title,
    this.authors = const [],
    this.year,
    this.venue,
    this.url,
    this.doi,
    this.pmid,
    this.isJudgment = false,
    this.caseCitation,
    this.court,
    this.date,
  });

  final String title;
  final List<String> authors;
  final int? year;
  final String? venue;
  final String? url;
  final String? doi;
  final String? pmid;
  final bool isJudgment;
  final String? caseCitation;
  final String? court;
  final String? date;

  factory CiteSource.fromPaper(Paper p) => CiteSource(
        title: p.title,
        authors: p.isJudgment ? const [] : p.authors,
        year: p.year,
        venue: p.isJudgment ? null : p.venue,
        url: p.url,
        doi: p.doi ?? _doiIn(p.url),
        pmid: p.pmid,
        isJudgment: p.isJudgment,
        caseCitation: p.citation,
        court: p.court,
        date: p.date,
      );

  factory CiteSource.fromItem(LibraryItem i) {
    final looksLikeCase = RegExp(r'\bv\.?\s', caseSensitive: false).hasMatch(i.title) &&
        (i.source == 'uk_caselaw' || RegExp(r'NWLR|LPELR|UKSC|EWCA|EWHC|SC\.|\(CA\)|\[\d{4}\]').hasMatch('${i.title} ${i.summary}'));
    return CiteSource(
      title: i.title,
      authors: looksLikeCase ? const [] : i.authors,
      year: i.year,
      venue: looksLikeCase ? null : i.siteName,
      url: i.url,
      doi: _doiIn(i.url),
      isJudgment: looksLikeCase,
      caseCitation: looksLikeCase ? _caseCitationIn('${i.title} ${i.summary}') : null,
    );
  }

  static String? _doiIn(String? url) {
    if (url == null) return null;
    final m = RegExp(r'10\.\d{4,9}/[^\s?#]+', caseSensitive: false).firstMatch(url);
    return m?.group(0);
  }

  static String? _caseCitationIn(String text) {
    final m = RegExp(r'(\(\d{4}\)\s*\d*\s*NWLR\s*\(Pt\.?\s*\d+\)\s*\d+|\(\d{4}\)\s*LPELR-\d+\s*\([A-Z]+\)|\[\d{4}\]\s*[A-Z]{2,6}(?:\s+Civ|\s+Crim)?\s+\d+(?:\s*\([A-Za-z]+\))?)')
        .firstMatch(text);
    return m?.group(0);
  }
}

/// A name split into surname and given names, from "Okafor A" or
/// "Ada Okafor" or "Okafor, Ada".
class _Name {
  _Name(this.family, this.given);
  final String family;
  final List<String> given;

  factory _Name.parse(String raw) {
    final n = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (n.contains(',')) {
      final parts = n.split(',');
      return _Name(parts.first.trim(), parts.skip(1).join(' ').trim().split(' ').where((p) => p.isNotEmpty).toList());
    }
    final words = n.split(' ');
    if (words.length > 1 && RegExp(r'^[A-Z]{1,3}$').hasMatch(words.last)) {
      // PubMed style: "Okafor AB"
      return _Name(words.take(words.length - 1).join(' '), words.last.split(''));
    }
    if (words.length == 1) return _Name(n, const []);
    return _Name(words.last, words.take(words.length - 1).toList());
  }

  String get initialsDotted => given.map((g) => '${g[0].toUpperCase()}.').join(' ');
  String get initialsTight => given.map((g) => g[0].toUpperCase()).join();
  String get givenFull => given.join(' ');

  bool get isOrg => given.isEmpty;
}

class Citations {
  Citations._();

  static String format(CiteSource s, CiteStyle style, {DateTime? accessed}) {
    if (s.isJudgment) return _case(s, style);
    final names = s.authors.where((a) => a.trim().isNotEmpty).map(_Name.parse).toList();
    final year = s.year?.toString() ?? 'n.d.';
    final title = _sentence(s.title);
    final venue = s.venue;
    final link = s.doi != null ? 'https://doi.org/${s.doi}' : s.url;
    final today = DateFormat('d MMMM y').format(accessed ?? DateTime.now());

    switch (style) {
      case CiteStyle.apa:
        final a = _join(names.take(20).map((n) => n.isOrg ? n.family : '${n.family}, ${n.initialsDotted}').toList(), '&');
        return _clean('${a.isEmpty ? '' : '$a '}($year). $title.${venue != null ? ' *$venue*.' : ''}${link != null ? ' $link' : ''}');
      case CiteStyle.harvard:
        final a = _join(names.take(3).map((n) => n.isOrg ? n.family : '${n.family}, ${n.initialsDotted.replaceAll(' ', '')}').toList(), 'and');
        final etal = names.length > 3 ? '${names.first.family} et al.' : a;
        return _clean("${etal.isEmpty ? '' : '$etal '}($year) '$title',${venue != null ? ' *$venue*.' : ''}"
            "${s.url != null ? ' Available at: ${link ?? s.url} (Accessed: $today).' : ''}");
      case CiteStyle.vancouver:
        final list = names.take(6).map((n) => n.isOrg ? n.family : '${n.family} ${n.initialsTight}').toList();
        final a = list.join(', ') + (names.length > 6 ? ', et al' : '');
        return _clean('${a.isEmpty ? '' : '$a. '}$title.${venue != null ? ' $venue.' : ''} $year.'
            '${s.doi != null ? ' doi:${s.doi}' : ''}${s.pmid != null ? ' PMID: ${s.pmid}.' : ''}'
            '${s.doi == null && s.pmid == null && s.url != null ? ' Available from: ${s.url}' : ''}');
      case CiteStyle.mla:
        final a = names.isEmpty
            ? ''
            : names.length == 1
                ? _mlaName(names.first)
                : names.length == 2
                    ? '${_mlaName(names.first)}, and ${names[1].givenFull} ${names[1].family}'
                    : '${_mlaName(names.first)}, et al';
        return _clean('${a.isEmpty ? '' : '$a. '}"${_title(s.title)}."${venue != null ? ' *$venue*,' : ''} $year'
            '${link != null ? ', $link' : ''}.');
      case CiteStyle.chicago:
        final a = names.isEmpty
            ? ''
            : _join([
                _mlaName(names.first),
                for (final n in names.skip(1).take(9)) n.isOrg ? n.family : '${n.givenFull} ${n.family}',
              ], 'and');
        return _clean('${a.isEmpty ? '' : '$a. '}$year. "${_title(s.title)}."${venue != null ? ' *$venue*.' : ''}'
            '${link != null ? ' $link.' : ''}');
      case CiteStyle.oscola:
        final a = _join(names.take(3).map((n) => n.isOrg ? n.family : '${n.givenFull} ${n.family}').toList(), 'and') +
            (names.length > 3 ? ' and others' : '');
        return _clean("${a.isEmpty ? '' : '$a, '}'${_title(s.title)}' ($year)${venue != null ? ' $venue' : ''}"
            '${link != null ? ' <$link> accessed $today' : ''}');
      case CiteStyle.nigerian:
        final a = _join(names.take(3).map((n) => n.isOrg ? n.family : '${n.givenFull} ${n.family}').toList(), '&');
        return _clean("${a.isEmpty ? '' : '$a, '}\"${_title(s.title)}\"${venue != null ? ' ($year) $venue' : ' ($year)'}"
            '${link != null ? ', available at $link' : ''}');
    }
  }

  /// Case citations. Uses the citation exactly as given and never invents
  /// a law-report reference.
  static String _case(CiteSource s, CiteStyle style) {
    final name = s.title.trim();
    final cit = s.caseCitation?.trim();
    final court = s.court?.trim();
    final year = s.year?.toString() ?? (s.date?.substring(0, 4));
    switch (style) {
      case CiteStyle.oscola:
        // OSCOLA: case name in italics, neutral citation, no full stop.
        return '*$name* ${cit ?? (year != null ? '[$year]' : '')}'.trim();
      case CiteStyle.nigerian:
        // e.g. Okafor v Bello (2016) LPELR-40000 (SC). Brackets as given.
        return '*$name* ${cit ?? (year != null ? '($year)' : '')}${court != null && cit == null ? ' ($court)' : ''}'.trim();
      case CiteStyle.apa:
      case CiteStyle.chicago:
        return '*$name*, ${cit ?? ''}${court != null ? ' ($court${year != null ? ' $year' : ''})' : ''}${s.url != null ? '. ${s.url}' : ''}'
            .replaceAll(' ,', ',').trim();
      case CiteStyle.harvard:
      case CiteStyle.mla:
      case CiteStyle.vancouver:
        return '*$name* ${cit ?? (year != null ? '($year)' : '')}${court != null ? ', $court' : ''}.'.trim();
    }
  }

  static String _mlaName(_Name n) => n.isOrg ? n.family : '${n.family}, ${n.givenFull}';

  static String _join(List<String> parts, String and) {
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    final sep = and == '&' ? ', & ' : ' $and ';
    return '${parts.take(parts.length - 1).join(', ')}${parts.length > 2 && and != '&' ? ',' : ''}$sep${parts.last}';
  }

  static String _sentence(String t) => t.trim().replaceAll(RegExp(r'[.\s]+$'), '');
  static String _title(String t) => _sentence(t);

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').replaceAll(' .', '.').replaceAll('..', '.').trim();

  /// Removes the *italics* markers, for pasting where Markdown doesn't render.
  static String plain(String s) => s.replaceAll('*', '');

  // ── Reference manager formats ──────────────────────────────────────

  static String bibtex(List<CiteSource> items) {
    final used = <String>{};
    final out = StringBuffer();
    for (final s in items) {
      final first = s.authors.isEmpty ? 'anon' : _Name.parse(s.authors.first).family;
      var key = '${first.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')}${s.year ?? ''}';
      if (key.isEmpty) key = 'item';
      var k = key;
      for (var i = 1; used.contains(k); i++) {
        k = '$key${String.fromCharCode(96 + i)}';
      }
      used.add(k);
      String esc(String v) => v.replaceAll('{', r'\{').replaceAll('}', r'\}');
      out.writeln('@${s.isJudgment ? 'misc' : (s.venue != null ? 'article' : 'misc')}{$k,');
      out.writeln('  title = {${esc(s.title)}},');
      if (s.authors.isNotEmpty) {
        out.writeln('  author = {${s.authors.map((a) {
          final n = _Name.parse(a);
          return n.isOrg ? '{${esc(n.family)}}' : '${esc(n.family)}, ${esc(n.givenFull)}';
        }).join(' and ')}},');
      }
      if (s.year != null) out.writeln('  year = {${s.year}},');
      if (s.venue != null) out.writeln('  journal = {${esc(s.venue!)}},');
      if (s.doi != null) out.writeln('  doi = {${s.doi}},');
      if (s.caseCitation != null) out.writeln('  note = {${esc(s.caseCitation!)}${s.court != null ? ', ${esc(s.court!)}' : ''}},');
      if (s.url != null) out.writeln('  url = {${s.url}},');
      out.writeln('}');
      out.writeln();
    }
    return out.toString();
  }

  static String ris(List<CiteSource> items) {
    final out = StringBuffer();
    for (final s in items) {
      out.writeln('TY  - ${s.isJudgment ? 'CASE' : (s.venue != null ? 'JOUR' : 'GEN')}');
      out.writeln('TI  - ${s.title}');
      for (final a in s.authors) {
        final n = _Name.parse(a);
        out.writeln('AU  - ${n.isOrg ? n.family : '${n.family}, ${n.givenFull}'}');
      }
      if (s.year != null) out.writeln('PY  - ${s.year}');
      if (s.venue != null) out.writeln('JO  - ${s.venue}');
      if (s.court != null) out.writeln('PB  - ${s.court}');
      if (s.caseCitation != null) out.writeln('M1  - ${s.caseCitation}');
      if (s.doi != null) out.writeln('DO  - ${s.doi}');
      if (s.pmid != null) out.writeln('AN  - PMID:${s.pmid}');
      if (s.url != null) out.writeln('UR  - ${s.url}');
      out.writeln('ER  - ');
      out.writeln();
    }
    return out.toString();
  }
}
