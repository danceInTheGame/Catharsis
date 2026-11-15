import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models/grammar_rule.dart';
import '../services/grammar_repository.dart';
import '../theme.dart';
import 'grammar_exercise_screen.dart';
import 'grammar_rule_screen.dart';

/// Page d'un niveau : ses sections, puis ses catégories.
class GrammarLevelScreen extends StatelessWidget {
  const GrammarLevelScreen({super.key, required this.level});

  final GrammarLevel level;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: s.grammarLevelTitle(level.code),
                subtitle:
                    '${level.ruleCount} ${s.rulesCount} · ${level.sections.length} ${s.sectionsLabel}',
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
                  children: [
                    for (final section in level.sections) ...[
                      const SizedBox(height: 18),
                      Text(
                        _sectionLabel(s, section.name).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...section.categories.map(
                        (category) => _CategoryCard(
                          category: category,
                          level: level,
                          section: section,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.level,
    required this.section,
  });

  final GrammarCategory category;
  final GrammarLevel level;
  final GrammarSection section;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final repo = GrammarRepository.instance;
    final first = category.ruleIds.isEmpty ? null : repo.rule(category.ruleIds.first);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GrammarRulesScreen(
                title: category.nameFor(s.lang.code),
                level: level,
                ruleIds: category.ruleIds,
              ),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: appCardDecoration(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.nameFor(s.lang.code),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (first != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        first.titleFor(s.lang.code),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.sandSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${category.ruleIds.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

/// Liste des règles d'une catégorie.
class GrammarRulesScreen extends StatelessWidget {
  const GrammarRulesScreen({
    super.key,
    required this.title,
    required this.level,
    required this.ruleIds,
  });

  final String title;
  final GrammarLevel level;
  final List<String> ruleIds;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final repo = GrammarRepository.instance;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: title,
                subtitle: '${ruleIds.length} ${s.rulesCount}',
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
                  itemCount: ruleIds.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final rule = repo.rule(ruleIds[index]);
                    if (rule == null) return const SizedBox.shrink();
                    final structures = rule.structureFor(s.lang.code);
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GrammarRuleScreen(
                              ruleId: rule.id,
                              levelCode: level.code,
                              level: level.appLevel,
                            ),
                          ),
                        );
                      },
                      child: Ink(
                        padding: const EdgeInsets.all(16),
                        decoration: appCardDecoration(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rule.titleFor(s.lang.code),
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  if (structures.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      structures.first,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded,
                                color: AppColors.inkSoft),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GrammarExerciseScreen(
                            maxLevel: level.appLevel,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text(s.practiceAllRules),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
