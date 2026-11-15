import '../models/grammar_rule.dart';

/// Type d'exercice de grammaire.
enum ExerciseType { fill, mixed }

extension ExerciseTypeX on ExerciseType {
  /// Identifiant stable utilisé dans les données et la progression.
  String get key => this == ExerciseType.fill ? 'm' : 'w';
}

/// Un exercice prêt à afficher, fabriqué à partir des données de grammaire.
///
/// * [ExerciseType.fill] — « mot manquant » : une phrase avec un trou,
///   quatre propositions, un indice (le sens du mot) ;
/// * [ExerciseType.mixed] — « phrase mélangée » : les morceaux de la phrase
///   dans le désordre, à remettre dans l'ordre.
class GrammarExercise {
  const GrammarExercise({
    required this.id,
    required this.type,
    required this.rule,
    required this.tokens,
    required this.pinyin,
    required this.translation,
    this.shuffled = const [],
    this.blankIndex = -1,
    this.options = const [],
    this.answer = '',
    this.answerSuffix = '',
    this.hint = '',
    this.hintPinyin = '',
  });

  final String id;
  final ExerciseType type;
  final GrammarRule rule;

  /// Jetons de la phrase dans l'ordre correct (ponctuation incluse).
  final List<String> tokens;

  /// Pinyin de la phrase entière.
  final String pinyin;

  /// Traduction de la phrase dans la langue de l'interface.
  final String translation;

  /// « Phrase mélangée » : les jetons dans l'ordre de départ (mélangé).
  final List<String> shuffled;

  /// « Mot manquant » : position du trou dans [tokens].
  final int blankIndex;

  /// « Mot manquant » : quatre propositions (la bonne incluse).
  final List<String> options;

  /// « Mot manquant » : le mot à retrouver, sans la ponctuation finale.
  final String answer;

  /// Ponctuation qui suit le mot caché (« 。 », « ？ », …).
  final String answerSuffix;

  /// Sens du mot caché, si le lexique le connaît.
  final String hint;

  /// Pinyin du mot caché, si le lexique le connaît.
  final String hintPinyin;

  /// Phrase correcte, recollée.
  String get sentence => tokens.join(' ');

  /// Jeton affiché à la place du trou (le mot caché + sa ponctuation).
  String get blankSuffix => answerSuffix;
}
