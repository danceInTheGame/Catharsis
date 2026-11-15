import 'package:flutter/widgets.dart';

/// Langue de l'application : français, anglais ou chinois (mandarin).
///
/// Elle porte à la fois l'interface **et** les significations affichées à la
/// correction : on ne voit jamais de mélange de langues. Les dictionnaires
/// sont embarqués dans le binaire, l'application reste hors ligne.
enum AppLang { fr, en, zh }

extension AppLangX on AppLang {
  /// Code court persisté dans les préférences.
  String get code => name;

  static AppLang fromCode(String? code) => AppLang.values.firstWhere(
    (l) => l.name == code,
    orElse: () => AppLang.fr,
  );

  /// Nom natif de la langue, affiché dans les réglages.
  String get nativeName => switch (this) {
    AppLang.fr => 'Français',
    AppLang.en => 'English',
    AppLang.zh => '中文',
  };

  /// Nom de la langue en français.
  String get frName => switch (this) {
    AppLang.fr => 'Français',
    AppLang.en => 'Anglais',
    AppLang.zh => 'Chinois (mandarin)',
  };
}

/// Tous les textes de l'interface, dans les trois langues disponibles.
class Strings {
  const Strings(this.lang);

  final AppLang lang;

  /// Retourne la traduction dans [lang], avec repli sur l'anglais.
  String _t(String fr, String en, [String? zh]) {
    return switch (lang) {
      AppLang.fr => fr,
      AppLang.en => en,
      AppLang.zh => zh ?? en,
    };
  }

  // ------------------------------------------------------------------ accueil
  String get appTitle => 'HSK';

  /// Titre : le dernier niveau sélectionné (`HSK 3`, `HSK 7-9`).
  String levelTitle(int level) => 'HSK ${levelLabel(level)}';

  String levelLabel(int level) => level >= 7 ? '7-9' : '$level';

  String levelWord(int level) =>
      _t('niveau $level', 'level $level', '级别 $level');

  String homeSubtitle(int count, int level) {
    final one = count == 1;
    if (level >= 7) {
      return _t(
        one
            ? '1 mot, tous les niveaux, à la volée.'
            : 'Les $count mots de tous les niveaux, à la volée.',
        one
            ? '1 word across every level, at random.'
            : 'All $count words across every level, at random.',
        one ? '1 个词，所有级别，随机。' : '所有级别的 $count 个词，随机。',
      );
    }
    return _t(
      one
          ? '1 mot, niveaux 1 à $level, à la volée.'
          : 'Les $count mots des niveaux 1 à $level, à la volée.',
      one
          ? 'The 1 word of levels 1 to $level, at random.'
          : 'The $count words of levels 1 to $level, at random.',
      one ? '1 个词，级别 1 到 $level，随机。' : '级别 1 到 $level 的 $count 个词，随机。',
    );
  }

  String get wordsPerSession =>
      _t('Mots par session', 'Words per session', '每轮词数');

  String get allWords => _t('Tous', 'All', '全部');

  String get start => _t('Commencer', 'Start', '开始');

  String get settings => _t('Réglages', 'Settings', '设置');

  String get resetProgress =>
      _t('Réinitialiser la progression', 'Reset progress', '重置进度');

  String get resetTitle => _t('Réinitialiser ?', 'Reset?', '重置？');

  String get resetBody => _t(
    'Tes mots maîtrisés et toutes tes statistiques seront effacés.',
    'Your mastered words and all your statistics will be erased.',
    '你掌握的单词和所有统计数据将被清除。',
  );

  String get cancel => _t('Annuler', 'Cancel', '取消');

  String get erase => _t('Effacer', 'Erase', '清除');

  String get noWords =>
      _t('Aucun mot disponible.', 'No words available.', '没有可用的单词。');

  String get mastered => _t('Maîtrisés', 'Mastered', '已掌握');

  String outOf(int count) => _t('sur $count', 'of $count', '共 $count');

  String get accuracy => _t('Précision', 'Accuracy', '准确率');

  String answersCount(int n) =>
      _t('$n réponses', '$n answer${n == 1 ? '' : 's'}', '$n 个答案');

