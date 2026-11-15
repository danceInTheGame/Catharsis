import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Une palette de couleurs complète : fond, cartes, texte, accents.
///
/// Chaque palette définit douze couleurs « sources » ; les teintes dérivées
/// (fonds subtils, couleurs de texte sur bouton) sont calculées à la
/// construction pour rester cohérentes d'une palette à l'autre.
class Palette {
  Palette({
    required this.id,
    required this.nameFr,
    required this.nameEn,
    this.nameZh = '',
    required this.dark,
    required this.paper,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.success,
    required this.danger,
    required this.sand,
  })  : paperDeep = Color.lerp(paper, ink, .07)!,
        sandSoft = Color.lerp(sand, card, .5)!,
        correctSoft = Color.lerp(success, card, .13)!,
        dangerSoft = Color.lerp(danger, card, .12)!,
        onAccent = contrastOn(accent),
        onSuccess = contrastOn(success),
        onError = contrastOn(danger);

  /// Identifiant persisté dans les préférences.
  final String id;
  final String nameFr;
  final String nameEn;
  final String nameZh;
  final bool dark;

  /// Fond d'écran le plus clair (ou le plus sombre).
  final Color paper;

  /// Fond des cartes et des champs de saisie.
  final Color card;

  /// Couleur du texte principal.
  final Color ink;

  /// Couleur du texte secondaire.
  final Color inkSoft;

  /// Couleur d'accent : boutons principaux, progression, éléments marquants.
  final Color accent;

  /// Bonne réponse, progression acquise.
  final Color success;

  /// Mauvaise réponse, erreur de ton.
  final Color danger;

  /// Bordures des cartes et des boutons discrets.
  final Color sand;

  // ---------------------------------------------------------- teintes dérivées
  final Color paperDeep;
  final Color sandSoft;
  final Color correctSoft;
  final Color dangerSoft;
  final Color onAccent;
  final Color onSuccess;
  final Color onError;

  String name(String lang) => switch (lang) {
        'fr' => nameFr,
        'zh' => nameZh.isEmpty ? nameEn : nameZh,
        _ => nameEn,
      };
}

