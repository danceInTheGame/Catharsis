import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/word.dart';

/// Charge le lexique embarqué (généré à partir des 7 PDF HSK, tous niveaux).
class WordRepository {
  static const String assetPath = 'assets/vocab.json';

  List<Word> _cache = const [];

  Future<List<Word>> load() async {
    if (_cache.isNotEmpty) return _cache;
    final raw = await rootBundle.loadString(assetPath);
    final list = jsonDecode(raw) as List<dynamic>;
    final words = list
        .map((e) => Word.fromJson(e as Map<String, dynamic>))
        .toList(growable: true)
      ..sort((a, b) => a.id.compareTo(b.id));
    _cache = List.unmodifiable(words);
    return _cache;
  }
}
