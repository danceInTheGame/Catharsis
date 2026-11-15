import 'dart:math';

import '../models/word.dart';

/// Mots disponibles pour l'entraînement : tous les niveaux jusqu'à [maxLevel].
///
/// La sélection des réglages est cumulative (« jusqu'au niveau N »).
List<Word> selectWords(List<Word> words, int maxLevel) =>
    words.where((w) => w.level <= maxLevel).toList(growable: false);

/// Construit un paquet de [size] mots.
///
/// Les mots qui ne sont pas encore maîtrisés passent en premier (dans un
/// ordre aléatoire) ; des rappels de mots déjà acquis viennent compléter la
/// session s'il en reste de la place.
List<Word> buildDeck(
  List<Word> words, {
  required Set<int> masteredIds,
  required int size,
  Random? random,
}) {
  final rng = random ?? Random();
  final unseen = words.where((w) => !masteredIds.contains(w.id)).toList()
    ..shuffle(rng);
  final seen = words.where((w) => masteredIds.contains(w.id)).toList()
    ..shuffle(rng);

  final deck = <Word>[...unseen, ...seen];
  return deck.length <= size ? deck : deck.sublist(0, size);
}