  String get streak => _t('Série', 'Streak', '连续');

  String bestRecord(int n) => _t('record $n', 'best $n', '纪录 $n');

  String get tipTones => _t(
    'Écris le pinyin avec ses tons, comme tu veux : par accent '
        '(« nǐhǎo »), par chiffre (« ni3hao3 ») ou sans espace. '
        'Si le ton est faux, la correction te le dira. Utilise le '
        'pavé de tons sous le champ pour saisir les accents.',
    'Type the pinyin however you like: with accents (« nǐhǎo »), '
        'with numbers (« ni3hao3 ») or without spaces. If the tone is '
        'wrong, the correction tells you. Use the tone pad below the '
        'field to enter the accents.',
    '随意输入拼音：带声调符号（「nǐhǎo」）、数字（「ni3hao3」）或不带空格。'
        '如果声调错误，批改会告诉你。使用输入框下方的声调键盘输入声调。',
  );

  String get tipNoTones => _t(
    'Écris le pinyin comme tu veux : les accents, les espaces et '
        'les tons sont ignorés (« ai » vaut « ài », « nver » vaut '
        '« nǚ’ér »). Tu peux aussi basculer ton clavier en saisie '
        'pinyin chinois, puis réactiver les tons ici.',
    'Type the pinyin however you like: accents, spaces and tones '
        'are ignored (« ai » matches « ài », « nver » matches '
        '« nǚ’ér »). You can also switch your keyboard to Chinese '
        'pinyin input, then turn the tones back on.',
    '随意输入拼音：重音符号、空格和声调均被忽略（「ai」等同「ài」，'
        '「nver」等同「nǚ\'ér」）。',
  );

  // ------------------------------------------------------------------ réglages
  String get settingsTitle => _t('Réglages', 'Settings', '设置');

  String get sectionPractice => _t('Exercice', 'Practice', '练习');

  String get sectionAppearance => _t('Apparence', 'Appearance', '外观');

  String get sectionLanguage => _t('Langue', 'Language', '语言');

  String get levelSection => _t('Niveau de HSK', 'HSK level', 'HSK 级别');

  String get levelHint => _t(
    'Le lexique va du niveau 1 jusqu’au niveau choisi.',
    'The vocabulary runs from level 1 up to the chosen level.',
    '词汇从 1 级到所选级别。',
  );

  String wordsCount(int n) =>
      _t('$n mots', '$n word${n == 1 ? '' : 's'}', '$n 个词');

  String get requireTones => _t('Exiger les tons', 'Require tones', '要求声调');

  String get tonesOn => _t(
    'Le ton fait partie de la réponse : mā, ma2, ma3…',
    'The tone is part of the answer: mā, ma2, ma3…',
    '声调是答案的一部分：mā、ma2、ma3…',
  );

  String get tonesOff => _t(
    'Seule la transcription compte, le ton est ignoré.',
    'Only the transcription counts; the tone is ignored.',
    '只看拼音，忽略声调。',
  );

  String get themeSection => _t('Thème', 'Theme', '主题');

  String get languageSection =>
      _t('Langue de l’application', 'App language', '应用语言');

  String get languageHint => _t(
    'L’interface et les significations sont dans cette langue.',
    'The interface and the meanings use this language.',
    '界面和释义使用此语言。',
  );

  // --------------------------------------------------------------------- quiz
  String get typePinyinFirst => _t(
    'Écris d’abord le pinyin du mot.',
    'Type the pinyin of the word first.',
    '请先输入单词的拼音。',
  );

  String get leaveSession =>
      _t('Quitter la session', 'Leave the session', '退出练习');

  String wordOn(int index, int total) => _t(
    'mot $index sur $total',
    'word $index of $total',
    '第 $index / $total 个词',
  );

  String wordNumber(int id) => _t('n° $id', 'no. $id', '第 $id 号');

  String get whatPinyin =>
      _t('Quel est le pinyin ?', 'What is the pinyin?', '拼音是什么？');

  String get pinyinLabel => 'Pinyin';

