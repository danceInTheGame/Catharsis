import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../l10n.dart';
import '../models/grammar_exercise.dart';
import '../models/grammar_rule.dart';
import '../models/word.dart';

/// Dépôt de grammaire : règles, exemples et exercices pré-calculés.
///
/// Deux fichiers embarqués :
///   * `grammar_rules.json` — 513 règles, leurs niveaux, sections, catégories,
///     explications, structures et exemples (traduits en anglais et en
///     chinois) ;
///   * `grammar_exercises.json` — 100 « mots manquants » et 100 « phrases
///     mélangées » par règle, rangés en tableaux d'entiers compacts.
///
/// Rien n'est généré au démarrage : les exercices sont fabriqués à la demande
/// pour la session, ce qui garde l'application fluide.
class GrammarRepository {
  GrammarRepository._();
  static final GrammarRepository instance = GrammarRepository._();

  final List<GrammarLevel> _levels = [];
  final Map<String, GrammarRule> _rules = {};
  final Map<String, Word> _vocabulary = {};
  final Map<String, Map<String, String>> _categoryNames = {};
  final Map<String, Map<String, String>> _exampleTranslations = {};

  Map<String, List<_Sentence>> _sentences = {};
  Map<String, List<String>> _tokenTable = {};
  Map<String, List<List<int>>> _fills = {};
  Map<String, List<List<int>>> _orders = {};

  bool _loaded = false;
  int _fillTotal = 0;
  int _orderTotal = 0;

  final Random _random = Random();

  bool get isLoaded => _loaded;
  int get fillTotal => _fillTotal;
  int get orderTotal => _orderTotal;

  int get ruleCount => _rules.length;

  List<GrammarLevel> get levels => List.unmodifiable(_levels);

  /// Niveaux disponibles pour le niveau HSK maximum choisi.
  List<GrammarLevel> levelsUpTo(int maxLevel) =>
      _levels.where((level) => level.appLevel <= maxLevel).toList();

  GrammarRule? rule(String id) => _rules[id];

  /// Nom traduit d'une catégorie (« Adverbes » → « Adverbs » / « 副词 »).
  String categoryName(String name, AppLang lang) {
    if (lang == AppLang.fr) return name;
    return _categoryNames[name]?[lang.code] ?? name;
  }

  Map<String, String> _rememberCategory(String name, Object? i18n) {
    final map = stringMap(i18n);
    if (name.isNotEmpty && map.isNotEmpty) _categoryNames[name] = map;
    return map;
  }

  Future<void> load(List<Word> words) async {
    if (_loaded) return;
    for (final word in words) {
      _vocabulary.putIfAbsent(word.hanzi, () => word);
    }

    final rawRules = jsonDecode(
      await rootBundle.loadString('assets/grammar_rules.json'),
    ) as Map<String, dynamic>;

    for (final level in rawRules['levels'] as List? ?? const []) {
      final map = (level as Map).cast<String, dynamic>();
      _levels.add(GrammarLevel(
        code: map['code'] as String? ?? '',
        appLevel: map['appLevel'] as int? ?? 1,
        title: map['title'] as String? ?? '',
        intro: ((map['intro'] as List?) ?? const [])
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList(),
        sections: [
          for (final section in map['sections'] as List? ?? const [])
            GrammarSection(
              name: (section as Map)['name'] as String? ?? '',
              categories: [
                for (final category in section['categories'] as List? ?? const [])
                  GrammarCategory(
                    name: (category as Map)['name'] as String? ?? '',
                    i18n: _rememberCategory(
                      category['name'] as String? ?? '',
                      category['nameI18n'],
                    ),
                    ruleIds: [
                      for (final rule in category['rules'] as List? ?? const [])
                        (rule as Map)['id'] as String,
                    ],
                  ),
              ],
            ),
        ],
      ));
    }

    for (final rule in rawRules['rules'] as List? ?? const []) {
      final parsed = GrammarRule.fromJson((rule as Map).cast<String, dynamic>());
      _rules[parsed.id] = parsed;
    }

    final rawExercises = jsonDecode(
      await rootBundle.loadString('assets/grammar_exercises.json'),
    ) as Map<String, dynamic>;

    final sentences = rawExercises['s'] as Map<String, dynamic>;
    final tokens = rawExercises['t'] as Map<String, dynamic>;
    _sentences = {
      for (final entry in sentences.entries)
        entry.key: [
          for (final item in entry.value as List)
            _Sentence.fromJson((item as Map).cast<String, dynamic>()),
        ],
    };
    _tokenTable = {
      for (final entry in tokens.entries)
        entry.key: [for (final token in entry.value as List) token.toString()],
    };
    _fills = {
      for (final entry in (rawExercises['m'] as Map<String, dynamic>).entries)
        entry.key: [
          for (final item in entry.value as List)
            [for (final value in item as List) value as int],
        ],
    };
    _orders = {
      for (final entry in (rawExercises['w'] as Map<String, dynamic>).entries)
        entry.key: [
          for (final item in entry.value as List)
            [for (final value in item as List) value as int],
        ],
    };

    _fillTotal = _fills.values.fold(0, (sum, list) => sum + list.length);
    _orderTotal = _orders.values.fold(0, (sum, list) => sum + list.length);
    _loaded = true;
  }

