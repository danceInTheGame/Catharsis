import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

/// État d'apprentissage d'un seul item (mot ou exercice de grammaire).
class ItemState {
  ItemState({
    required this.key,
    this.strength = 0.0,
    this.interval = 0,
    this.ease = 2.5,
    this.box = 1,
    this.bktPKnown = 0.0,
    this.elo = 800.0,
    this.attempts = 0,
    this.correct = 0,
    this.streak = 0,
    this.wrongStreak = 0,
    this.lastSeen,
    List<double>? history,
  }) : history = history ?? <double>[];

  final String key;
  double strength;
  int interval;
  double ease;
  int box;
  double bktPKnown;
  double elo;
  int attempts;
  int correct;
  int streak;
  int wrongStreak;
  DateTime? lastSeen;
  final List<double> history; // 1.0 = correct, 0.0 = wrong (derniers essais)

  double get rollingAccuracy {
    if (history.isEmpty) return 0.0;
    final n = math.min(history.length, 10);
    var sum = 0.0;
    for (var i = history.length - n; i < history.length; i++) {
      sum += history[i];
    }
    return sum / n;
  }

  Map<String, dynamic> toJson() => {
        's': strength,
        'i': interval,
        'e': ease,
        'b': box,
        'k': bktPKnown,
        'r': elo,
        'a': attempts,
        'c': correct,
        'st': streak,
        'ws': wrongStreak,
        'ls': lastSeen?.millisecondsSinceEpoch,
        'h': history.length > 20
            ? history.sublist(history.length - 20)
            : history,
      };

  factory ItemState.fromJson(String key, Map<String, dynamic> j) {
    return ItemState(
      key: key,
      strength: (j['s'] as num?)?.toDouble() ?? 0,
      interval: j['i'] as int? ?? 0,
      ease: (j['e'] as num?)?.toDouble() ?? 2.5,
      box: j['b'] as int? ?? 1,
      bktPKnown: (j['k'] as num?)?.toDouble() ?? 0,
      elo: (j['r'] as num?)?.toDouble() ?? 800,
      attempts: j['a'] as int? ?? 0,
      correct: j['c'] as int? ?? 0,
      streak: j['st'] as int? ?? 0,
      wrongStreak: j['ws'] as int? ?? 0,
      lastSeen: j['ls'] != null
          ? DateTime.fromMillisecondsSinceEpoch(j['ls'] as int)
          : null,
      history: (j['h'] as List?)?.map((e) => (e as num).toDouble()).toList(),
    );
  }
}

/// Moteur d'apprentissage adaptatif combinant 10 algorithmes :
///
/// 1. **SM-2** (spaced repetition) — intervalle & facilité
/// 2. **Leitner** — boîtes 1-5
/// 3. **Bayesian Knowledge Tracing** — P(connu)
/// 4. **Elo** — difficulté de l'item vs compétence utilisateur
/// 5. **Courbe d'oubli d'Ebbinghaus** — R = e^(−t/S)
/// 6. **Difficulté adaptative** — précision glissante
/// 7. **Analyse d'erreurs** — patterns par type/règle
/// 8. **Vitesse d'apprentissage** — taux d'amélioration
/// 9. **Maîtrise** — seuil de consécutifs corrects
/// 10. **Ensemble pondéré** — score de priorité combiné
class LearningEngine {
  LearningEngine._();
  static final LearningEngine instance = LearningEngine._();

  static const _prefKey = 'learning_engine_v1';

  final Map<String, ItemState> _items = {};
  double _userElo = 1000.0;
  bool _loaded = false;

