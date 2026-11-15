import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter/material.dart';

import '../l10n.dart';
import '../models/grammar_exercise.dart';
import '../services/grammar_repository.dart';
import '../theme.dart';
import 'grammar_rule_screen.dart';

/// Session d'exercices de grammaire, tirée au hasard dans tout le contenu.
///
/// Les deux types d'exercices alternent sans jamais s'enchaîner plus
/// de deux fois, et aucune règle ne revient deux fois dans la même session.
class GrammarExerciseScreen extends StatefulWidget {
  const GrammarExerciseScreen({
    super.key,
    required this.maxLevel,
    this.onlyRuleId,
    this.title,
    this.session,
  });

  /// Niveau HSK maximum : la grammaire correspondante est plafonnée à C1.
  final int maxLevel;

  /// Limite la session à une règle (bouton « s'exercer » de la fiche).
  final String? onlyRuleId;

  /// Titre affiché en tête de session.
  final String? title;

  /// Session imposée (tests) ; sinon elle est tirée au hasard.
  @visibleForTesting
  final List<GrammarExercise>? session;

  @override
  State<GrammarExerciseScreen> createState() => _GrammarExerciseScreenState();
}

class _GrammarExerciseScreenState extends State<GrammarExerciseScreen> {
  static const int _sessionLength = 15;

  final List<GrammarExercise> _session = [];
  int _index = 0;
  int _score = 0;
  bool _finished = false;

  // « Mot manquant »
  String? _chosen;
  bool _answered = false;

