import '../l10n.dart';
import 'pinyin.dart';

/// Un mot du lexique HSK, tous niveaux confondus.
class Word {
  const Word({
    required this.id,
    required this.level,
    required this.hanzi,
    required this.pinyin,
    required this.posEn,
    required this.posFr,
    required this.en,
    required this.fr,
    required this.answers,
    required this.answersWithTones,
    this.meanings = const {},
    this.posMap = const {},
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    final pinyin = (json['pinyin'] as String?) ?? '';

    // Formes toniques, avec les variantes de 变调 (tons de liaison) tolérées.
    final toned = Pinyin.withSandhi(Pinyin.tonedForms(pinyin));

    // Formes atones : on retire les tons des formes toniques, et on ajoute les
    // graphies déjà atones fournies par le lexique (`nver`, `shei`, ...).
    final toneless = <String>{...Pinyin.tonelessForms(pinyin)};
    final rawAnswers =
        (json['answers'] as List?)?.cast<String>() ?? const <String>[];
    for (final a in rawAnswers) {
      final plain = normalizePinyin(a);
      if (plain.isNotEmpty) toneless.add(plain);
    }

    // Significations et natures grammaticales, langue par langue.
    final meanings = <String, String>{};
    final posMap = <String, String>{};
    for (final code in _langCodes) {
      final m = json[code] as String?;
      if (m != null && m.isNotEmpty) meanings[code] = m;
      final p = json['pos${code[0].toUpperCase()}${code.substring(1)}'] as String?;
      if (p != null && p.isNotEmpty) posMap[code] = p;
    }

    return Word(
      id: json['id'] as int,
      level: json['level'] as int,
      hanzi: json['hanzi'] as String,
      pinyin: pinyin,
      posEn: json['posEn'] as String? ?? '',
      posFr: json['posFr'] as String? ?? '',
      en: json['en'] as String? ?? '',
      fr: json['fr'] as String? ?? '',
      answers: toneless.toList(growable: false),
      answersWithTones: toned.toList(growable: false),
      meanings: meanings,
      posMap: posMap,
    );
  }

  final int id;
  final int level;
  final String hanzi;
  final String pinyin;
  final String posEn;
  final String posFr;
  final String en;
  final String fr;
  final List<String> answers;
  final List<String> answersWithTones;

  /// Signification par code de langue (`en`, `fr`, `es`, `ar`, …).
  final Map<String, String> meanings;

  /// Nature grammaticale par code de langue.
  final Map<String, String> posMap;

  bool get isLevelSevenNine => level >= 7;

  /// Retourne la nature grammaticale dans la langue demandée.
  String pos(AppLang lang) {
    if (isLevelSevenNine) return '';
    return posMap[lang.code] ??
        (lang == AppLang.fr ? posFr : posEn);
  }

  /// Retourne la signification dans la langue demandée, avec repli sur
  /// l'anglais puis le français quand la traduction manque.
  String meaning(AppLang lang) {
    if (isLevelSevenNine) return pinyin;
    return meanings[lang.code] ??
        (lang == AppLang.fr ? fr : en);
  }

  /// Vrai si la signification affiche directement le pinyin (niveaux 7-9).
  bool meaningIsPinyin(AppLang lang) => isLevelSevenNine;

  /// Vérifie si une saisie correspond au mot, avec ou sans tons.
  ///
  /// Avec tons, **les tons sont exigés** : `ai` est rejeté, `ai4` est accepté.
  ///
  /// Sinon les tons sont facultatifs : `ai`, `ài` et `ai4` passent tous.
  ///
  /// Dans les deux cas les accents, espaces, apostrophes et la casse sont
  /// ignorés, `ü` peut s'écrire `ü`, `v` ou `u:`, et les lectures multiples
  /// (`shéi`/`shuí`) sont toutes valables.
  bool accepts(String? input, {required bool withTones}) {
    if (input == null || input.trim().isEmpty) return false;

    if (withTones) {
      final typed = Pinyin.tonedForms(input);
      return typed.any(answersWithTones.contains);
    }

    // Mode sans ton : la saisie peut être accentuée ou non.
    final typed = Pinyin.tonelessForms(input);
    if (typed.any(answers.contains)) return true;
    // Filet de sécurité : une graphie non segmentable mais littéralement
    // identique à une réponse du lexique reste acceptée.
    final plain = normalizePinyin(input);
    return plain.isNotEmpty && answers.contains(plain);
  }
}

String normalizePinyin(String s) {
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (_isSeparator(ch)) continue;
    final base = _baseOf[ch] ?? ch.toLowerCase();
    final code = base.codeUnitAt(0);
    if ((code >= 0x61 && code <= 0x7a) || (code >= 0x30 && code <= 0x39)) {
      buffer.write(base);
    }
  }
  return buffer.toString();
}

/// Codes de langue pour lesquels une signification peut être fournie.
const List<String> _langCodes = ['en', 'fr', 'zh'];

bool _isSeparator(String ch) {
  switch (ch) {
    case ' ':
    case '\t':
    case '\'':
    case '’':
    case '`':
    case '"':
    case '-':
    case '–':
    case '—':
      return true;
    default:
      return false;
  }
}

const Map<String, String> _baseOf = {
  'ā': 'a',
  'á': 'a',
  'ǎ': 'a',
  'à': 'a',
  'ē': 'e',
  'é': 'e',
  'ě': 'e',
  'è': 'e',
  'ī': 'i',
  'í': 'i',
  'ǐ': 'i',
  'ì': 'i',
  'ō': 'o',
  'ó': 'o',
  'ǒ': 'o',
  'ò': 'o',
  'ū': 'u',
  'ú': 'u',
  'ǔ': 'u',
  'ù': 'u',
  'ü': 'u',
  'ǘ': 'u',
  'ǚ': 'u',
  'ǜ': 'u',
  'u:': 'u',
  'v': 'u',
  'a': 'a',
  'e': 'e',
  'i': 'i',
  'o': 'o',
  'u': 'u',
};
