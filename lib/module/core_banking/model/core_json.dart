/// Lenient readers for Core replies whose schemas are not yet published
/// (banks, name enquiry, bill catalogues). A shape they cannot read yields
/// null or an empty list rather than a guess.
library;

/// Trimmed non-empty text, or null.
String? coreText(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

/// An identifier sent as text or as a whole number, as text.
String? coreId(Object? value) => switch (value) {
  final int number => '$number',
  final String text => coreText(text),
  _ => null,
};

/// The first of [keys] in [json] that reads as text.
String? coreFirstText(Map<Object?, Object?> json, List<String> keys) {
  for (final key in keys) {
    final value = coreText(json[key]);
    if (value != null) return value;
  }
  return null;
}

/// The rows of a list reply: [json] itself, or the list under the first of
/// [keys] when the list arrives wrapped in an object.
List<Object?> coreRows(Object? json, List<String> keys) {
  if (json is List) return json;
  if (json is Map) {
    for (final key in keys) {
      final rows = json[key];
      if (rows is List) return rows;
    }
  }
  throw const FormatException('Missing list.');
}
