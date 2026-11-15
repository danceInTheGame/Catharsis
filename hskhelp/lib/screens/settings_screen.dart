import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models/word.dart';
import '../services/stats_service.dart';
import '../theme.dart';

/// Écran des réglages : niveau de HSK, thème, tons, langue.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.stats,
    required this.words,
  });

  final StatsService stats;

  /// Lexique complet, uniquement pour compter les mots du niveau choisi.
  final List<Word> words;

  @override
  Widget build(BuildContext context) {
    final s = Strings(stats.lang);
    final count = words.where((w) => w.level <= stats.maxLevel).length;

    return Scaffold(
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: s.cancel,
                      icon: Icon(Icons.arrow_back_rounded,
                          size: 25, color: AppColors.ink),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.settingsTitle,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: .4,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Section(
                        title: s.sectionPractice,
                        children: [
                          _LevelPicker(
                            stats: stats,
                            count: count,
                            strings: s,
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1, thickness: 1),
                          const SizedBox(height: 6),
                          _ToneToggle(
                            enabled: stats.requireTones,
                            title: s.requireTones,
                            onLabel: s.tonesOn,
                            offLabel: s.tonesOff,
                            onChanged: stats.setRequireTones,
                          ),
                        ],
                      ),
                      _Section(
                        title: s.sectionAppearance,
                        children: [
                          Text(
                            s.themeSection,
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: .6,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final palette in kPalettes)
                                _ThemeChip(
                                  palette: palette,
                                  name: palette.name(stats.lang.code),
                                  selected: palette.id == stats.themeId,
                                  onTap: () => stats.setThemeId(palette.id),
                                ),
                            ],
                          ),
                        ],
                      ),
                      _Section(
                        title: s.sectionLanguage,
                        children: [
                          Text(
                            s.languageHint,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.inkSoft,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final l in AppLang.values)
                                SizedBox(
                                  width:
                                      (MediaQuery.of(context).size.width - 60) / 2,
                                  child: _ChoiceButton(
                                    label: l.nativeName,
                                    selected: stats.lang == l,
                                    onTap: () => stats.setLang(l),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
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

/// Carte de réglage avec un titre de section au-dessus.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: appCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sélecteur cumulatif « jusqu'au niveau N », avec le nombre de mots.
class _LevelPicker extends StatelessWidget {
  const _LevelPicker({
    required this.stats,
    required this.count,
    required this.strings,
  });

  final StatsService stats;
  final int count;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final level = stats.maxLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strings.levelSection,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'HSK ${strings.levelLabel(level)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onAccent,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: level.toDouble(),
          min: 1,
          max: 7,
          divisions: 6,
          label: 'HSK ${strings.levelLabel(level)}',
          onChanged: (value) => stats.setMaxLevel(value.round()),
        ),
        Row(
          children: [
            for (var i = 1; i <= 7; i++) ...[
              Expanded(
                child: Center(
                  child: Text(
                    strings.levelLabel(i),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          i <= level ? FontWeight.w700 : FontWeight.w500,
                      color: i <= level ? AppColors.accent : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          strings.levelHint,
          style: TextStyle(
              fontSize: 12.5, color: AppColors.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 6),
        Text(
          strings.wordsCount(count),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

/// Bascule « Exiger les tons ».
class _ToneToggle extends StatelessWidget {
  const _ToneToggle({
    required this.enabled,
    required this.title,
    required this.onLabel,
    required this.offLabel,
    required this.onChanged,
  });

  final bool enabled;
  final String title;
  final String onLabel;
  final String offLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          enabled ? Icons.graphic_eq_rounded : Icons.blur_on_rounded,
          color: enabled ? AppColors.accent : AppColors.inkSoft,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                enabled ? onLabel : offLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.inkSoft,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: enabled,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Pastille de thème : aperçu des couleurs et nom.
class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.palette,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColors.accent : AppColors.sand;
    return Material(
      color: selected ? AppColors.accent : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  width: 34,
                  height: 19,
                  color: palette.paper,
                  child: Row(
                    children: [
                      Expanded(child: Container(color: palette.accent)),
                      Expanded(child: Container(color: palette.ink)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.onAccent : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton de choix unique (langue, taille de session…).
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accent : AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.sand,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.onAccent : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