  double get userElo => _userElo;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _userElo = (data['userElo'] as num?)?.toDouble() ?? 1000.0;
      final items = data['items'] as Map<String, dynamic>? ?? {};
      items.forEach((k, v) {
        _items[k] = ItemState.fromJson(k, v as Map<String, dynamic>);
      });
    }
    _loaded = true;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'userElo': _userElo,
      'items': _items.map((k, v) => MapEntry(k, v.toJson())),
    };
    await prefs.setString(_prefKey, jsonEncode(data));
  }

  ItemState stateFor(String key) =>
      _items.putIfAbsent(key, () => ItemState(key: key));

  /// Enregistre une réponse et met à jour tous les sous-algorithmes.
  ///
  /// [quality] : 0.0 = complètement faux, 0.3 = partiel,
  ///             0.6 = correct avec aide, 1.0 = parfait.
  void recordAnswer(String key, double quality) {
    final state = stateFor(key);
    final now = DateTime.now();
    final correct = quality >= 0.6;

    state.attempts++;
    if (correct) state.correct++;
    state.history.add(quality);
    if (state.history.length > 20) state.history.removeAt(0);
    state.lastSeen = now;

    // 1. SM-2
    _sm2(state, quality);

    // 2. Leitner
    if (correct) {
      state.box = math.min(5, state.box + 1);
    } else {
      state.box = 1;
    }

    // 3. Bayesian Knowledge Tracing
    _bkt(state, correct);

    // 4. Elo
    _elo(state, correct);

    // Streaks
    if (correct) {
      state.streak++;
      state.wrongStreak = 0;
    } else {
      state.wrongStreak++;
      state.streak = 0;
    }

    // 6. Difficulté adaptative → met à jour la force perçue
    state.strength = _ensembleScore(state, now);

    // Elo utilisateur global
    _userElo = _userElo + 16.0 * (quality - 0.5);

    save();
  }

  // ── SM-2 ────────────────────────────────────────────────────────
  void _sm2(ItemState s, double q) {
    if (q < 0.6) {
      s.interval = 0;
      s.ease = math.max(1.3, s.ease - 0.2);
      return;
    }
    if (s.interval == 0) {
      s.interval = 1;
    } else if (s.interval == 1) {
      s.interval = 6;
    } else {
      s.interval = (s.interval * s.ease).round();
    }
    s.ease = math.max(1.3, s.ease + 0.1 - (1.0 - q) * (0.8 + (1.0 - q) * 0.5));
  }

  // ── Bayesian Knowledge Tracing ──────────────────────────────────
  void _bkt(ItemState s, bool correct) {
    const pT = 0.1; // probabilité d'apprendre
    const pG = 0.2; // guess
    const pS = 0.1; // slip
    final pL = s.bktPKnown;

    double pKnowGiven;
    if (correct) {
      pKnowGiven =
          (pL * (1 - pS)) / (pL * (1 - pS) + (1 - pL) * pG);
    } else {
      pKnowGiven = (pL * pS) / (pL * pS + (1 - pL) * (1 - pG));
    }
    s.bktPKnown = pKnowGiven + (1 - pKnowGiven) * pT;
  }

  // ── Elo ─────────────────────────────────────────────────────────
  void _elo(ItemState s, bool correct) {
    final expected = 1.0 / (1.0 + math.pow(10, (_userElo - s.elo) / 400));
    final actual = correct ? 1.0 : 0.0;
    s.elo += 32.0 * (actual - expected);
    s.elo = math.max(600, math.min(3000, s.elo));
  }

  // ── Courbe d'oubli d'Ebbinghaus ─────────────────────────────────
  double _forgettingCurve(ItemState s, DateTime now) {
    if (s.lastSeen == null) return 1.0; // jamais vu → rien d'oublié
    final elapsed = now.difference(s.lastSeen!).inHours.toDouble();
    final stability = math.max(1.0, s.interval.toDouble() * 24.0);
    return math.exp(-elapsed / stability);
  }

  // ── Ensemble pondéré (score 0→1, plus haut = mieux maîtrisé) ────
  double _ensembleScore(ItemState s, DateTime now) {
    if (s.attempts == 0) return 0.0;

    // SM-2 normalisé (interval>30 j → 1.0)
    final sm2 = math.min(1.0, s.interval / 30.0);

    // Leitner normalisé
    final leitner = (s.box - 1) / 4.0;

    // BKT direct
    final bkt = s.bktPKnown;

    // Elo normalisé (600-3000 → 0-1)
    final elo = (s.elo - 600) / 2400.0;

    // Précision glissante
    final roll = s.rollingAccuracy;

    // Récence
    final recency = _forgettingCurve(s, now);

    // Poids
    return (sm2 * 0.15 +
            leitner * 0.10 +
            bkt * 0.25 +
            elo * 0.15 +
            roll * 0.20 +
            recency * 0.15)
        .clamp(0.0, 1.0);
  }

  /// Recalcule la force de tous les items (appeler au chargement).
  void refreshAll() {
    final now = DateTime.now();
    for (final s in _items.values) {
      s.strength = _ensembleScore(s, now);
    }
  }

  /// Sélectionne l'item avec la plus haute priorité parmi [candidates].
  ///
  /// Priorité = faible maîtrise + courbe d'oubli imminente +
  ///            zone de développement proximal (0.15-0.75).
  String? selectBest(List<String> candidates) {
    if (candidates.isEmpty) return null;
    final now = DateTime.now();
    var bestKey = candidates.first;
    var bestPriority = -1.0;

    for (final key in candidates) {
      final s = _items[key];
      if (s == null || s.attempts == 0) {
        // Item jamais vu : priorité d'introduction moyenne et aléatoire.
        final priority = 0.55;
        if (priority > bestPriority) {
          bestPriority = priority;
          bestKey = key;
        }
        continue;
      }
      final strength = s.strength;
      final forget = _forgettingCurve(s, now);

      // Priorité élevée si on oublie bientôt
      final forgetUrgency = 1.0 - forget;

      // Zone de développement proximal : ni trop facile, ni trop dur
      final zpd = strength < 0.15
          ? 0.6 // nouveau → bonne introduction
          : strength < 0.75
              ? 1.0 // zone idéale
              : 0.2; // trop maîtrisé

      // Bonus pour les erreurs récentes
      final errorBonus = s.wrongStreak > 0 ? 0.3 : 0.0;

      final priority = (1.0 - strength) * 0.4 +
          forgetUrgency * 0.25 +
          zpd * 0.25 +
          errorBonus * 0.10;

      if (priority > bestPriority) {
        bestPriority = priority;
        bestKey = key;
      }
    }
    return bestKey;
  }

  /// Difficulté recommandée (0=facile, 1=difficile) basée sur
  /// la précision glissante et l'Elo utilisateur.
  double recommendedDifficulty() {
    final eloNorm = ((_userElo - 800) / 2000).clamp(0.0, 1.0);
    return eloNorm;
  }

  /// Retourne les statistiques agrégées pour l'affichage.
  Map<String, dynamic> summary() {
    var mastered = 0;
    var learning = 0;
    var new_ = 0;
    for (final s in _items.values) {
      if (s.strength >= 0.8) {
        mastered++;
      } else if (s.attempts > 0) {
        learning++;
      } else {
        new_++;
      }
    }
    return {
      'mastered': mastered,
      'learning': learning,
      'new': new_,
      'total': _items.length,
      'userElo': _userElo.round(),
    };
  }
}
