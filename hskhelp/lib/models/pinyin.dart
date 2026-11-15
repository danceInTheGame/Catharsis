import 'dart:math' as math;

import '../data/syllables.dart';

class Pinyin {
  static const int _maxSyllable = 6;
  static const int _maxForms = 48;

  static Set<String> tonedForms(String reading) {
    final out = <String>{};
    for (final r in reading.split('/')) {
      final s = _segmentReading(r);
      if (s != null) {
        out.addAll(s);
      }
    }
    return out;
  }

  static Set<String> tonelessForms(String reading) {
    final toned = tonedForms(reading);
    return toned.map(_stripTones).toSet();
  }

  static Set<String> withSandhi(Set<String> forms) {
    final out = <String>{...forms};
    for (final f in List<String>.of(forms)) {
      if (f.startsWith('bu2')) {
        out.add('bu4${f.substring(3)}');
      }
      if (f.startsWith('yi2')) {
        out.add('yi1${f.substring(3)}');
      }
    }
    return out;
  }

  static Set<String>? _segmentReading(String reading) {
    final tokens = _tokenize(reading);
    if (tokens == null) return null;
    final segs = _syllabifyAll(tokens);
    if (segs.isEmpty) return null;
    final out = <String>{};
    for (final seg in segs) {
      out.addAll(_buildForms(tokens, seg));
      if (out.length >= _maxForms) break;
    }
    return out;
  }

  static String _stripTones(String s) {
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      if (code >= 0x30 && code <= 0x39) continue;
      b.write(s[i]);
    }
    return b.toString();
  }

  static bool _isAsciiLetter(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5a) || (code >= 0x61 && code <= 0x7a);
  }

  static bool _isSeparator(String ch) {
    switch (ch) {
      case ' ':
      case '\t':
      case '\'':
      case '’':
      case '`':
      case '"':
      case '-':
      case '–':
      case '—':
        return true;
      default:
        return false;
    }
  }

  static _Tokens? _tokenize(String raw) {
    final letters = <String>[];
    final accent = <int>[];
    final digit = <int>[];
    final breaks = <int>[];
    var pendingBreak = false;
    var justSawDigit = false;

    final text = raw.toLowerCase().replaceAll('u:', 'ü');
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_isSeparator(ch)) {
        if (letters.isNotEmpty) pendingBreak = true;
        justSawDigit = false;
        continue;
      }
      final code = ch.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) {
        if (letters.isNotEmpty) {
          digit[digit.length - 1] = int.parse(ch);
        }
        justSawDigit = true;
        continue;
      }
      String? base = _baseOf[ch];
      var tone = 0;
      if (base == null && _isAsciiLetter(ch)) {
        base = ch;
      } else if (base != null) {
        tone = _toneOf[ch] ?? 0;
      }
      if (base == null) {
        justSawDigit = false;
        continue;
      }
      if ((pendingBreak || justSawDigit) && letters.isNotEmpty) {
        breaks.add(letters.length);
        pendingBreak = false;
        justSawDigit = false;
      }
      pendingBreak = false;
      justSawDigit = false;
      letters.add(base);
      accent.add(tone);
      digit.add(0);
    }
    if (letters.isEmpty) return null;
    return _Tokens(letters, accent, digit, breaks);
  }

  static String _syllableText(_Tokens tokens, int start, int end) {
    final b = StringBuffer();
    for (var i = start; i < end; i++) {
      b.write(tokens.letters[i]);
    }
    return b.toString();
  }

  static int _toneOfRange(_Tokens tokens, int start, int end, {int? erhuaSuffixStart}) {
    var tone = 0;
    for (var i = start; i < end; i++) {
      if (tokens.accent[i] != 0) tone = tokens.accent[i];
    }
    if (tone != 0) return tone;
    for (var i = end - 1; i >= start; i--) {
      if (tokens.digit[i] != 0) return tokens.digit[i];
    }
    if (erhuaSuffixStart != null) {
      for (var i = erhuaSuffixStart; i < tokens.digit.length && i < tokens.accent.length; i++) {
        if (tokens.accent[i] != 0) return tokens.accent[i];
        if (tokens.digit[i] != 0) return tokens.digit[i];
      }
    }
    return 5;
  }

  static List<_Seg> _syllabifyAll(_Tokens tokens) {
    final breaks = tokens.breaks;
    if (breaks.isEmpty) {
      return _segmentRangeAll(tokens.letters, 0, tokens.letters.length,
          allowErhua: true);
    }

    final bounds = <int>[0, ...breaks, tokens.letters.length];
    final blockSegments = <List<_Seg>>[];
    for (var b = 0; b < bounds.length - 1; b++) {
      final segs = _segmentRangeAll(
        tokens.letters,
        bounds[b],
        bounds[b + 1],
        allowErhua: b == bounds.length - 2,
      );
      if (segs.isEmpty) {
        return _segmentRangeAll(tokens.letters, 0, tokens.letters.length,
            allowErhua: true);
      }
      blockSegments.add(segs);
    }
    final results = <_Seg>[];
    void dfs(int idx, List<_Syl> current, bool lastErhua) {
      if (idx == blockSegments.length) {
        results.add(_Seg(List<_Syl>.of(current), lastErhua));
        return;
      }
      if (results.length >= _maxForms) return;
      for (final seg in blockSegments[idx]) {
        final isLast = idx == blockSegments.length - 1;
        final newErhua = isLast ? seg.erhua : lastErhua;
        current.addAll(seg.syllables);
        dfs(idx + 1, current, newErhua);
        current.removeRange(
            current.length - seg.syllables.length, current.length);
      }
    }
    dfs(0, <_Syl>[], false);
    return results;
  }

  static List<_Seg> _segmentRangeAll(
    List<String> letters,
    int from,
    int to, {
    required bool allowErhua,
  }) {
    final direct = _dpAll(letters, from, to);
    if (direct.isNotEmpty) {
      return direct.map((s) => _Seg(s, false)).toList(growable: false);
    }
    if (allowErhua && to - from > 1 && letters[to - 1] == 'r') {
      final without = _dpAll(letters, from, to - 1);
      if (without.isNotEmpty) {
        return without.map((s) => _Seg(s, true)).toList(growable: false);
      }
    }
    return const <_Seg>[];
  }

  static List<List<_Syl>> _dpAll(List<String> letters, int from, int to) {
    final n = to - from;
    if (n == 0) return const <List<_Syl>>[];
    final word = letters.sublist(from, to).join();
    const inf = 0x3fffffff;
    final cost = List<int>.filled(n + 1, inf);
    cost[n] = 0;
    for (var i = n - 1; i >= 0; i--) {
      final hi = math.min(n, i + _maxSyllable);
      for (var j = i + 1; j <= hi; j++) {
        final substr = word.substring(i, j);
        if (kPinyinSyllables.contains(substr) && 1 + cost[j] < cost[i]) {
          cost[i] = 1 + cost[j];
        }
      }
    }
    if (cost[0] >= inf) return const <List<_Syl>>[];
    final results = <List<_Syl>>[];
    void backtrack(int index, List<_Syl> path) {
      if (index == n) {
        results.add(List<_Syl>.of(path));
        return;
      }
      if (results.length >= _maxForms) return;
      final hi = math.min(n, index + _maxSyllable);
      for (var j = hi; j > index; j--) {
        final substr = word.substring(index, j);
        if (kPinyinSyllables.contains(substr) && 1 + cost[j] == cost[index]) {
          path.add(_Syl(from + index, from + j));
          backtrack(j, path);
          path.removeLast();
          if (results.length >= _maxForms) return;
        }
      }
    }
    backtrack(0, <_Syl>[]);
    return results;
  }

  static Set<String> _buildForms(_Tokens tokens, _Seg seg) {
    final syllables = seg.syllables;
    final out = <String>{};
    final length = tokens.letters.length;
    final glued = StringBuffer();
    for (var i = 0; i < syllables.length; i++) {
      final syl = syllables[i];
      final end = (seg.erhua && i == syllables.length - 1) ? length : syl.end;
      glued.write(_syllableText(tokens, syl.start, end));
      glued.write(_toneOfRange(tokens, syl.start, end,
          erhuaSuffixStart: (seg.erhua && i == syllables.length - 1) ? syl.end : null));
    }
    out.add(glued.toString());
    if (seg.erhua && syllables.isNotEmpty) {
      final split = StringBuffer();
      for (var i = 0; i < syllables.length; i++) {
        final syl = syllables[i];
        final endSyl = syl.end;
        split.write(_syllableText(tokens, syl.start, endSyl));
        split.write(_toneOfRange(tokens, syl.start, endSyl));
      }
      split.write('er5');
      out.add(split.toString());
    }
    return out;
  }
}

