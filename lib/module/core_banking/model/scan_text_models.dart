import 'package:equatable/equatable.dart';

import 'interbank_models.dart';

/// A rectangle in `[0,1]` with a top-left origin, measured on the upright
/// image after EXIF orientation: `(0,0)` is its top-left pixel and `(1,1)` its
/// bottom-right.
class ScanTextBox extends Equatable {
  const ScanTextBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  @override
  List<Object?> get props => [left, top, width, height];
}

/// One line of text recognized on a scanned image.
class RecognizedLine extends Equatable {
  const RecognizedLine(this.text, this.box);

  final String text;
  final ScanTextBox box;

  @override
  List<Object?> get props => [text, box];
}

/// What a scan offers the customer to confirm. Nothing here is sent anywhere
/// until they confirm it.
class ScanCandidates extends Equatable {
  const ScanCandidates({
    required this.accountNumbers,
    required this.bankTextLines,
  });

  /// Distinct ten-digit numbers in reading order.
  final List<String> accountNumbers;

  /// Every recognized line with its digit runs removed, empty lines dropped.
  final List<String> bankTextLines;

  @override
  List<Object?> get props => [accountNumbers, bankTextLines];
}

enum BankMatchStatus {
  /// Exactly one supported bank was named.
  unique,

  /// Several banks were named, or only near matches were found.
  ambiguous,

  /// No supported bank was found.
  none,
}

/// The supported banks a scan's text points to, best first. Only
/// [BankMatchStatus.unique] is safe to preselect.
class BankMatch extends Equatable {
  const BankMatch(this.status, this.candidates);

  final BankMatchStatus status;
  final List<CommercialBank> candidates;

  @override
  List<Object?> get props => [status, candidates];
}