  // « Phrase mélangée »
  List<int> _picked = [];
  List<int> _pool = [];
  String? _mixedMessage;
  bool _revealed = false;
  bool _lastCorrect = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final s = AppScope.of(context);
    final exercises = widget.session ??
        GrammarRepository.instance.buildSession(
          count: _sessionLength,
          maxLevel: widget.maxLevel,
          lang: s.lang,
          onlyRule: widget.onlyRuleId,
        );
    _session
      ..clear()
      ..addAll(exercises);
    _index = 0;
    _score = 0;
    _finished = false;
    _resetExercise();
  }

  void _resetExercise() {
    _chosen = null;
    _answered = false;
    _mixedMessage = null;
    _revealed = false;
    _lastCorrect = false;
    _picked = [];
    if (_session.isNotEmpty && _index < _session.length) {
      final exercise = _session[_index];
      _pool = [for (var i = 0; i < exercise.shuffled.length; i++) i];
    } else {
      _pool = [];
    }
  }

  void _next() {
    if (_index + 1 >= _session.length) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _resetExercise();
    });
  }

  void _choose(String option) {
    if (_answered) return;
    final exercise = _session[_index];
    setState(() {
      _chosen = option;
      _answered = true;
      if (option == exercise.answer) {
        _score++;
        _lastCorrect = true;
      } else {
        _lastCorrect = false;
      }
    });
  }

  void _pick(int index) {
    if (_revealed) return;
    setState(() {
      _pool.remove(index);
      _picked.add(index);
    });
  }

  void _unpick(int index) {
    if (_revealed) return;
    setState(() {
      _picked.remove(index);
      _pool.add(index);
    });
  }

  void _verifyMixed() {
    if (_revealed) return;
    final s = AppScope.of(context);
    final exercise = _session[_index];
    if (_picked.length < exercise.tokens.length) {
      setState(() => _mixedMessage = s.incompleteOrder);
      return;
    }
    final candidate = [for (final i in _picked) exercise.shuffled[i]];
    if (listEquals(candidate, exercise.tokens)) {
      setState(() {
        _score++;
        _lastCorrect = true;
        _revealed = true;
        _mixedMessage = null;
      });
    } else {
      setState(() {
        _lastCorrect = false;
        _mixedMessage = s.wrongOrder;
      });
    }
  }

  void _showAnswer() {
    setState(() {
      _revealed = true;
      _lastCorrect = false;
      _mixedMessage = null;
    });
  }

  void _clearMixed() {
    if (_revealed) return;
    setState(() {
      _picked = [];
      _pool = [for (var i = 0; i < _session[_index].shuffled.length; i++) i];
      _mixedMessage = null;
    });
  }

  void _openRule(GrammarExercise exercise) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GrammarRuleScreen(
          ruleId: exercise.rule.id,
          levelCode: exercise.rule.levelCode,
          level: exercise.rule.level,
        ),
      ),
    );
  }

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
              _Header(
                title: widget.title ?? s.practiceAllRules,
                index: _index,
                total: _session.length,
                score: _score,
                finished: _finished,
                onClose: () => Navigator.of(context).maybePop(),
              ),
              if (!_finished && _session.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_index + 1) / _session.length,
                      minHeight: 6,
                      backgroundColor: AppColors.sandSoft,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              Expanded(
                child: _finished || _session.isEmpty
                    ? _Summary(
                        score: _score,
                        total: _session.length,
                        onAgain: () => setState(_start),
                        onBack: () => Navigator.of(context).maybePop(),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                        children: [
                          _ExerciseBody(
                            exercise: _session[_index],
                            chosen: _chosen,
                            answered: _answered,
                            picked: _picked,
                            pool: _pool,
                            mixedMessage: _mixedMessage,
                            revealed: _revealed,
                            lastCorrect: _lastCorrect,
                            onChoose: _choose,
                            onPick: _pick,
                            onUnpick: _unpick,
                            onVerify: _verifyMixed,
                            onClear: _clearMixed,
                            onShowAnswer: _showAnswer,
                            onOpenRule: () => _openRule(_session[_index]),
                          ),
                          const SizedBox(height: 18),
                          if (_done)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _next,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    _index + 1 >= _session.length
                                        ? s.seeResult
                                        : s.nextExercise,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
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

  bool get _done {
    if (_session.isEmpty) return false;
    return _session[_index].type == ExerciseType.fill
        ? _answered
        : _revealed;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.index,
    required this.total,
    required this.score,
    required this.finished,
    required this.onClose,
  });

  final String title;
  final int index;
  final int total;
  final int score;
  final bool finished;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: AppColors.ink),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  finished
                      ? s.sessionDone
                      : '${s.exerciseProgress} ${index + 1} / $total',
                  style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.sandSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 15, color: AppColors.inkSoft),
                const SizedBox(width: 4),
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseBody extends StatelessWidget {
  const _ExerciseBody({
    required this.exercise,
    required this.chosen,
    required this.answered,
    required this.picked,
    required this.pool,
    required this.mixedMessage,
    required this.revealed,
    required this.lastCorrect,
    required this.onChoose,
    required this.onPick,
    required this.onUnpick,
    required this.onVerify,
    required this.onClear,
    required this.onShowAnswer,
    required this.onOpenRule,
  });

  final GrammarExercise exercise;
  final String? chosen;
  final bool answered;
  final List<int> picked;
  final List<int> pool;
  final String? mixedMessage;
  final bool revealed;
  final bool lastCorrect;
  final ValueChanged<String> onChoose;
  final ValueChanged<int> onPick;
  final ValueChanged<int> onUnpick;
  final VoidCallback onVerify;
  final VoidCallback onClear;
  final VoidCallback onShowAnswer;
  final VoidCallback onOpenRule;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final done =
        exercise.type == ExerciseType.fill ? answered : revealed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                exercise.type == ExerciseType.fill
                    ? s.missingWord
                    : s.mixedPhrase,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                exercise.rule.titleFor(s.lang.code),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          exercise.type == ExerciseType.fill ? s.chooseAnswer : s.arrangeWords,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 12),
        if (exercise.type == ExerciseType.fill)
          _FillExercise(
            exercise: exercise,
            chosen: chosen,
            answered: answered,
            onChoose: onChoose,
          )
        else
          _MixedExercise(
            exercise: exercise,
            picked: picked,
            pool: pool,
            message: mixedMessage,
            revealed: revealed,
            onPick: onPick,
            onUnpick: onUnpick,
            onVerify: onVerify,
            onClear: onClear,
            onShowAnswer: onShowAnswer,
          ),
        if (done) ...[
          const SizedBox(height: 16),
          _Feedback(
            exercise: exercise,
            correct: lastCorrect,
            chosen: chosen,
            onOpenRule: onOpenRule,
          ),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------- mot manquant

class _FillExercise extends StatelessWidget {
  const _FillExercise({
    required this.exercise,
    required this.chosen,
    required this.answered,
    required this.onChoose,
  });

  final GrammarExercise exercise;
  final String? chosen;
  final bool answered;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final tokens = exercise.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: appCardDecoration(),
          child: Wrap(
            spacing: 4,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < tokens.length; i++)
                if (i == exercise.blankIndex)
                  _Blank(
                    filled: answered,
                    text: exercise.answer + exercise.answerSuffix,
                    correct: chosen == exercise.answer,
                  )
                else
                  Text(
                    tokens[i],
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
            ],
          ),
        ),
        if (exercise.hint.isNotEmpty && !answered) ...[
          const SizedBox(height: 10),
          Text(
            '${s.hint} : ${exercise.hint}'
            '${exercise.hintPinyin.isEmpty ? '' : ' (${exercise.hintPinyin})'}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (var row = 0; row < 2; row++) ...[
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                if (col > 0) const SizedBox(width: 10),
                Expanded(
                  child: _Option(
                    index: row * 2 + col,
                    text: exercise.options[row * 2 + col],
                    answer: exercise.answer,
                    chosen: chosen,
                    answered: answered,
                    onTap: () => onChoose(exercise.options[row * 2 + col]),
                  ),
                ),
              ],
            ],
          ),
          if (row == 0) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _Blank extends StatelessWidget {
  const _Blank({
    required this.filled,
    required this.text,
    required this.correct,
  });

  final bool filled;
  final String text;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2.4,
            color: filled
                ? (correct ? AppColors.success : AppColors.danger)
                : AppColors.accent,
          ),
        ),
      ),
      child: Text(
        filled ? text : '　　　',
        style: TextStyle(
          fontSize: 20,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: filled
              ? (correct ? AppColors.success : AppColors.danger)
              : AppColors.accent,
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.index,
    required this.text,
    required this.answer,
    required this.chosen,
    required this.answered,
    required this.onTap,
  });

  final int index;
  final String text;
  final String answer;
  final String? chosen;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAnswer = text == answer;
    final isChosen = text == chosen;

    Color border = AppColors.sand;
    Color fill = AppColors.card;
    Color ink = AppColors.ink;

    if (answered) {
      if (isAnswer) {
        border = AppColors.success;
        fill = AppColors.correctSoft;
        ink = AppColors.success;
      } else if (isChosen) {
        border = AppColors.danger;
        fill = AppColors.dangerSoft;
        ink = AppColors.danger;
      } else {
        ink = AppColors.inkSoft;
      }
    }

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: isAnswer || isChosen ? 2 : 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ phrase mélangée