class _Tokens {
  const _Tokens(this.letters, this.accent, this.digit, this.breaks);

  final List<String> letters;
  final List<int> accent;
  final List<int> digit;
  final List<int> breaks;
}

class _Syl {
  const _Syl(this.start, this.end);

  final int start;
  final int end;
}

class _Seg {
  const _Seg(this.syllables, this.erhua);

  final List<_Syl> syllables;
  final bool erhua;
}

const Map<String, String> _baseOf = {
  'ā': 'a',
  'á': 'a',
  'ǎ': 'a',
  'à': 'a',
  'ē': 'e',
  'é': 'e',
  'ě': 'e',
  'è': 'e',
  'ī': 'i',
  'í': 'i',
  'ǐ': 'i',
  'ì': 'i',
  'ō': 'o',
  'ó': 'o',
  'ǒ': 'o',
  'ò': 'o',
  'ū': 'u',
  'ú': 'u',
  'ǔ': 'u',
  'ù': 'u',
  'ü': 'u',
  'ǘ': 'u',
  'ǚ': 'u',
  'ǜ': 'u',
  'ń': 'n',
  'ň': 'n',
  'ǹ': 'n',
  'm': 'm',
  'n': 'n',
  'g': 'g',
  'a': 'a',
  'e': 'e',
  'i': 'i',
  'o': 'o',
  'u': 'u',
  'v': 'u',
  'u:': 'u',
};

const Map<String, int> _toneOf = {
  'ā': 1,
  'á': 2,
  'ǎ': 3,
  'à': 4,
  'ē': 1,
  'é': 2,
  'ě': 3,
  'è': 4,
  'ī': 1,
  'í': 2,
  'ǐ': 3,
  'ì': 4,
  'ō': 1,
  'ó': 2,
  'ǒ': 3,
  'ò': 4,
  'ū': 1,
  'ú': 2,
  'ǔ': 3,
  'ù': 4,
  'ǘ': 2,
  'ǚ': 3,
  'ǜ': 4,
  'ń': 2,
  'ň': 3,
  'ǹ': 4,
};