  int countFor(String ruleId, ExerciseType type) =>
      (type == ExerciseType.fill ? _fills[ruleId] : _orders[ruleId])?.length ?? 0;

  /// Construit une session d'exercices tirés au hasard.
  ///
  /// [onlyRule] limite la session à une règle (bouton « s'exercer » de la
  /// fiche) ; sinon on pioche dans tous les niveaux disponibles, **sans tenir
  /// compte de la difficulté**, comme demandé.
  ///
  /// Les tirages évitent les répétitions : une règle ne revient pas deux fois
  /// dans une session et deux exercices du même type ne s'enchaînent jamais
  /// plus de deux fois.
  List<GrammarExercise> buildSession({
    required int count,
    required int maxLevel,
    required AppLang lang,
    String? onlyRule,
  }) {
    final allowed = levelsUpTo(maxLevel).map((l) => l.appLevel).toSet();
    final pool = onlyRule != null
        ? [onlyRule]
        : [
            for (final rule in _rules.values)
              if (allowed.contains(rule.level) &&
                  countFor(rule.id, ExerciseType.fill) > 0 &&
                  countFor(rule.id, ExerciseType.mixed) > 0)
                rule.id,
          ];
    if (pool.isEmpty) return const [];

    final session = <GrammarExercise>[];
    final used = <String>{};
    final usedRules = <String>{};
    var previous = <ExerciseType>[];

    bool acceptable(ExerciseType type, String ruleId, String key) {
      if (used.contains(key)) return false;
      if (usedRules.contains(ruleId) && pool.length >= count) return false;
      if (previous.length >= 2 &&
          previous[previous.length - 1] == type &&
          previous[previous.length - 2] == type) {
        return false;
      }
      return true;
    }

    var guard = 0;
    while (session.length < count && guard < count * 400) {
      guard++;
      final type = _random.nextBool() ? ExerciseType.fill : ExerciseType.mixed;
      final ruleId = pool[_random.nextInt(pool.length)];
      final total = countFor(ruleId, type);
      if (total == 0) continue;
      final index = _random.nextInt(total);
      final key = '${type.key}:$ruleId:$index';
      if (!acceptable(type, ruleId, key)) continue;

      final exercise = build(ruleId, type, index, lang);
      if (exercise == null) continue;
      session.add(exercise);
      used.add(key);
      usedRules.add(ruleId);
      previous.add(type);
    }

    // Filet de sécurité quand le vivier est plus petit que la session.
    if (session.length < count) {
      for (final ruleId in pool) {
        if (session.length >= count) break;
        for (final type in ExerciseType.values) {
          final total = countFor(ruleId, type);
          for (var index = 0; index < total && session.length < count; index++) {
            final key = '${type.key}:$ruleId:$index';
            if (used.contains(key)) continue;
            final exercise = build(ruleId, type, index, lang);
            if (exercise == null) continue;
            session.add(exercise);
            used.add(key);
          }
        }
      }
    }
    return session;
  }

