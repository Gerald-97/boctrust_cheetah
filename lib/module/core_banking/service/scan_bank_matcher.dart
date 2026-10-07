import '../model/interbank_models.dart';
import '../model/scan_text_models.dart';

/// Reviewed whole-token aliases for banks people write differently from the
/// name Core lists, mapped to that name. An alias only counts when its bank is
/// in the available list. Audit against the live bank list when it changes.
const _aliases = {
  'gtbank': 'Guaranty Trust Bank',
  'gtco': 'Guaranty Trust Bank',
  'fcmb': 'First City Monument Bank',
  'uba': 'United Bank for Africa',
  'boctrust': 'BOCTRUST',
};

const _suffixes = {'plc', 'ltd', 'limited'};
const _generic = {
  'bank',
  'microfinance',
  'account',
  'name',
  'number',
  'of',
  'for',
  'and',
  'the',
};

// Short tokens are too noisy to compare by similarity.
const _minSimilarLength = 4;

final _digitRun = RegExp(r'\d+');
final _nonLetters = RegExp(r'[^a-z]+');

/// Resolves OCR bank text against [availableBanks], which is the output of
/// `scanToPayBanks`. Only exact or alias hits to a single bank are `unique`;
/// near matches are suggestions after them and never make a match unique.
BankMatch matchScanBanks(
  List<String> bankTextLines,
  List<CommercialBank> availableBanks,
) {
  final names = [
    for (final bank in availableBanks) (bank, _tokens(bank.name)),
  ].where((entry) => entry.$2.isNotEmpty).toList();

  final hits = <String, CommercialBank>{};
  final suggestions = <String, CommercialBank>{};
  for (final line in bankTextLines) {
    final tokens = _tokens(line);
    final spans = <(int, int, CommercialBank)>[];
    for (final (bank, name) in names) {
      for (var i = 0; i + name.length <= tokens.length; i++) {
        if (_sameAt(tokens, name, i)) spans.add((i, i + name.length, bank));
      }
      for (final entry in _aliases.entries) {
        if (_tokens(entry.value).join(' ') != name.join(' ')) continue;
        for (var i = 0; i < tokens.length; i++) {
          if (tokens[i] == entry.key) spans.add((i, i + 1, bank));
        }
      }
    }
    final kept = [
      for (final span in spans)
        if (!spans.any(
          (other) =>
              other.$1 < span.$2 &&
              span.$1 < other.$2 &&
              other.$2 - other.$1 > span.$2 - span.$1,
        ))
          span.$3,
    ];
    for (final bank in kept) {
      hits.putIfAbsent(bank.code, () => bank);
    }
    if (kept.isNotEmpty) continue;
    for (final (bank, name) in names) {
      if (_isSimilar(tokens, name)) {
        suggestions.putIfAbsent(bank.code, () => bank);
      }
    }
  }

  suggestions.removeWhere((code, _) => hits.containsKey(code));
  final candidates = [...hits.values, ...suggestions.values];
  final status = hits.length == 1
      ? BankMatchStatus.unique
      : candidates.isEmpty
      ? BankMatchStatus.none
      : BankMatchStatus.ambiguous;
  return BankMatch(status, List.unmodifiable(candidates));
}

List<String> _tokens(String text) {
  final tokens = text
      .toLowerCase()
      .replaceAll(_digitRun, ' ')
      .split(_nonLetters)
      .where((token) => token.isNotEmpty)
      .expand((token) => token == 'mfb' ? ['microfinance', 'bank'] : [token])
      .toList();
  while (tokens.isNotEmpty && _suffixes.contains(tokens.last)) {
    tokens.removeLast();
  }
  return tokens;
}

bool _sameAt(List<String> tokens, List<String> name, int start) {
  for (var i = 0; i < name.length; i++) {
    if (tokens[start + i] != name[i]) return false;
  }
  return true;
}

bool _isSimilar(List<String> lineTokens, List<String> name) {
  for (final word in name) {
    if (word.length < _minSimilarLength || _generic.contains(word)) continue;
    final allowed = word.length <= 7 ? 1 : 2;
    for (final token in lineTokens) {
      if (token.length < _minSimilarLength || _generic.contains(token)) {
        continue;
      }
      if (_distance(token, word) <= allowed) return true;
    }
  }
  return false;
}

int _distance(String a, String b) {
  var previous = List.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = [i, ...List.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = [
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}
