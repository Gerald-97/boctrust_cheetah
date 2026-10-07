import '../model/scan_text_models.dart';

const _accountLength = 10;

// A token of digits and the letters OCR confuses with them, not attached to
// other letters or digits.
final _token = RegExp(r'(?<![A-Za-z0-9|])[0-9OoIl|]+(?![A-Za-z0-9|])');
final _lookAlikes = RegExp(r'[OoIl|]');
final _separators = RegExp(r'^[ \-]+$');
final _digitRun = RegExp(r'\d+');
final _spaces = RegExp(r'\s+');

/// Pulls ten-digit account numbers and bank-name text out of OCR lines.
ScanCandidates extractScanCandidates(List<RecognizedLine> lines) {
  final ordered = [...lines]
    ..sort((a, b) {
      final byTop = a.box.top.compareTo(b.box.top);
      return byTop != 0 ? byTop : a.box.left.compareTo(b.box.left);
    });

  final accounts = <String>{};
  final bankText = <String>[];
  for (final line in ordered) {
    accounts.addAll(_accountsIn(line.text));
    final text = line.text.replaceAll(_digitRun, ' ').replaceAll(_spaces, ' ');
    if (text.trim().isNotEmpty) bankText.add(text.trim());
  }
  return ScanCandidates(
    accountNumbers: List.unmodifiable(accounts),
    bankTextLines: List.unmodifiable(bankText),
  );
}

Iterable<String> _accountsIn(String text) sync* {
  final runs = <StringBuffer>[];
  var previousEnd = -1;
  for (final match in _token.allMatches(text)) {
    final token = match[0]!;
    final letters = _lookAlikes.allMatches(token).length;
    // Only a token with real digits and at most two look-alikes is a number.
    if (letters > 2 || letters == token.length) {
      previousEnd = -1;
      continue;
    }
    final joined =
        previousEnd >= 0 &&
        _separators.hasMatch(text.substring(previousEnd, match.start));
    if (!joined) runs.add(StringBuffer());
    runs.last.write(
      token.replaceAll(RegExp('[Oo]'), '0').replaceAll(RegExp(r'[Il|]'), '1'),
    );
    previousEnd = match.end;
  }
  for (final run in runs) {
    if (run.length == _accountLength) yield run.toString();
  }
}
