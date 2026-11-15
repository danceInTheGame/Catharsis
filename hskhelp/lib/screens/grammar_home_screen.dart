import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models/grammar_rule.dart';
import '../models/word.dart';
import '../services/grammar_repository.dart';
import '../services/stats_service.dart';
import '../theme.dart';
import 'grammar_exercise_screen.dart';
import 'grammar_level_screen.dart';

/// Contenu de l'onglet grammaire, affiché dans l'écran d'accueil.
///
/// Ne possède pas de [Scaffold] : il est intégré à la colonne de l'accueil,
/// sous la bascule vocabulaire/grammaire. Il présente l'arborescence : un
/// niveau (A1 → HSK 1 … C1 → HSK 5-6), ses sections, ses catégories et ses
/// règles.
class GrammarHomeContent extends StatefulWidget {
  const GrammarHomeContent({
    super.key,
    required this.words,
    required this.stats,
    required this.onSettings,
  });

  final List<Word> words;
  final StatsService stats;
  final VoidCallback onSettings;

  @override
  State<GrammarHomeContent> createState() => _GrammarHomeContentState();
}

class _GrammarHomeContentState extends State<GrammarHomeContent> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await GrammarRepository.instance.load(widget.words);
    } catch (_) {
      // L'écran affichera l'erreur de chargement.
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final repo = GrammarRepository.instance;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!repo.isLoaded) {
      return Center(child: Text(s.loadError));
    }

    final maxLevel = widget.stats.maxLevel;
    // La grammaire s'arrête à C1 : au-delà du niveau 6, tout le contenu reste
    // accessible.
    final grammarMax = maxLevel >= 6 ? 5 : maxLevel;
    final levels = repo.levelsUpTo(grammarMax);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.menu_book_rounded,
                        color: AppColors.accent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.grammar,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.grammarLevelsSubtitle,
                          style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: s.settings,
                    onPressed: widget.onSettings,
                    icon: Icon(Icons.settings_outlined, color: AppColors.inkSoft),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Exercices : un tirage au hasard dans tout le contenu.
              _PracticeCard(
                title: s.practiceAllRules,
                subtitle: s.practiceAllRulesHint,
                onTap: levels.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                GrammarExerciseScreen(maxLevel: grammarMax),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 26),

              Text(
                s.grammarLevelsTitle,
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 10),
              for (final level in levels) ...[
                _LevelCard(
                  level: level,
                  labels: [
                    for (final section in level.sections)
                      _sectionLabel(s, section.name),
                  ],
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GrammarLevelScreen(level: level),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _sectionLabel(Strings s, String name) {
  switch (name) {
    case 'Catégories grammaticales':
      return s.sectionGrammarCategories;
    case 'Structures grammaticales':
      return s.sectionGrammarStructures;
    case 'Comparaisons':
      return s.sectionGrammarComparisons;
  }
  return name;
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent,
              Color.lerp(AppColors.accent, Colors.black, .18)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: .3),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.bolt_rounded,
                  color: AppColors.onAccent, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.onAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.onAccent.withValues(alpha: .85),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.onAccent.withValues(alpha: .8)),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.labels,
    required this.onTap,
  });

  final GrammarLevel level;
  final List<String> labels;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final palette = AppColors.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: appCardDecoration(),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                level.code,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: palette.accent,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.grammarLevelTitle(level.code),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${level.hskLabel} · ${level.ruleCount} ${s.rulesCount}',
                    style: TextStyle(fontSize: 13, color: palette.inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final label in labels)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: palette.sandSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                                fontSize: 11, color: palette.inkSoft),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.inkSoft),
          ],
        ),
      ),
    );
  }
}