  /// Fabrique l'exercice [index] de la règle [ruleId].
  GrammarExercise? build(
    String ruleId,
    ExerciseType type,
    int index,
    AppLang lang,
  ) {
    final rule = _rules[ruleId];
    final tokens = _tokenTable[ruleId];
    final sentences = _sentences[ruleId];
    if (rule == null || tokens == null || sentences == null) return null;

    if (type == ExerciseType.fill) {
      final entries = _fills[ruleId];
      if (entries == null || index < 0 || index >= entries.length) return null;
      final entry = entries[index];
      final sentence = sentences[entry[0]];
      final blank = entry[1];
      if (blank < 0 || blank >= sentence.tokens.length) return null;
      final sentenceTokens = [for (final t in sentence.tokens) tokens[t]];
      final raw = sentenceTokens[blank];
      final core = _coreOf(raw);
      final suffix = raw.substring(core.length);

      final options = <String>[
        core,
        for (final token in entry.sublist(3)) tokens[token],
      ];
      options.shuffle(_random);

      final word = _vocabulary[core];
      return GrammarExercise(
        id: 'm:$ruleId:$index',
        type: type,
        rule: rule,
        tokens: sentenceTokens,
        pinyin: sentence.pinyin,
        translation: _translation(rule, sentence, lang),
        blankIndex: blank,
        options: options,
        answer: core,
        answerSuffix: suffix,
        // Pour un apprenant chinois, le sens du mot est le mot lui-même.
        hint: lang == AppLang.zh ? '' : (word?.meaning(lang) ?? ''),
        hintPinyin: word?.pinyin ?? '',
      );
    }

    final entries = _orders[ruleId];
    if (entries == null || index < 0 || index >= entries.length) return null;
    final entry = entries[index];
    final sentence = sentences[entry[0]];
    final sentenceTokens = [for (final t in sentence.tokens) tokens[t]];
    final order = entry.sublist(2);
    if (order.length != sentenceTokens.length) return null;
    return GrammarExercise(
      id: 'w:$ruleId:$index',
      type: type,
      rule: rule,
      tokens: sentenceTokens,
      shuffled: [for (final i in order) sentenceTokens[i]],
      pinyin: sentence.pinyin,
      translation: _translation(rule, sentence, lang),
    );
  }

  /// Traduction de la phrase d'exemple dans la langue de l'interface.
  String _translation(GrammarRule rule, _Sentence sentence, AppLang lang) {
    if (lang == AppLang.fr || sentence.french.isEmpty) return sentence.french;
    final key = '${rule.id}:${lang.code}';
    final table = _exampleTranslations.putIfAbsent(key, () {
      final map = <String, String>{};
      for (final example in rule.examples) {
        map[example.fr] = example.translationFor(lang.code);
      }
      return map;
    });
    return table[sentence.french] ?? sentence.french;
  }
}

/// Une phrase d'exemple, en indices de jetons.
class _Sentence {
  const _Sentence({
    required this.tokens,
    required this.pinyin,
    required this.french,
  });

  factory _Sentence.fromJson(Map<String, dynamic> json) => _Sentence(
        tokens: [for (final t in json['k'] as List? ?? const []) t as int],
        pinyin: json['y'] as String? ?? '',
        french: json['f'] as String? ?? '',
      );

  final List<int> tokens;
  final String pinyin;
  final String french;
}

const String _punctuation = '，。？！、；：,.?!;:…“”‘’「」『』《》〈〉（）()';

String _coreOf(String token) {
  var end = token.length;
  while (end > 0 && _punctuation.contains(token[end - 1])) {
    end--;
  }
  return token.substring(0, end);
}
