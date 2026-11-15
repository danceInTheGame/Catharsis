import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models/grammar_rule.dart';
import '../services/grammar_repository.dart';
import '../theme.dart';
import 'grammar_exercise_screen.dart';

/// Fiche d'une règle : titre, parties, structures et exemples (hanzi en rouge,
/// pinyin, traduction).
class GrammarRuleScreen extends StatelessWidget {
  const GrammarRuleScreen({
    super.key,
    required this.ruleId,
    required this.levelCode,
    required this.level,
  });

  final String ruleId;
  final String levelCode;
  final int level;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final rule = GrammarRepository.instance.rule(ruleId);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          child: rule == null
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: Icon(Icons.arrow_back_rounded,
                                color: AppColors.ink),
                          ),
                          Expanded(
                            child: Text(
                              '$levelCode · '
                              '${GrammarRepository.instance.categoryName(rule.category, s.lang)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.inkSoft,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: s.practiceThisRule,
                            onPressed: () => _practice(context, s),
                            icon: Icon(Icons.bolt_rounded,
                                color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                        children: [
                          Text(
                            rule.titleFor(s.lang.code),
                            style: TextStyle(
                              fontSize: 25,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _Chip(text: levelCode),
                              _Chip(
                                text: GrammarRepository.instance
                                    .categoryName(rule.category, s.lang),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          for (final block in rule.blocks)
                            _RuleBlock(block: block, lang: s.lang.code),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _practice(context, s),
                              icon: const Icon(Icons.bolt_rounded),
                              label: Text(s.practiceThisRule),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _practice(BuildContext context, Strings s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GrammarExerciseScreen(
          maxLevel: level,
          onlyRuleId: ruleId,
          title: GrammarRepository.instance.rule(ruleId)?.titleFor(s.lang.code),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.sandSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }
}

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({required this.block, required this.lang});

  final GrammarBlock block;
  final String lang;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case 'h2':
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            block.textFor(lang),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        );
      case 'h3':
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            block.textFor(lang).toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: AppColors.inkSoft,
            ),
          ),
        );
      case 'structure':
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accent.withValues(alpha: .22)),
          ),
          child: Text(
            block.textFor(lang),
            style: TextStyle(
              fontSize: 15.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        );
      case 'examples':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final example in block.items)
              _ExampleCard(example: example, lang: lang),
          ],
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            block.textFor(lang),
            style: TextStyle(
              fontSize: 15.5,
              height: 1.55,
              color: AppColors.ink,
            ),
          ),
        );
    }
  }
}

/// Exemple : hanzi (mot clé en rouge), pinyin, traduction.
class ExampleView extends StatelessWidget {
  const ExampleView({super.key, required this.example, required this.lang});

  final GrammarExample example;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HanziText(
          text: example.zh,
          highlights: example.hl,
          style: TextStyle(
            fontSize: 17,
            height: 1.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        if (example.pinyin.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            example.pinyin,
            style: TextStyle(
              fontSize: 13.5,
              fontStyle: FontStyle.italic,
              color: AppColors.inkSoft,
            ),
          ),
        ],
        if (example.translationFor(lang).trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            example.translationFor(lang),
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ],
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.example, required this.lang});

  final GrammarExample example;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sand),
      ),
      child: ExampleView(example: example, lang: lang),
    );
  }
}

/// Texte hanzi où les plages repérées passent en rouge.
class _HanziText extends StatelessWidget {
  const _HanziText({
    required this.text,
    required this.highlights,
    required this.style,
  });

  final String text;
  final List<List<int>> highlights;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) return Text(text, style: style);

    final red = <int>{};
    for (final range in highlights) {
      if (range.length < 2) continue;
      final start = range[0].clamp(0, text.length);
      final end = range[1].clamp(start, text.length);
      for (var i = start; i < end; i++) {
        red.add(i);
      }
    }
    if (red.isEmpty) return Text(text, style: style);

    final highlight = TextStyle(
      color: AppColors.danger,
      fontWeight: FontWeight.w800,
    );
    final spans = <TextSpan>[];
    var index = 0;
    while (index < text.length) {
      final isRed = red.contains(index);
      var next = index + 1;
      while (next < text.length && red.contains(next) == isRed) {
        next++;
      }
      spans.add(TextSpan(
        text: text.substring(index, next),
        style: isRed ? highlight : null,
      ));
      index = next;
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
