import 'package:flutter/material.dart';

import '../data/deck.dart';
import '../l10n.dart';
import '../models/word.dart';
import '../services/stats_service.dart';
import '../theme.dart';
import 'quiz_screen.dart';

/// Bilan d'une session : score, nouveaux mots maîtrisés, replays.
class SummaryScreen extends StatelessWidget {
  const SummaryScreen({
    super.key,
    required this.words,
    required this.stats,
    required this.sessionSize,
    required this.correct,
    required this.total,
    required this.masteredGained,
  });

  final List<Word> words;
  final StatsService stats;
  final int sessionSize;
  final int correct;
  final int total;
  final int masteredGained;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ratio = total == 0 ? 0 : correct / total;
    final percent = (ratio * 100).round();
    final perfect = total > 0 && correct == total;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: perfect ? AppColors.success : AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2E000000),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        perfect
                            ? Icons.emoji_events_rounded
                            : Icons.check_rounded,
                        color: perfect
                            ? AppColors.onSuccess
                            : AppColors.onAccent,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    perfect ? s.flawless : s.sessionDone,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.percentCorrect(percent),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 20),
                    decoration: appCardDecoration(),
                    child: Row(
                      children: [
                        _Metric(
                          value: '$correct/$total',
                          label: s.score,
                          color: AppColors.ink,
                        ),
                        const _Divider(),
                        _Metric(
                          value: '+$masteredGained',
                          label: s.mastered,
                          color: AppColors.success,
                        ),
                        const _Divider(),
                        _Metric(
                          value: '${stats.bestStreak}',
                          label: s.record,
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => _replay(context),
                    style: primaryButtonStyle(context),
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(s.again),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.home_rounded, size: 20),
                    label: Text(s.backHome),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: BorderSide(color: AppColors.sand),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
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

  void _replay(BuildContext context) {
    final deck = buildDeck(
      words,
      masteredIds: stats.masteredIds,
      size: sessionSize,
    );
    if (deck.isEmpty) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QuizScreen(
          words: words,
          deck: deck,
          stats: stats,
          sessionSize: sessionSize,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: AppColors.inkSoft,
            ),
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
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.sand,
    );
  }
}