  String pinyinHint(bool withTones) =>
      withTones ? 'ai4, nǐ hǎo, nu3er2…' : 'ai, ni hao, nǐ hǎo…';

  String hintLetter(String letter) => _t(
    'Indice : le pinyin commence par « $letter » (l’indice compte comme une aide)',
    'Hint: the pinyin starts with “$letter” (the hint counts as help)',
    '提示：拼音以「$letter」开头（提示算作帮助）',
  );

  String get hint => _t('Indice', 'Hint', '提示');

  String get check => _t('Valider', 'Check', '检查');

  String get dontKnow => _t('Je ne sais pas', 'I don’t know', '我不知道');

  String get correctAnswer => _t('Bonne réponse !', 'Correct!', '答对了！');

  /// Verdict affiché quand on a demandé la réponse (« Je ne sais pas »).
  String get revealAnswer =>
      _t('La bonne réponse', 'The correct answer', '正确答案');

  String get notQuite => _t('Pas tout à fait…', 'Not quite…', '不完全正确…');

  String get toneWrong => _t(
    'Les lettres sont justes, c’est le ton qui est faux.',
    'The letters are right, the tone is wrong.',
    '字母正确，声调错误。',
  );

  String yourAnswer(String answer) =>
      _t('Ta réponse : $answer', 'Your answer: $answer', '你的答案：$answer');

  String get pinyinIs => _t('Pinyin : ', 'Pinyin: ', '拼音：');

  String get nextWord => _t('Mot suivant', 'Next word', '下一个词');

  String get seeResult => _t('Voir le résultat', 'See the result', '查看结果');

  String get meaningLabel => _t('SIGNIFICATION', 'MEANING', '释义');

  // ------------------------------------------------------------------ bilan
  String get flawless => _t('Sans faute !', 'Flawless!', '全部正确！');

  String get sessionDone => _t('Session terminée', 'Session finished', '练习结束');

  String percentCorrect(int percent) =>
      _t('$percent % de bonnes réponses', '$percent % correct', '$percent% 正确');

  String get score => 'Score';

  String get record => _t('Record', 'Best', '纪录');

  String get again => _t('Refaire une session', 'Do another session', '再练一轮');

  String get backHome => _t('Retour à l’accueil', 'Back to home', '返回首页');

  // ----------------------------------------------------------------- grammaire
  String get grammar => _t('Grammaire', 'Grammar', '语法');

  String get vocabulary => _t('Vocabulaire', 'Vocabulary', '词汇');

  String get grammarLessons => _t('Leçons', 'Lessons', '课程');

  String get grammarLessonsSubtitle => _t(
    'Règles de grammaire par niveau',
    'Grammar rules by level',
    '按级别的语法规则',
  );

  String get grammarExercises => _t('Exercices', 'Exercises', '练习');

  String get grammarExercisesSubtitle =>
      _t('Entraînement aléatoire', 'Random practice', '随机训练');

  String get mixedPhrase => _t('Phrase mélangée', 'Mixed sentence', '排列句子');

  String get missingWord => _t('Mot manquant', 'Missing word', '填空');

  String get arrangeWords =>
      _t('Remets les mots dans l’ordre', 'Put the words in order', '将词语排列成句');

  String get typeMissingWord =>
      _t('Quel mot manque ?', 'Which word is missing?', '缺少哪个词？');

  String get ruleTitle => _t('Règle de grammaire', 'Grammar rule', '语法规则');

  String get nextExercise => _t('Exercice suivant', 'Next exercise', '下一题');

  String get exerciseProgress => _t('Exercice', 'Exercise', '第');

  String get exerciseDone => _t('Session terminée', 'Session finished', '练习完成');

  String get grammarNotAvailable => _t(
    'Pas de grammaire pour les niveaux 7-9.',
    'No grammar for levels 7-9.',
    '7-9 级没有语法内容。',
  );

  String get loading => _t('Chargement…', 'Loading…', '加载中…');

  String get loadError => _t(
    'Impossible de charger le lexique.',
    'Unable to load the vocabulary.',
    '无法加载词汇。',
  );