/// `blanc` ou `noir`, selon ce qui contraste le mieux sur [background].
///
/// Utilisé pour le texte des boutons : une palette à accent clair
/// (Dracula, Monokai) obtient du texte noir au lieu d'un blanc illisible.
Color contrastOn(Color background) {
  double channel(int value) {
    final v = value / 255;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  final argb = background.toARGB32();
  final luminance = 0.2126 * channel((argb >> 16) & 0xFF) +
      0.7152 * channel((argb >> 8) & 0xFF) +
      0.0722 * channel(argb & 0xFF);
  final withWhite = 1.05 / (luminance + 0.05);
  final withBlack = (luminance + 0.05) / 0.05;
  return withWhite >= withBlack ? Colors.white : Colors.black;
}

/// Les huit palettes disponibles, claires puis sombres.
///
/// Les noms reprennent les thèmes connus de Visual Studio Code
/// (Light+, Solarized, Monokai, Dracula, Dark+) auxquels s'ajoute la palette
/// d'origine « papier & encre ».
final List<Palette> kPalettes = [
  Palette(
    id: 'papier',
    nameFr: 'Papier',
    nameEn: 'Paper',
    nameZh: '纸张',
    dark: false,
    paper: const Color(0xFFF6F1E7),
    card: const Color(0xFFFFFDF7),
    ink: const Color(0xFF1C1917),
    inkSoft: const Color(0xFF78706A),
    accent: const Color(0xFFB72D26),
    success: const Color(0xFF2E7D5B),
    danger: const Color(0xFFB72D26),
    sand: const Color(0xFFE1D7C3),
  ),
  Palette(
    id: 'clair',
    nameFr: 'Clair',
    nameEn: 'Light',
    nameZh: '明亮',
    dark: false,
    paper: const Color(0xFFF7F7F8),
    card: const Color(0xFFFFFFFF),
    ink: const Color(0xFF2B2B2B),
    inkSoft: const Color(0xFF6E7175),
    accent: const Color(0xFF007ACC),
    success: const Color(0xFF0F7B3E),
    danger: const Color(0xFFD13438),
    sand: const Color(0xFFDCDEE1),
  ),
  Palette(
    id: 'solaire-clair',
    nameFr: 'Solaire clair',
    nameEn: 'Solarized light',
    nameZh: '浅色 Solarized',
    dark: false,
    paper: const Color(0xFFFDF6E3),
    card: const Color(0xFFFFFEF8),
    ink: const Color(0xFF073642),
    inkSoft: const Color(0xFF586E75),
    accent: const Color(0xFF268BD2),
    success: const Color(0xFF7A9600),
    danger: const Color(0xFFC6351F),
    sand: const Color(0xFFE6DDC6),
  ),
  Palette(
    id: 'doux',
    nameFr: 'Doux',
    nameEn: 'Soft',
    nameZh: '柔和',
    dark: false,
    paper: const Color(0xFFFBFAFF),
    card: const Color(0xFFFFFFFF),
    ink: const Color(0xFF2A2733),
    inkSoft: const Color(0xFF6F6A7C),
    accent: const Color(0xFF6B4EE6),
    success: const Color(0xFF2E8B57),
    danger: const Color(0xFFE04A45),
    sand: const Color(0xFFE2DFF0),
  ),
  Palette(
    id: 'sombre',
    nameFr: 'Sombre',
    nameEn: 'Dark',
    nameZh: '深色',
    dark: true,
    paper: const Color(0xFF1E1E1E),
    card: const Color(0xFF262626),
    ink: const Color(0xFFD4D4D4),
    inkSoft: const Color(0xFF9D9D9D),
    accent: const Color(0xFF569CD6),
    success: const Color(0xFF4EC9B0),
    danger: const Color(0xFFF44747),
    sand: const Color(0xFF3B3B3B),
  ),
  Palette(
    id: 'monokai',
    nameFr: 'Monokai',
    nameEn: 'Monokai',
    nameZh: 'Monokai',
    dark: true,
    paper: const Color(0xFF272822),
    card: const Color(0xFF2D2E2C),
    ink: const Color(0xFFF8F8F2),
    inkSoft: const Color(0xFFA5A08C),
    accent: const Color(0xFFF92672),
    success: const Color(0xFFA6E22E),
    danger: const Color(0xFFFF5F57),
    sand: const Color(0xFF41403A),
  ),
  Palette(
    id: 'solaire-sombre',
    nameFr: 'Solaire sombre',
    nameEn: 'Solarized dark',
    nameZh: '深色 Solarized',
    dark: true,
    paper: const Color(0xFF002B36),
    card: const Color(0xFF073642),
    ink: const Color(0xFF93A1A1),
    inkSoft: const Color(0xFF839496),
    accent: const Color(0xFF268BD2),
    success: const Color(0xFF859900),
    danger: const Color(0xFFFF7A6B),
    sand: const Color(0xFF124552),
  ),
  Palette(
    id: 'dracula',
    nameFr: 'Dracula',
    nameEn: 'Dracula',
    nameZh: 'Dracula',
    dark: true,
    paper: const Color(0xFF282A36),
    card: const Color(0xFF2F3341),
    ink: const Color(0xFFF8F8F2),
    inkSoft: const Color(0xFFB8BAD0),
    accent: const Color(0xFFBD93F9),
    success: const Color(0xFF50FA7B),
    danger: const Color(0xFFFF5555),
    sand: const Color(0xFF44475A),
  ),
];

Palette paletteById(String? id) =>
    kPalettes.firstWhere((p) => p.id == id, orElse: () => kPalettes.first);

/// Couleurs effectivement utilisées par les écrans.
///
/// Elles ne sont plus des constantes : la palette est choisie dans les
/// réglages (clair/sombre et nuances multiples). `AppColors.accent` reste
/// donc un simple accèseur, à lire à chaque construction de widget.
abstract final class AppColors {
  static Palette palette = kPalettes.first;

  static void apply(Palette value) => palette = value;

  static Color get paper => palette.paper;
  static Color get paperDeep => palette.paperDeep;
  static Color get card => palette.card;
  static Color get ink => palette.ink;
  static Color get inkSoft => palette.inkSoft;
  static Color get accent => palette.accent;
  static Color get success => palette.success;
  static Color get danger => palette.danger;
  static Color get sand => palette.sand;
  static Color get sandSoft => palette.sandSoft;
  static Color get correctSoft => palette.correctSoft;
  static Color get dangerSoft => palette.dangerSoft;
  static Color get onAccent => palette.onAccent;
  static Color get onSuccess => palette.onSuccess;
  static Color get onError => palette.onError;
  static bool get dark => palette.dark;
}

/// Applique [palette] et construit le thème Material associé.
///
/// L'ordre compte : les couleurs sont publiées avant que les écrans ne se
/// construisent, donc tous les widgets lus la nouvelle palette.
ThemeData buildAppTheme(Palette palette) {
  AppColors.apply(palette);
  final scheme = ColorScheme(
    brightness: palette.dark ? Brightness.dark : Brightness.light,
    primary: palette.accent,
    onPrimary: palette.onAccent,
    secondary: palette.success,
    onSecondary: palette.onSuccess,
    error: palette.danger,
    onError: palette.onError,
    surface: palette.card,
    onSurface: palette.ink,
    outline: palette.sand,
    inverseSurface: Color.lerp(palette.card, palette.ink, .88)!,
    onInverseSurface: palette.card,
    outlineVariant: palette.sand,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'HskHelp',
    scaffoldBackgroundColor: palette.paper,
    splashFactory: InkRipple.splashFactory,
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: palette.ink, height: 1.35),
      bodyLarge: TextStyle(color: palette.ink, height: 1.35),
      titleLarge: TextStyle(color: palette.ink, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(color: palette.inkSoft, letterSpacing: .4),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

/// Dégradé de fond utilisé par tous les écrans.
Decoration appBackground() => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.paper, AppColors.paperDeep],
        stops: const [0.55, 1],
      ),
    );

/// Carte blanche aux coins doux, légèrement ombrée.
BoxDecoration appCardDecoration({Color? color}) => BoxDecoration(
      color: color ?? AppColors.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.sand),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    );

/// Décoration du champ de saisie du pinyin.
InputDecoration pinyinInputDecoration({String? label, String? hint}) {
  const radius = BorderRadius.all(Radius.circular(18));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: AppColors.card,
    alignLabelWithHint: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    labelStyle: TextStyle(color: AppColors.inkSoft),
    hintStyle: TextStyle(color: AppColors.inkSoft, fontSize: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.sand),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.accent, width: 2),
    ),
  );
}

ButtonStyle primaryButtonStyle(BuildContext context) => FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.onAccent,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 17),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
