import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../models/word.dart';
import '../services/stats_service.dart';
import '../theme.dart';
import 'summary_screen.dart';

enum _Phase { answering, revealed }

/// Écran principal : affiche un mot en hanzi, attend le pinyin, puis corrige.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.words,
    required this.deck,
    required this.stats,
    required this.sessionSize,
  });

  final List<Word> words;
  final List<Word> deck;
  final StatsService stats;
  final int sessionSize;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode();
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  int _index = 0;
  _Phase _phase = _Phase.answering;
  String _submitted = '';
  bool _correct = false;

  /// « Je ne sais pas » : on montre la réponse au lieu de pointer une faute.
  bool _skipped = false;

  /// Les lettres étaient justes mais le ton faux (mode « exiger les tons »).
  bool _toneError = false;

  bool _usedHint = false;
  int _sessionCorrect = 0;
  int _sessionMastered = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shake.dispose();
    super.dispose();
  }

  Word get _word => widget.deck[_index];
  bool get _isLast => _index + 1 >= widget.deck.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: appBackground(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AnimatedBuilder(
                                animation: _shake,
                                builder: (context, child) => Transform.translate(
                                  offset: Offset(_shakeOffset, 0),
                                  child: child,
                                ),
                                child: _buildWordCard(),
                              ),
                              const SizedBox(height: 16),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: _phase == _Phase.answering
                                    ? _buildInput()
                                    : _buildResult(),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  double get _shakeOffset {
    final t = _shake.value;
    if (t >= 1) return 0;
    return math.sin(t * math.pi * 6) * 13 * (1 - t);
  }

  // ----------------------------------------------------------------- actions

  void _validate({bool skip = false}) {
    if (_phase == _Phase.revealed) return;
    final s = AppScope.of(context);
    final answer = _controller.text.trim();
    if (!skip && answer.isEmpty) {
      _showMessage(s.typePinyinFirst);
      return;
    }
    final correct = !skip &&
        _word.accepts(answer, withTones: widget.stats.requireTones);
    // Lettres correctes mais ton faux : c'est le cas le plus fréquent en
    // mode strict, et le plus utile à signaler précisément.
    final toneError = !correct &&
        !skip &&
        widget.stats.requireTones &&
        _word.accepts(answer, withTones: false);
    final firstTry = correct && !_usedHint;
    final masteredNow = widget.stats.record(
      wordId: _word.id,
      correct: correct,
      firstTry: firstTry,
    );
    setState(() {
      _phase = _Phase.revealed;
      _submitted = answer;
      _correct = correct;
      _skipped = skip;
      _toneError = toneError;
      if (correct) _sessionCorrect += 1;
      if (masteredNow) _sessionMastered += 1;
    });
    if (correct) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
      // Une réponse effacée volontairement n'a rien d'une erreur à signaler.
      if (!skip) _shake.forward(from: 0);
    }
    _focusNode.unfocus();
  }

  void _next() {
    if (_isLast) {
      widget.stats.endSession();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SummaryScreen(
            words: widget.words,
            stats: widget.stats,
            sessionSize: widget.sessionSize,
            correct: _sessionCorrect,
            total: widget.deck.length,
            masteredGained: _sessionMastered,
          ),
        ),
      );
      return;
    }
    setState(() {
      _index += 1;
      _phase = _Phase.answering;
      _usedHint = false;
      _submitted = '';
      _correct = false;
      _skipped = false;
      _toneError = false;
      _controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _phase == _Phase.answering) _focusNode.requestFocus();
    });
  }

  void _hint() {
    if (_phase == _Phase.revealed || _usedHint) return;
    setState(() => _usedHint = true);
    HapticFeedback.selectionClick();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }

  // ----------------------------------------------------------------- widgets

  Widget _buildTopBar() {
    final s = AppScope.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: s.leaveSession,
          icon: Icon(Icons.close_rounded, size: 26, color: AppColors.ink),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_index + 1) / widget.deck.length,
              minHeight: 7,
              color: AppColors.accent,
              backgroundColor: AppColors.sandSoft,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _StreakChip(streak: widget.stats.streak),
      ],
    );
  }

  Widget _buildWordCard() {
    final s = AppScope.of(context);
    final word = _word;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      decoration: appCardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.wordOn(_index + 1, widget.deck.length),
                style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.sandSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  s.wordNumber(word.id),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                right: 2,
                top: 2,
                child: Opacity(
                  opacity: .07,
                  child: Transform.rotate(
                    angle: -0.12,
                    child: Text(
                      '记',
                      style: TextStyle(
                        fontSize: 108,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .9, end: 1).animate(animation),
                    child: child,
                  ),
                ),
                child: SizedBox(
                  key: ValueKey<int>(word.id),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      word.hanzi,
                      style: TextStyle(
                        fontSize: 104,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            s.whatPinyin,
            style: TextStyle(fontSize: 14.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    final s = AppScope.of(context);
    final hintLetter = _word.answers.isEmpty ? '' : _word.answers.first.substring(0, 1);
    final withTones = widget.stats.requireTones;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          enableSuggestions: false,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.ink,
          ),
          decoration: pinyinInputDecoration(
            label: s.pinyinLabel,
            hint: _usedHint ? '' : s.pinyinHint(withTones),
          ),
          onSubmitted: (_) => _validate(),
        ),
        if (withTones) ...[
          const SizedBox(height: 10),
          _buildTonePad(),
        ],
        if (_usedHint) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.sandSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_rounded,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.hintLetter(hintLetter),
                    style: TextStyle(
                        fontSize: 13, color: AppColors.ink, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _phase == _Phase.answering ? _hint : null,
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
                label: Text(s.hint),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  disabledForegroundColor: AppColors.inkSoft,
                  side: BorderSide(color: AppColors.sand),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _validate,
                style: primaryButtonStyle(context),
                icon: const Icon(Icons.check_rounded),
                label: Text(s.check),
              ),
            ),
          ],
        ),
        Center(
          child: TextButton(
            onPressed: () => _validate(skip: true),
            child: Text(
              s.dontKnow,
              style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  /// Pavé de tons : insère une voyelle accentuée à la position du curseur.
  ///
  /// Un clavier standard ne produit pas d'accents toniques ; ce pavé permet de
  /// saisir `nǐ`, `hǎo`, `nǚ` sans quitter l'écran. La notation chiffrée
  /// (`ni3`) reste possible directement au clavier.
  Widget _buildTonePad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.sandSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var g = 0; g < _toneGroups.length; g++) ...[
              if (g > 0) const SizedBox(width: 8),
              for (var t = 0; t < _toneGroups[g].length; t++) ...[
                if (t > 0) const SizedBox(width: 2),
                _ToneKey(
                  label: _toneGroups[g][t],
                  onTap: () => _insertTone(_toneGroups[g][t]),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static const List<List<String>> _toneGroups = [
    ['ā', 'á', 'ǎ', 'à'],
    ['ē', 'é', 'ě', 'è'],
    ['ī', 'í', 'ǐ', 'ì'],
    ['ō', 'ó', 'ǒ', 'ò'],
    ['ū', 'ú', 'ǔ', 'ù'],
    ['ǖ', 'ǘ', 'ǚ', 'ǜ'],
  ];

  static const Map<String, String> _toneBase = {
    'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
    'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
    'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
    'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
    'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
    'ǖ': 'u', 'ǘ': 'u', 'ǚ': 'u', 'ǜ': 'u',
  };

  void _insertTone(String toned) {
    final value = _controller.value;
    final text = value.text;
    final collapsed = !value.selection.isValid ||
        value.selection.start == value.selection.end;
    var start = value.selection.isValid && value.selection.start >= 0
        ? value.selection.start
        : text.length;
    var end = value.selection.isValid && value.selection.end >= 0
        ? value.selection.end
        : start;

    // Si la voyelle de base est juste avant le curseur, on la remplace :
    // « ai » puis [à] donne « ài » et non « aià ».
    if (collapsed) {
      final base = _toneBase[toned];
      for (var i = start - 1; i >= 0 && start - i <= 5; i--) {
        final ch = text[i];
        if (ch == ' ' || ch == "'" || ch == '\u2019') break;
        // Chiffre de ton : on le laisse tel quel et on continue à remonter.
        // NB : String.compareTo ne renvoie qu'un signe (-1/0/1), pas une
        // différence de codes — comparer à 9 serait toujours vrai.
        final code = ch.codeUnitAt(0);
        if (code >= 0x30 && code <= 0x39) continue;
        if (ch == base) {
          start = i;
          end = i + 1;
          break;
        }
      }
    }

    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, toned),
      selection: TextSelection.collapsed(offset: start + toned.length),
    );
    HapticFeedback.selectionClick();
    _focusNode.requestFocus();
  }

  Widget _buildResult() {
    final s = AppScope.of(context);
    final word = _word;
    final reveal = s.lang;

    // Trois états : correct, refusé, ou réponse demandée (« Je ne sais pas »).
    // Le troisième n'est pas une faute : on montre simplement la réponse.
    final Color color;
    final IconData icon;
    final String verdict;
    if (_correct) {
      color = AppColors.success;
      icon = Icons.check_circle_rounded;
      verdict = s.correctAnswer;
    } else if (_skipped) {
      color = AppColors.inkSoft;
      icon = Icons.visibility_outlined;
      verdict = s.revealAnswer;
    } else {
      color = AppColors.danger;
      icon = Icons.cancel_rounded;
      verdict = s.notQuite;
    }
    final background = _correct
        ? AppColors.correctSoft
        : (_skipped ? AppColors.sandSoft : AppColors.dangerSoft);

    // Le niveau 7-9 n'a aucune traduction : sa « signification » EST le
    // pinyin, qui n'a donc plus à être répété dans le cadre de correction.
    final showPinyinRow = !word.meaningIsPinyin(reveal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: appCardDecoration(color: background),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      verdict,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  if (_correct && widget.stats.streak > 1) ...[
                    Icon(Icons.local_fire_department_rounded,
                        size: 18, color: AppColors.accent),
                    Text(
                      ' ${widget.stats.streak}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
              if (!_correct && !_skipped && _toneError) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded,
                        size: 16, color: AppColors.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.toneWrong,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (!_correct && !_skipped && _submitted.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  s.yourAnswer(_submitted),
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.inkSoft,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
              if (showPinyinRow) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      s.pinyinIs,
                      style: TextStyle(fontSize: 15, color: AppColors.inkSoft),
                    ),
                    Flexible(
                      child: Text(
                        word.pinyin,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MeaningCard(word: word, strings: s),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _next,
          style: primaryButtonStyle(context),
          icon: Icon(
              _isLast ? Icons.emoji_events_outlined : Icons.arrow_forward_rounded),
          label: Text(_isLast ? s.seeResult : s.nextWord),
        ),
      ],
    );
  }
}

class _MeaningCard extends StatelessWidget {
  const _MeaningCard({required this.word, required this.strings});

  final Word word;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final pos = word.pos(strings.lang);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                strings.meaningLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(width: 10),
              if (pos.isNotEmpty)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.sandSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      pos,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            word.meaning(strings.lang),
            style: TextStyle(
              fontSize: 20,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToneKey extends StatelessWidget {
  const _ToneKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.sand),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded,
              size: 18, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