class _MixedExercise extends StatelessWidget {
  const _MixedExercise({
    required this.exercise,
    required this.picked,
    required this.pool,
    required this.message,
    required this.revealed,
    required this.onPick,
    required this.onUnpick,
    required this.onVerify,
    required this.onClear,
    required this.onShowAnswer,
  });

  final GrammarExercise exercise;
  final List<int> picked;
  final List<int> pool;
  final String? message;
  final bool revealed;
  final ValueChanged<int> onPick;
  final ValueChanged<int> onUnpick;
  final VoidCallback onVerify;
  final VoidCallback onClear;
  final VoidCallback onShowAnswer;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    final answerTokens = revealed
        ? exercise.tokens
        : [for (final i in picked) exercise.shuffled[i]];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: revealed
                ? (AppColors.success.withValues(alpha: .08))
                : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: revealed ? AppColors.success : AppColors.sand,
              width: revealed ? 2 : 1,
            ),
          ),
          child: answerTokens.isEmpty
              ? Center(
                  child: Text(
                    s.tapToBuild,
                    style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  ),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < answerTokens.length; i++)
                      _TokenChip(
                        text: answerTokens[i],
                        highlighted: revealed,
                        onTap: revealed
                            ? null
                            : () => onUnpick(picked[i]),
                      ),
                  ],
                ),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final i in pool)
              _TokenChip(
                text: exercise.shuffled[i],
                onTap: revealed ? null : () => onPick(i),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!revealed)
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onVerify,
                  child: Text(s.verify),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: s.clearPieces,
                onPressed: onClear,
                icon: Icon(Icons.restart_alt_rounded, color: AppColors.inkSoft),
              ),
              IconButton(
                tooltip: s.showAnswer,
                onPressed: onShowAnswer,
                icon: Icon(Icons.visibility_outlined, color: AppColors.inkSoft),
              ),
            ],
          ),
      ],
    );
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip({
    required this.text,
    this.highlighted = false,
    this.onTap,
  });

  final String text;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppColors.correctSoft : AppColors.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(
              color: highlighted ? AppColors.success : AppColors.sand,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ correction

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.exercise,
    required this.correct,
    required this.chosen,
    required this.onOpenRule,
  });

  final GrammarExercise exercise;
  final bool correct;
  final String? chosen;
  final VoidCallback onOpenRule;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final color = correct ? AppColors.success : AppColors.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: correct ? AppColors.correctSoft : AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: .5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    correct
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exercise.type == ExerciseType.fill
                          ? (correct ? s.correctWord : s.wrongWord)
                          : (correct ? s.correctWord : s.wrongOrder),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (exercise.type == ExerciseType.fill)
                Text(
                  '${s.theAnswer} : ${exercise.answer}'
                  '${exercise.hintPinyin.isEmpty ? '' : '  ·  ${exercise.hintPinyin}'}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              if (exercise.type == ExerciseType.fill && exercise.hint.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    exercise.hint,
                    style: TextStyle(
                        fontSize: 14, color: AppColors.inkSoft),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                exercise.sentence,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              if (exercise.pinyin.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  exercise.pinyin,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
              if (exercise.translation.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  exercise.translation,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _RuleReminder(exercise: exercise, onOpenRule: onOpenRule),
      ],
    );
  }
}

/// Rappel de la règle, affiché après chaque réponse.
class _RuleReminder extends StatelessWidget {
  const _RuleReminder({required this.exercise, required this.onOpenRule});

  final GrammarExercise exercise;
  final VoidCallback onOpenRule;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final rule = exercise.rule;
    final explanation = rule.explanationFor(s.lang.code);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                s.theRule.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rule.titleFor(s.lang.code),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              explanation,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.55,
                color: AppColors.ink,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenRule,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(s.fullRule),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.score,
    required this.total,
    required this.onAgain,
    required this.onBack,
  });

  final int score;
  final int total;
  final VoidCallback onAgain;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              const SizedBox(height: 30),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  total > 0 && score == total
                      ? Icons.emoji_events_rounded
                      : Icons.insights_rounded,
                  size: 46,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                total > 0 && score == total ? s.flawless : s.exerciseDone,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.sessionScore(score, total),
                style: TextStyle(fontSize: 15, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAgain,
                  child: Text(s.nextSession),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onBack,
                  child: Text(s.backHome),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
