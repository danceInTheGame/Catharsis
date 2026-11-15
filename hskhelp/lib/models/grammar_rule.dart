/// Modèles de grammaire.
///
/// Le contenu est découpé en 5 niveaux (A1, A2, B1, B2, C1), chacun en
/// sections (*Catégories grammaticales*, *Structures grammaticales*,
/// *Comparaisons*), puis en catégories (Adverbes, Verbes, Particules…) et en
/// règles. Une règle est une suite de blocs — paragraphes, titres, structures
/// et exemples — affichés dans l'ordre.
library;

/// Un exemple : hanzi, pinyin, traduction française.
///
/// [hl] repère les caractères mis en rouge (le mot clé de la
/// règle) ; [frI18n] contient les traductions anglaise et chinoise.
class GrammarExample {
  const GrammarExample({
    required this.zh,
    required this.pinyin,
    required this.fr,
    this.hl = const [],
    this.frI18n = const {},
  });

  factory GrammarExample.fromJson(Map<String, dynamic> json) {
    final ranges = <List<int>>[];
    for (final range in json['hl'] as List? ?? const []) {
      if (range is List && range.length >= 2) {
        ranges.add([range[0] as int, range[1] as int]);
      }
    }
    return GrammarExample(
      zh: json['zh'] as String? ?? '',
      pinyin: json['py'] as String? ?? '',
      fr: json['fr'] as String? ?? '',
      hl: ranges,
      frI18n: stringMap(json['frI18n']),
    );
  }

  final String zh;
  final String pinyin;
  final String fr;
  final List<List<int>> hl;
  final Map<String, String> frI18n;

  /// Traduction dans la langue de l'interface, avec repli sur le français.
  String translationFor(String lang) => frI18n[lang] ?? fr;
}

/// Un bloc du corps d'une règle, dans l'ordre.
///
/// `type` vaut `p` (paragraphe), `h2` (titre de partie), `h3` (libellé
/// « Structure » / « Exemples »), `structure` ou `examples`.
class GrammarBlock {
  const GrammarBlock({
    required this.type,
    required this.fr,
    this.i18n = const {},
    this.items = const [],
  });

  factory GrammarBlock.fromJson(Map<String, dynamic> json) {
    final items = <GrammarExample>[];
    for (final item in json['items'] as List? ?? const []) {
      items.add(GrammarExample.fromJson((item as Map).cast<String, dynamic>()));
    }
    return GrammarBlock(
      type: json['t'] as String? ?? 'p',
      fr: json['fr'] as String? ?? '',
      i18n: stringMap(json['i18n']),
      items: items,
    );
  }

  final String type;
  final String fr;
  final Map<String, String> i18n;
  final List<GrammarExample> items;

  bool get isExamples => type == 'examples';

  String textFor(String lang) => i18n[lang] ?? fr;
}

/// Une règle de grammaire, avec son niveau et son classement.
class GrammarRule {
  const GrammarRule({
    required this.id,
    required this.title,
    required this.level,
    required this.levelCode,
    required this.section,
    required this.category,
    required this.blocks,
    this.titleI18n = const {},
  });

  factory GrammarRule.fromJson(Map<String, dynamic> json) {
    final blocks = <GrammarBlock>[];
    for (final block in json['blocks'] as List? ?? const []) {
      blocks.add(GrammarBlock.fromJson((block as Map).cast<String, dynamic>()));
    }
    return GrammarRule(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      level: json['level'] as int? ?? 1,
      levelCode: json['levelCode'] as String? ?? 'A1',
      section: json['section'] as String? ?? '',
      category: json['category'] as String? ?? '',
      blocks: blocks,
      titleI18n: stringMap(json['titleI18n']),
    );
  }

  final String id;
  final String title;
  final int level;
  final String levelCode;
  final String section;
  final String category;
  final List<GrammarBlock> blocks;
  final Map<String, String> titleI18n;

  String titleFor(String lang) => titleI18n[lang] ?? title;

  /// Tous les exemples de la règle, dans l'ordre.
  List<GrammarExample> get examples => [
        for (final block in blocks)
          if (block.isExamples) ...block.items,
      ];

  /// Les structures de la règle (« 受 + Verbe », …).
  List<String> structureFor(String lang) => [
        for (final block in blocks)
          if (block.type == 'structure') block.textFor(lang),
      ];

  /// Explication de la règle : les paragraphes, suivis des structures.
  ///
  /// Les libellés « Structure » / « Exemples » et les exemples eux-mêmes sont
  /// exclus : ils ont leur propre affichage.
  String explanationFor(String lang) {
    final parts = <String>[];
    for (final block in blocks) {
      if (block.fr.trim().isEmpty) continue;
      if (block.type == 'p' || block.type == 'h2') {
        parts.add(block.textFor(lang));
      }
    }
    final structures = structureFor(lang);
    if (structures.isNotEmpty) {
      parts.add(structures.join('\n'));
    }
    return parts.join('\n\n');
  }

  /// Explication en français, pour les exercices (langue de repli).
  String get explanationFr => explanationFor('fr');
}

/// Une catégorie (Adverbes, Verbes, Particules…) et ses règles.
class GrammarCategory {
  const GrammarCategory({
    required this.name,
    required this.ruleIds,
    this.i18n = const {},
  });

  final String name;
  final List<String> ruleIds;
  final Map<String, String> i18n;

  String nameFor(String lang) => i18n[lang] ?? name;
}

/// Une section : catégories grammaticales, structures, comparaisons.
class GrammarSection {
  const GrammarSection({required this.name, required this.categories});

  final String name;
  final List<GrammarCategory> categories;

  int get ruleCount =>
      categories.fold(0, (sum, category) => sum + category.ruleIds.length);
}

/// Un niveau de grammaire (A1 → HSK 1, …, C1 → HSK 5-6).
class GrammarLevel {
  const GrammarLevel({
    required this.code,
    required this.appLevel,
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String code;
  final int appLevel;
  final String title;
  final List<String> intro;
  final List<GrammarSection> sections;

  int get ruleCount =>
      sections.fold(0, (sum, section) => sum + section.ruleCount);

  /// Équivalence HSK affichée à côté du code (« HSK 1 », « HSK 5-6 »).
  String get hskLabel => switch (code) {
        'A1' => 'HSK 1',
        'A2' => 'HSK 2',
        'B1' => 'HSK 3',
        'B2' => 'HSK 4',
        'C1' => 'HSK 5-6',
        _ => '',
      };
}

/// Convertit une valeur JSON en table de chaînes (ignore les entrées vides).
Map<String, String> stringMap(Object? value) {
  if (value is! Map) return const {};
  final out = <String, String>{};
  value.forEach((k, v) {
    if (v is String && v.isNotEmpty) out[k.toString()] = v;
  });
  return out;
}
