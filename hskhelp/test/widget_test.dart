import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hskhelp/data/deck.dart';
import 'package:hskhelp/l10n.dart';
import 'package:hskhelp/models/grammar_exercise.dart';
import 'package:hskhelp/models/word.dart';
import 'package:hskhelp/screens/grammar_exercise_screen.dart';
import 'package:hskhelp/screens/home_screen.dart';
import 'package:hskhelp/screens/quiz_screen.dart';
import 'package:hskhelp/screens/settings_screen.dart';
import 'package:hskhelp/services/grammar_repository.dart';
import 'package:hskhelp/services/learning_engine.dart';
import 'package:hskhelp/services/stats_service.dart';
import 'package:hskhelp/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<dynamic> _loadVocab() {
  final path = '${Directory.current.path}/assets/vocab.json';
  return jsonDecode(File(path).readAsStringSync()) as List<dynamic>;
}

void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() => tester.view.reset());
}

Widget app(StatsService stats, Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(stats.palette),
    builder: (context, child) => AppScope(
      strings: Strings(stats.lang),
      child: child ?? const SizedBox(),
    ),
    home: home,
  );
}

const quizWord = Word(
  id: 1,
  level: 1,
  hanzi: '爱',
  pinyin: 'ài',
  posEn: 'verb',
  posFr: 'verbe',
  en: 'to love',
  fr: 'aimer',
  answers: ['ai'],
  answersWithTones: ['ai4'],
);

