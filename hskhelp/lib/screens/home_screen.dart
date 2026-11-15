import 'package:flutter/material.dart';

import '../data/deck.dart';
import '../l10n.dart';
import '../models/word.dart';
import '../services/stats_service.dart';
import '../theme.dart';
import 'grammar_home_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

/// Écran d'accueil : bascule vocabulaire/grammaire, statistiques, lancement.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.words,
    required this.stats,
  });

  final List<Word> words;
  final StatsService stats;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Tailles de session. `0` signifie « tous les mots du niveau choisi ».
  static const _sizes = [10, 20, 0];
  int _sessionSize = 20;

  /// 0 = vocabulaire, 1 = grammaire.
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    if (_mode == 1) {
      // Mode grammaire
      return Scaffold(
        body: Container(
          decoration: appBackground(),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _ModeToggle(
                    mode: _mode,
                    strings: s,
                    onChanged: (v) => setState(() => _mode = v),
                  ),
                ),
                Expanded(
                  child: GrammarHomeContent(
                    words: widget.words,
                    stats: widget.stats,
                    onSettings: _openSettings,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mode vocabulaire
    final words = selectWords(widget.words, widget.stats.maxLevel);
    final total = words.length;
    final visibleIds = words.map((w) => w.id).toSet();
    final mastered = widget.stats.masteredIds.intersection(visibleIds).length;
    final size = _sessionSize == 0 ? total : _sessionSize;

    return Scaffold(
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ModeToggle(
                    mode: _mode,
                    strings: s,
                    onChanged: (v) => setState(() => _mode = v),
                  ),
                  const SizedBox(height: 16),
                  _Header(
                    strings: s,
                    level: widget.stats.maxLevel,
                    total: total,
                    onSettings: _openSettings,
                  ),
                  const SizedBox(height: 24),
                  _StatsCard(
                    mastered: mastered,
                    total: total,
                    stats: widget.stats,
                    strings: s,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    s.wordsPerSession,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SizeSelector(
                    sizes: _sizes,
                    selected: _sessionSize,
                    strings: s,
                    onChanged: (value) => setState(() => _sessionSize = value),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => _start(size),
                    style: primaryButtonStyle(context),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(s.start),
                  ),
                  const SizedBox(height: 22),
                  _TipCard(withTones: widget.stats.requireTones, strings: s),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _confirmReset,
                      child: Text(
                        s.resetProgress,
                        style:
                            TextStyle(color: AppColors.inkSoft, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          stats: widget.stats,
          words: widget.words,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _start(int size) async {
    final s = AppScope.of(context);
    final words = selectWords(widget.words, widget.stats.maxLevel);
    final deck = buildDeck(
      words,
      masteredIds: widget.stats.masteredIds,
      size: size,
    );
    if (deck.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noWords)),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizScreen(
          words: words,
          deck: deck,
          stats: widget.stats,
          sessionSize: deck.length,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _confirmReset() async {
    final s = AppScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(s.resetTitle),
        content: Text(s.resetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(s.erase),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      widget.stats.resetProgress();
      setState(() {});
    }
  }
}

/// Bascule Vocabulaire / Grammaire en haut de l'écran d'accueil.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.strings,
    required this.onChanged,
  });

  final int mode;
  final Strings strings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          _ToggleBtn(
            label: strings.vocabulary,
            icon: Icons.translate_rounded,
            selected: mode == 0,
            onTap: () => onChanged(0),
          ),
          _ToggleBtn(
            label: strings.grammar,
            icon: Icons.menu_book_rounded,
            selected: mode == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18,
                    color: selected ? AppColors.onAccent : AppColors.inkSoft),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.onAccent : AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.strings,
    required this.level,
    required this.total,
    required this.onSettings,
  });

  final Strings strings;
  final int level;
  final int total;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 66,
          height: 66,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            '汉',
            style: TextStyle(
              color: AppColors.onAccent,
              fontSize: 36,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.levelTitle(level),
                style: TextStyle(
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.homeSubtitle(total, level),
                style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onSettings,
          tooltip: strings.settings,
          icon: Icon(Icons.settings_rounded, size: 27, color: AppColors.ink),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.mastered,
    required this.total,
    required this.stats,
    required this.strings,
  });

  final int mastered;
  final int total;
  final StatsService stats;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final accuracy = stats.totalAnswers == 0
        ? '—'
        : '${(stats.accuracy * 100).round()} %';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: appCardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              _Metric(
                label: strings.mastered,
                value: '$mastered',
                sub: strings.outOf(total),
                color: AppColors.accent,
              ),
              const _Divider(),
              _Metric(
                label: strings.accuracy,
                value: accuracy,
                sub: strings.answersCount(stats.totalAnswers),
                color: AppColors.ink,
              ),
              const _Divider(),
              _Metric(
                label: strings.streak,
                value: '${stats.streak}',
                sub: strings.bestRecord(stats.bestStreak),
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : mastered / total,
              minHeight: 8,
              color: AppColors.accent,
              backgroundColor: AppColors.sandSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.1,
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.sand,
    );
  }
}

class _SizeSelector extends StatelessWidget {
  const _SizeSelector({
    required this.sizes,
    required this.selected,
    required this.strings,
    required this.onChanged,
  });

  final List<int> sizes;
  final int selected;
  final Strings strings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final size in sizes) ...[
          Expanded(
            child: _SizeButton(
              label: size == 0 ? strings.allWords : '$size',
              selected: size == selected,
              onTap: () => onChanged(size),
            ),
          ),
          if (size != sizes.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
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
          height: 52,
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
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.onAccent : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.withTones, required this.strings});

  final bool withTones;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(color: AppColors.sandSoft),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              color: AppColors.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              withTones ? strings.tipTones : strings.tipNoTones,
              style: TextStyle(
                  fontSize: 13, color: AppColors.ink, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
