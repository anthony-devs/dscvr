import 'package:dscvr/data/discover_service.dart';
import 'package:dscvr/models/citation.dart';
import 'package:dscvr/models/paper.dart';
import 'package:dscvr/models/profession.dart';
import 'package:dscvr/state/settings_controller.dart';
import 'package:dscvr/ui/ui.dart';
import 'package:dscvr/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Subjects', () {
    test('every catalog label is unique and every alias resolves', () {
      final labels = Subject.catalog.map((s) => s.label.toLowerCase()).toList();
      expect(labels.toSet().length, labels.length);
      for (final a in ['MBBS', 'O&G', 'Paeds', 'ENT', 'Tort', 'Land Law', 'IP', 'ADR', 'Med-Surg', 'Audit']) {
        expect(Subject.lookup(a), isNotNull, reason: a);
      }
    });

    test('health subjects use Europe PMC, law areas use UK case law', () {
      expect(Subject.lookup('Nursing')!.feed, Feed.europepmc);
      expect(Subject.lookup('Clinical Guidelines')!.guidelines, isTrue);
      expect(Subject.lookup('Contract Law')!.feed, Feed.caselaw);
      expect(Subject.lookup('Contract Law')!.isLaw, isTrue);
      expect(Subject.lookup('Machine Learning')!.feed, Feed.arxiv);
      expect(Subject.lookup('Marketing')!.feed, Feed.openalex);
      expect(Subject.custom('Igbo oral poetry').feed, Feed.openalex);
      expect(PaperSource.forFeed(Feed.caselaw), PaperSource.ukCaseLaw);
    });

    test('search finds word starts, not only prefixes', () {
      expect(Subject.search('nursing').map((s) => s.label), containsAll(['Nursing', 'Paediatric Nursing', 'Nursing Education']));
      expect(Subject.search('tort').first.label, 'Tort Law');
    });

    test('every profession starter subject exists', () {
      for (final p in Profession.values) {
        expect(p.subjects.length, p.starter.length, reason: p.label);
      }
      expect(Profession.guess(['Contract Law', 'Tort Law']), Profession.law);
      expect(Profession.guess(['Midwifery', 'Nursing']), Profession.nursing);
      expect(Profession.fromId('law'), Profession.law);
    });

    test('law libraries build search links', () {
      final ng = LawLibrary.all.firstWhere((l) => l.name == 'NigeriaLII');
      expect(ng.searchUri('land use act').toString(), 'https://nigerialii.org/search/?q=land+use+act');
    });
  });

  group('Citations', () {
    const article = CiteSource(
      title: 'Malaria in children.',
      authors: ['Okafor AB', 'Bello C'],
      year: 2025,
      venue: 'Lancet',
      doi: '10.1/xyz',
      pmid: '123',
    );

    test('APA', () {
      expect(Citations.format(article, CiteStyle.apa), 'Okafor, A. B., & Bello, C. (2025). Malaria in children. *Lancet*. https://doi.org/10.1/xyz');
    });

    test('Vancouver', () {
      expect(Citations.format(article, CiteStyle.vancouver), 'Okafor AB, Bello C. Malaria in children. Lancet. 2025. doi:10.1/xyz PMID: 123.');
    });

    test('full names are split into surname and initials', () {
      const s = CiteSource(title: 'T', authors: ['Ada Ngozi Eze'], year: 2020);
      expect(Citations.format(s, CiteStyle.apa), startsWith('Eze, A. N. (2020)'));
      expect(Citations.format(s, CiteStyle.mla), startsWith('Eze, Ada Ngozi.'));
    });

    test('judgments use the citation as given and never invent one', () {
      final p = Paper.fromMap({
        'id': 'uksc/2026/1', 'title': 'A v B', 'source': 'uk_caselaw', 'kind': 'judgment',
        'citation': '[2026] UKSC 1', 'court': 'United Kingdom Supreme Court', 'year': 2026,
      });
      final s = CiteSource.fromPaper(p);
      expect(Citations.format(s, CiteStyle.oscola), '*A v B* [2026] UKSC 1');
      expect(Citations.plain(Citations.format(s, CiteStyle.nigerian)), 'A v B [2026] UKSC 1');
      const bare = CiteSource(title: 'Okafor v Bello', isJudgment: true, year: 2016);
      expect(Citations.format(bare, CiteStyle.nigerian), '*Okafor v Bello* (2016)');
    });

    test('BibTeX and RIS', () {
      final bib = Citations.bibtex([article, article]);
      expect(bib, contains('@article{okafor2025,'));
      expect(bib, contains('@article{okafor2025a,'));
      expect(bib, contains('author = {Okafor, A B and Bello, C}'));
      final ris = Citations.ris([article]);
      expect(ris, contains('TY  - JOUR'));
      expect(ris, contains('AU  - Okafor, A B'));
      expect(ris, contains('DO  - 10.1/xyz'));
    });
  });

  group('Accessibility settings', () {
    test('persist and clamp', () async {
      SharedPreferences.setMockInitialValues({});
      final s = SettingsController();
      await s.load();
      s.setTextScale(3);
      s.setFont(ReadingFont.lexend);
      s.setHighContrast(true);
      expect(s.textScale, 1.6);
      final again = SettingsController();
      await again.load();
      expect(again.font, ReadingFont.lexend);
      expect(again.highContrast, isTrue);
      again.resetAccessibility();
      expect(again.textScale, 1.0);
      expect(again.font, ReadingFont.standard);
    });

    testWidgets('switch and slider are exposed to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      var on = false;
      var v = 1.0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, set) => Column(children: [
              AppSwitch(value: on, label: 'High contrast', onChanged: (x) => set(() => on = x)),
              SizedBox(
                width: 200,
                child: AppSlider(value: v, min: 0.9, max: 1.6, step: 0.1, label: 'Text size', onChanged: (x) => set(() => v = x)),
              ),
            ]),
          ),
        ),
      ));
      expect(tester.getSemantics(find.byType(AppSwitch)), matchesSemantics(label: 'High contrast', hasToggledState: true,
          isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true, isFocusable: true, hasFocusAction: true));
      await tester.tap(find.byType(AppSwitch));
      await tester.pumpAndSettle();
      expect(on, isTrue);
      final slider = tester.getSemantics(find.byType(AppSlider));
      expect(slider.label, 'Text size');
      expect(slider.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
      handle.dispose();
    });
  });
}