const _sampleWords = [
  quizWord,
  Word(
    id: 2,
    level: 1,
    hanzi: '爸爸',
    pinyin: 'bàba',
    posEn: 'noun',
    posFr: 'nom',
    en: 'father',
    fr: 'père',
    answers: ['baba'],
    answersWithTones: ['ba4ba5'],
  ),
  Word(
    id: 3,
    level: 2,
    hanzi: '报纸',
    pinyin: 'bàozhǐ',
    posEn: 'noun',
    posFr: 'nom',
    en: 'newspaper',
    fr: 'journal',
    answers: ['baozhi'],
    answersWithTones: ['bao4zhi3'],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────── pinyin (unitaire)
  test('mode sans ton : accents, espaces et casse ignorés', () {
    const ai = Word(
      id: 1,
      level: 1,
      hanzi: '爱',
      pinyin: 'ài',
      posEn: 'verb',
      posFr: 'verbe',
      en: 'to love',
      fr: 'aimer',
      answers: ['ai'],
      answersWithTones: ['ai4'],
    );
    expect(ai.accepts('ai', withTones: false), isTrue);
    expect(ai.accepts('Ài', withTones: false), isTrue);
    expect(ai.accepts(' ai ', withTones: false), isTrue);
    expect(ai.accepts('a i', withTones: false), isTrue);
    expect(ai.accepts('', withTones: false), isFalse);
    expect(ai.accepts(null, withTones: false), isFalse);
    expect(ai.accepts('an', withTones: false), isFalse);
  });

  test('mode ton : le bon ton exigé, les graphies équivalentes acceptées', () {
    const ai = Word(
      id: 1,
      level: 1,
      hanzi: '爱',
      pinyin: 'ài',
      posEn: 'verb',
      posFr: 'verbe',
      en: 'to love',
      fr: 'aimer',
      answers: ['ai'],
      answersWithTones: ['ai4'],
    );
    expect(ai.accepts('ài', withTones: true), isTrue);
    expect(ai.accepts('ai4', withTones: true), isTrue);
    expect(ai.accepts('ÀI4', withTones: true), isTrue);
    expect(ai.accepts('a i 4', withTones: true), isTrue);
    expect(ai.accepts('ai', withTones: true), isFalse);
    expect(ai.accepts('āi', withTones: true), isFalse);
    expect(ai.accepts('ai3', withTones: true), isFalse);
  });

  test('ton neutre : pas d’accent attendu', () {
    const ma = Word(
      id: 100,
      level: 1,
      hanzi: '吗',
      pinyin: 'ma',
      posEn: 'particle',
      posFr: 'particule',
      en: 'question particle',
      fr: 'particule interrogative',
      answers: ['ma'],
      answersWithTones: ['ma5'],
    );
    expect(ma.accepts('ma', withTones: true), isTrue);
    expect(ma.accepts('ma5', withTones: true), isTrue);
    expect(ma.accepts('mā', withTones: true), isFalse);
  });

  test('ü accepté noté v, u ou u: (mode sans ton)', () {
    final nv = Word(
      id: 153,
      level: 1,
      hanzi: '女儿',
      pinyin: 'nǚ’ér',
      posEn: 'noun',
      posFr: 'nom',
      en: 'daughter',
      fr: 'fille',
      answers: ['nuer'],
      answersWithTones: ['nu3er2'],
    );
    expect(nv.pinyin, 'nǚ’ér');
    for (final input in ['nüer', 'nver', "nu'er", 'nue r', 'NU:ER', 'Nǚ’Ér']) {
      expect(nv.accepts(input, withTones: false), isTrue, reason: input);
    }
    for (final input in ['nǚ’ér', 'nu3er2', 'nv3er2', 'NU3 ER2']) {
      expect(nv.accepts(input, withTones: true), isTrue, reason: input);
    }
    expect(nv.accepts('nu2er2', withTones: true), isFalse);
  });

  test('lexique : chaque mot accepte sa propre transcription', () {
    final raw = _loadVocab();
    final failures = <String>[];
    for (final entry in raw.cast<Map<String, dynamic>>()) {
      final word = Word.fromJson(entry);
      if (word.answersWithTones.isEmpty) {
        failures.add('${word.hanzi} ${word.pinyin} : aucune forme tonique');
        continue;
      }
      if (word.answers.isEmpty) {
        failures.add('${word.hanzi} ${word.pinyin} : aucune forme atone');
        continue;
      }
      if (!word.accepts(word.pinyin, withTones: true)) {
        failures.add('${word.hanzi} ${word.pinyin} : rejetée en mode ton');
      }
      if (!word.accepts(word.pinyin, withTones: false)) {
        failures.add('${word.hanzi} ${word.pinyin} : rejetée sans ton');
      }
      for (final a in (entry['answers'] as List).cast<String>()) {
        if (!word.accepts(a, withTones: false)) {
          failures.add('${word.hanzi} : graphie « $a » rejetée sans ton');
        }
      }
    }
    expect(failures, isEmpty, reason: failures.take(5).join('\n'));
  });

  test('lexique : toute transcription au ton faux est refusée', () {
    final raw = _loadVocab();
    final failures = <String>[];
    var acceptedForms = 0;
    var mutatedForms = 0;

    for (final entry in raw.cast<Map<String, dynamic>>()) {
      final word = Word.fromJson(entry);
      final valid = word.answersWithTones.toSet();

      for (final form in valid) {
        acceptedForms++;
        if (!word.accepts(form, withTones: true)) {
          failures.add('${word.hanzi} ${word.pinyin} : « $form » rejetée');
        }
      }

      for (final form in valid) {
        final chars = form.split('');
        for (var i = 0; i < chars.length; i++) {
          final c = chars[i];
          final code = c.codeUnitAt(0);
          if (code < 0x30 || code > 0x39) continue;
          for (final other in ['1', '2', '3', '4']) {
            if (other == c) continue;
            final mutated = (List.of(chars)..[i] = other).join();
            if (valid.contains(mutated)) continue;
            mutatedForms++;
            if (word.accepts(mutated, withTones: true)) {
              failures.add(
                '${word.hanzi} ${word.pinyin} : « $mutated » acceptée à tort '
                '(valides : ${valid.join(', ')})',
              );
            }
          }
        }
      }
    }

    expect(failures, isEmpty, reason: failures.take(8).join('\n'));
    expect(acceptedForms, greaterThan(11000));
    expect(mutatedForms, greaterThan(15000));
  });

  // ─────────────────────────────────────────── deck / vocabulaire
  test('selectWords filtre par niveau cumulatif', () {
    final words = _sampleWords;
    expect(selectWords(words, 1).length, 2);
    expect(selectWords(words, 2).length, 3);
    expect(selectWords(words, 7).length, 3);
  });

  test('buildDeck place les mots non maîtrisés en premier', () {
    final deck = buildDeck(
      _sampleWords,
      masteredIds: {1},
      size: 10,
    );
    // Tous les mots restent disponibles (les acquis servent de rappel),
    // mais le mot maîtrisé est relégué en fin de paquet.
    expect(deck.length, 3);
    expect(deck.last.id, 1);
  });

  // ────────────────────────────────────── moteur d'apprentissage
  test('moteur d’apprentissage : progression et sélection', () {
    final engine = LearningEngine.instance;
    engine.recordAnswer('test:item1', 1.0);
    engine.recordAnswer('test:item1', 1.0);
    engine.recordAnswer('test:item2', 0.0);

    final s1 = engine.stateFor('test:item1');
    final s2 = engine.stateFor('test:item2');
    expect(s1.attempts, 2);
    expect(s1.correct, 2);
    expect(s1.streak, 2);
    expect(s2.attempts, 1);
    expect(s2.wrongStreak, 1);

    // L'item raté doit être prioritaire sur l'item réussi.
    final chosen = engine.selectBest(['test:item1', 'test:item2']);
    expect(chosen, 'test:item2');
  });

  test('moteur d’apprentissage : formule SM-2 augmente l’intervalle', () {
    final engine = LearningEngine.instance;
    engine.recordAnswer('sm2:a', 1.0);
    final first = engine.stateFor('sm2:a').interval;
    engine.recordAnswer('sm2:a', 1.0);
    final second = engine.stateFor('sm2:a').interval;
    expect(first, 1);
    expect(second, 6);
    engine.recordAnswer('sm2:a', 0.0);
    expect(engine.stateFor('sm2:a').interval, 0);
  });

  // ────────────────────────────────────────────── grammaire
  test('dépôt de grammaire : charge les règles et fabrique une session', () async {
    final repo = GrammarRepository.instance;
    await repo.load(_sampleWords);

    expect(repo.ruleCount, 513);
    expect(repo.levels.map((l) => l.code).toList(), ['A1', 'A2', 'B1', 'B2', 'C1']);
    expect(repo.levels.first.ruleCount, greaterThan(0));
    expect(repo.levelsUpTo(2).map((l) => l.code).toList(), ['A1', 'A2']);

    final session = repo.buildSession(count: 12, maxLevel: 5, lang: AppLang.fr);
    expect(session, hasLength(12));
    // Aucune règle ne revient dans la même session.
    expect(session.map((e) => e.rule.id).toSet(), hasLength(12));
    // Jamais trois exercices du même type d'affilée.
    for (var i = 2; i < session.length; i++) {
      final three = session[i].type == session[i - 1].type &&
          session[i].type == session[i - 2].type;
      expect(three, isFalse, reason: 'trois ${session[i].type.name} d’affilée');
    }
  });

  test('grammaire : les deux types d’exercices sont tirés au hasard', () async {
    final repo = GrammarRepository.instance;
    await repo.load(_sampleWords);
    final session = repo.buildSession(count: 40, maxLevel: 5, lang: AppLang.fr);
    expect(session.any((e) => e.type == ExerciseType.fill), isTrue);
    expect(session.any((e) => e.type == ExerciseType.mixed), isTrue);
    // La session ignore la difficulté : plusieurs niveaux sont représentés.
    expect(session.map((e) => e.rule.level).toSet().length, greaterThan(2));
  });

  test('grammaire : un mot manquant cache un mot et propose quatre choix',
      () async {
    final repo = GrammarRepository.instance;
    await repo.load(_sampleWords);
    final session = repo.buildSession(count: 60, maxLevel: 5, lang: AppLang.fr);
    final fills = session.where((e) => e.type == ExerciseType.fill).toList();
    expect(fills, isNotEmpty);
    for (final fill in fills) {
      expect(fill.options, hasLength(4));
      expect(fill.options.toSet(), hasLength(4));
      expect(fill.options, contains(fill.answer));
      expect(fill.blankIndex, inInclusiveRange(0, fill.tokens.length - 1));
      expect(fill.tokens[fill.blankIndex], startsWith(fill.answer));
      expect(fill.answer, isNotEmpty);
    }
  });

  test('grammaire : une phrase mélangée n’est pas déjà dans l’ordre',
      () async {
    final repo = GrammarRepository.instance;
    await repo.load(_sampleWords);
    final session = repo.buildSession(count: 60, maxLevel: 5, lang: AppLang.fr);
    final mixed = session.where((e) => e.type == ExerciseType.mixed).toList();
    expect(mixed, isNotEmpty);
    for (final exercise in mixed) {
      expect(exercise.shuffled, hasLength(exercise.tokens.length));
      expect(listEquals(exercise.shuffled, exercise.tokens), isFalse);
      final a = [...exercise.shuffled]..sort();
      final b = [...exercise.tokens]..sort();
      expect(a, b, reason: 'les jetons doivent être les mêmes');
    }
  });

  test('grammaire : les règles portent leurs textes', () async {
    final repo = GrammarRepository.instance;
    await repo.load(_sampleWords);
    final rule = repo.levels.first.sections.first.categories.first.ruleIds.first;
    final parsed = repo.rule(rule)!;
    expect(parsed.title, isNotEmpty);
    expect(parsed.category, isNotEmpty);
    expect(parsed.blocks, isNotEmpty);
    expect(parsed.examples, isNotEmpty);
    expect(parsed.explanationFor('fr'), isNotEmpty);
    expect(parsed.titleFor('fr'), parsed.title);
  });

  // ────────────────────────────────────────────── interface
  testWidgets('accueil : bascule vocabulaire/grammaire visible',
      (tester) async {
    usePhoneSize(tester);
    final stats = await StatsService.load();
    await tester.pumpWidget(app(stats, HomeScreen(
      words: _sampleWords,
      stats: stats,
    )));
    await tester.pump();

    final s = Strings(stats.lang);
    expect(find.text(s.vocabulary), findsOneWidget);
    expect(find.text(s.grammar), findsOneWidget);
  });

  testWidgets('accueil : la bascule grammaire montre les niveaux',
      (tester) async {
    usePhoneSize(tester);
    final stats = await StatsService.load();
    await tester.pumpWidget(app(stats, HomeScreen(
      words: _sampleWords,
      stats: stats,
    )));
    await tester.pump();

    final s = Strings(stats.lang);
    await tester.tap(find.text(s.grammar));
    await tester.pump();
    // Laisse charger le contenu de la grammaire.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.text(s.practiceAllRules), findsOneWidget);
    expect(find.text(s.grammarLevelTitle('A1')), findsOneWidget);
  });

  testWidgets('réglages : les trois langues sont proposées', (tester) async {
    usePhoneSize(tester);
    tester.view.physicalSize = const Size(390, 1600);
    final stats = await StatsService.load();
    await tester.pumpWidget(app(stats, SettingsScreen(
      stats: stats,
      words: _sampleWords,
    )));
    await tester.pump();

    expect(AppLang.values, [AppLang.fr, AppLang.en, AppLang.zh]);
    for (final l in AppLang.values) {
      await tester.ensureVisible(find.text(l.nativeName));
      await tester.pump();
      expect(find.text(l.nativeName), findsOneWidget,
          reason: 'langue ${l.name} absente');
    }
  });

  testWidgets('réglages : changer la langue reconstruit l’interface',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.reset());
    SharedPreferences.setMockInitialValues({});
    final stats = await StatsService.load();
    await tester.pumpWidget(app(stats, SettingsScreen(
      stats: stats,
      words: _sampleWords,
    )));
    await tester.pump();

    await tester.ensureVisible(find.text('English'));
    await tester.pump();
    await tester.tap(find.text('English'));
    await tester.pump();
    expect(stats.lang, AppLang.en);

    await tester.ensureVisible(find.text('中文'));
    await tester.pump();
    await tester.tap(find.text('中文'));
    await tester.pump();
    expect(stats.lang, AppLang.zh);
  });

  testWidgets('quiz : « Je ne sais pas » révèle la bonne réponse',
      (tester) async {
    usePhoneSize(tester);
    final stats = await StatsService.load();
    final deck = [quizWord];
    await tester.pumpWidget(app(
      stats,
      QuizScreen(
        words: deck,
        deck: deck,
        stats: stats,
        sessionSize: 1,
      ),
    ));
    await tester.pump();

    final s = Strings(stats.lang);
    expect(find.text(s.dontKnow), findsOneWidget);
    await tester.tap(find.text(s.dontKnow));
    await tester.pump();

    // La bonne réponse est montrée, jamais « Pas tout à fait ».
    expect(find.text(s.revealAnswer), findsOneWidget);
    expect(find.text(s.notQuite), findsNothing);
  });

  testWidgets('quiz : une bonne réponse affiche « Bonne réponse ! »',
      (tester) async {
    usePhoneSize(tester);
    final stats = await StatsService.load();
    final deck = [quizWord];
    await tester.pumpWidget(app(
      stats,
      QuizScreen(
        words: deck,
        deck: deck,
        stats: stats,
        sessionSize: 1,
      ),
    ));
    await tester.pump();

    final s = Strings(stats.lang);
    await tester.enterText(find.byType(TextField), 'ài');
    await tester.pump();
    await tester.tap(find.text(s.check));
    await tester.pump();

    expect(find.text(s.correctAnswer), findsOneWidget);
  });

  // ────────────────────────────────────── exercices de grammaire
  Future<void> pumpExercise(
    WidgetTester tester,
    List<GrammarExercise> session,
  ) async {
    usePhoneSize(tester);
    final stats = await StatsService.load();
    await tester.pumpWidget(app(
      stats,
      GrammarExerciseScreen(maxLevel: 5, session: session),
    ));
    await tester.pump();
  }

  testWidgets('grammaire : choisir le bon mot est félicité et montre la règle',
      (tester) async {
    final repo = GrammarRepository.instance;
    await repo.load(_sampleWords);
    final fill = repo.build('ASG6509E', ExerciseType.fill, 0, AppLang.fr)!;
    await pumpExercise(tester, [fill]);
    final s = Strings(AppLang.fr);

    expect(find.text(s.chooseAnswer), findsOneWidget);
    await tester.tap(find.text(fill.answer));
    await tester.pump();

    expect(find.text(s.correctWord), findsOneWidget);
    expect(find.text(s.theRule.toUpperCase()), findsOneWidget);
    expect(find.text(fill.sentence), findsOneWidget);
  });

  testWidgets('grammaire : un mauvais choix montre la réponse et la règle',
      (tester) async {
    final repo = GrammarRepository.instance;
    await repo.load(_sampleWords);
    final fill = repo.build('ASG6509E', ExerciseType.fill, 0, AppLang.fr)!;
    await pumpExercise(tester, [fill]);
    final s = Strings(AppLang.fr);

    final wrong = fill.options.firstWhere((o) => o != fill.answer);
    await tester.tap(find.text(wrong));
    await tester.pump();

    expect(find.text(s.wrongWord), findsOneWidget);
    expect(find.text(s.theRule.toUpperCase()), findsOneWidget);
    expect(find.textContaining(fill.answer), findsWidgets);
  });

  testWidgets('grammaire : une phrase mélangée peut révéler sa réponse',
      (tester) async {
    final repo = GrammarRepository.instance;
    await repo.load(_sampleWords);
    final mixed = repo.build('ASG6509E', ExerciseType.mixed, 0, AppLang.fr)!;
    await pumpExercise(tester, [mixed]);
    final s = Strings(AppLang.fr);

    expect(find.text(s.arrangeWords), findsOneWidget);
    await tester.tap(find.byTooltip(s.showAnswer));
    await tester.pump();

    expect(find.text(s.theRule.toUpperCase()), findsOneWidget);
  });
}