  // ------------------------------------------------- grammaire : navigation
  String get grammarLevelsTitle =>
      _t('Niveaux de grammaire', 'Grammar levels', '语法级别');

  String get grammarLevelsSubtitle => _t(
    'Les règles avec leurs exemples.',
    'The rules with their examples.',
    '语法规则及其例句。',
  );

  String grammarLevelTitle(String code) => _t(
    'Grammaire chinoise niveau $code',
    'Chinese grammar — level $code',
    '汉语语法 $code 级',
  );

  String get sectionGrammarCategories =>
      _t('Catégories grammaticales', 'Grammar categories', '语法类别');

  String get sectionGrammarStructures =>
      _t('Structures grammaticales', 'Grammar structures', '语法结构');

  String get sectionGrammarComparisons =>
      _t('Comparaisons', 'Comparisons', '比较');

  String get rulesCount => _t('règles', 'rules', '条规则');

  String get exercisesCount => _t('exercices', 'exercises', '道练习');

  String get sectionsLabel => _t('sections', 'sections', '部分');

  String rulesCountLabel(int n) => _t('$n règles', '$n rules', '$n 条规则');

  String get structureLabel => _t('Structure', 'Structure', '结构');

  String get examplesLabel => _t('Exemples', 'Examples', '例句');

  String get practiceThisRule =>
      _t('S’exercer sur cette règle', 'Practice this rule', '练习此规则');

  String get practiceAllRules =>
      _t('Exercices de grammaire', 'Grammar exercises', '语法练习');

  String get practiceAllRulesHint => _t(
    'Un tirage aléatoire parmi toutes les règles et les types d’exercices.',
    'A random draw across every rule and exercise types.',
    '从所有规则和两种练习中随机抽取。',
  );

  String get chooseAnswer =>
      _t('Choisis le mot qui manque.', 'Choose the missing word.', '选择缺少的词。');

  String get tapToBuild => _t(
    'Touche les morceaux dans le bon ordre.',
    'Tap the pieces in the right order.',
    '按正确顺序点击词语。',
  );

  String get verify => _t('Vérifier', 'Check', '检查');

  String get clearPieces => _t('Tout retirer', 'Clear all', '清空');

  String get showAnswer => _t('Voir la réponse', 'Show the answer', '显示答案');

  String get incompleteOrder => _t(
    'Il reste des morceaux à placer.',
    'Some pieces are still left.',
    '还有词语没有放置。',
  );

  String get wrongOrder => _t(
    'Ce n’est pas l’ordre. Reprends un morceau et essaie autrement.',
    'That is not the order. Take a piece back and try again.',
    '顺序不对。取回一个词语再试一次。',
  );

  String get correctWord => _t('C’est juste.', 'That’s right.', '答对了。');

  String get wrongWord =>
      _t('Ce n’était pas celui-là.', 'That wasn’t the one.', '不是这个。');

  String get theAnswer => _t('La bonne réponse', 'The correct answer', '正确答案');

  String get theRule => _t('La règle', 'The rule', '规则');

  String get fullRule =>
      _t('Voir la règle complète', 'See the full rule', '查看完整规则');

  String get explanation => _t('Explication', 'Explanation', '说明');

  String get translationLabel => _t('Traduction', 'Translation', '翻译');

  String get mixedPhraseDone => _t(
    'Phrase remise dans l’ordre.',
    'Sentence put back in order.',
    '句子已排好。',
  );

  String get exerciseRuleFrom => _t('Règle', 'Rule', '规则');

  String get grammarEmpty =>
      _t('Aucune règle pour ce niveau.', 'No rule for this level.', '此级别没有规则。');

  String sessionScore(int correct, int total) => _t(
    '$correct bonnes réponses sur $total',
    '$correct correct out of $total',
    '$total 题中答对 $correct 题',
  );

  String get nextSession => _t('Nouvelle session', 'New session', '新一轮');
}

/// Fournit les [Strings] à tous les écrans, y compris ceux qui sont poussés
/// dans le navigateur.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.strings, required super.child});

  final Strings strings;

  static Strings of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.strings;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.strings.lang != strings.lang;
}
