import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n.dart';
import '../theme.dart';

/// Réglages de l'application et statistiques de progression.
///
/// Est un [ChangeNotifier] : les réglages (niveau, thème, langue, tons)
/// notifient l'arbre widget pour que l'interface se reconstruise aussitôt.
/// Les réponses, elles, sont sauvegardées sans reconstruire l'application.
class StatsService extends ChangeNotifier {
  StatsService._(
    this._prefs,
    this.masteredIds,
    this.totalAnswers,
    this.totalCorrect,
    this.streak,
    this.bestStreak,
    this.sessions,
    this.requireTones,
    this.maxLevel,
    this.themeId,
    this.lang,
  );

  final SharedPreferences _prefs;

  /// Mots répondus sans erreur (et sans indice) : considérés comme acquis.
  final Set<int> masteredIds;

  int totalAnswers;
  int totalCorrect;

  /// Série de bonnes réponses consécutives.
  int streak;
  int bestStreak;

  /// Nombre de sessions terminées.
  int sessions;

  /// Faut-il exiger les tons dans la saisie du pinyin ?
  ///
  /// Activé par défaut : c'est l'objectif affiché de l'application.
  bool requireTones;

  /// Dernier niveau HSK sélectionné, de 1 à 7 (7 = bandeau 7-9).
  ///
  /// La sélection est cumulative : on s'exerce sur tous les niveaux
  /// inférieurs ou égaux.
  int maxLevel;

  /// Identifiant de la palette ([kPalettes]) en cours.
  String themeId;

  /// Langue de l'interface et des significations.
  AppLang lang;

  static const _kMastered = 'mastered_ids';
  static const _kAnswers = 'total_answers';
  static const _kCorrect = 'total_correct';
  static const _kStreak = 'streak';
  static const _kBest = 'best_streak';
  static const _kSessions = 'sessions';
  static const _kRequireTones = 'require_tones';
  static const _kMaxLevel = 'max_level';
  static const _kTheme = 'theme_id';
  static const _kLang = 'app_lang';

  static Future<StatsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mastered =
        (prefs.getStringList(_kMastered) ?? const <String>[])
            .map(int.tryParse)
            .whereType<int>()
            .toSet();
    final level = prefs.getInt(_kMaxLevel) ?? 1;
    return StatsService._(
      prefs,
      mastered,
      prefs.getInt(_kAnswers) ?? 0,
      prefs.getInt(_kCorrect) ?? 0,
      prefs.getInt(_kStreak) ?? 0,
      prefs.getInt(_kBest) ?? 0,
      prefs.getInt(_kSessions) ?? 0,
      prefs.getBool(_kRequireTones) ?? true,
      level < 1 ? 1 : (level > 7 ? 7 : level),
      prefs.getString(_kTheme) ?? kPalettes.first.id,
      AppLangX.fromCode(prefs.getString(_kLang)),
    );
  }

  /// Palette effective : celle retenue, ou la première si l'identifiant
  /// ne correspond plus (thème retiré entre deux versions).
  Palette get palette => paletteById(themeId);

  void setRequireTones(bool value) {
    if (value == requireTones) return;
    requireTones = value;
    _prefs.setBool(_kRequireTones, value);
    notifyListeners();
  }

  void setMaxLevel(int value) {
    final level = value < 1 ? 1 : (value > 7 ? 7 : value);
    if (level == maxLevel) return;
    maxLevel = level;
    _prefs.setInt(_kMaxLevel, level);
    notifyListeners();
  }

  void setThemeId(String value) {
    if (value == themeId) return;
    themeId = value;
    _prefs.setString(_kTheme, value);
    notifyListeners();
  }

  void setLang(AppLang value) {
    if (value == lang) return;
    lang = value;
    _prefs.setString(_kLang, value.code);
    notifyListeners();
  }

  bool isMastered(int wordId) => masteredIds.contains(wordId);

  double get accuracy =>
      totalAnswers == 0 ? 0 : totalCorrect / totalAnswers;

  /// Enregistre une réponse. Renvoie `true` si le mot devient maîtrisé.
  bool record({required int wordId, required bool correct, required bool firstTry}) {
    totalAnswers += 1;
    if (correct) {
      totalCorrect += 1;
      streak += 1;
      if (streak > bestStreak) bestStreak = streak;
    } else {
      streak = 0;
    }
    var newlyMastered = false;
    if (correct && firstTry && masteredIds.add(wordId)) {
      newlyMastered = true;
    }
    _save();
    return newlyMastered;
  }

  void endSession() {
    sessions += 1;
    _save();
  }

  void resetProgress() {
    masteredIds.clear();
    totalAnswers = 0;
    totalCorrect = 0;
    streak = 0;
    bestStreak = 0;
    sessions = 0;
    _save();
    notifyListeners();
  }

  void _save() {
    _prefs.setStringList(
      _kMastered,
      masteredIds.map((id) => id.toString()).toList(growable: false),
    );
    _prefs.setInt(_kAnswers, totalAnswers);
    _prefs.setInt(_kCorrect, totalCorrect);
    _prefs.setInt(_kStreak, streak);
    _prefs.setInt(_kBest, bestStreak);
    _prefs.setInt(_kSessions, sessions);
  }
}
