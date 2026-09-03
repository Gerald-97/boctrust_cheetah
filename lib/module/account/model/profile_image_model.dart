import 'package:equatable/equatable.dart';

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);

/// A short-lived signed URL for the user's private profile image.
///
/// Held in memory only. It is never written to preferences or secure storage:
/// it is a bearer-equivalent credential for the image object, and persisting it
/// would outlive the session it was issued for.
class ProfileImageSignedUrlData extends Equatable {
  ProfileImageSignedUrlData({
    required this.imageUrl,
    required this.expiresInSeconds,
    DateTime? fetchedAtUtc,
  }) : fetchedAtUtc = fetchedAtUtc ?? DateTime.now().toUtc();

  factory ProfileImageSignedUrlData.fromJson(Object? value) {
    final json = _map(value);
    final imageUrl = json['imageUrl']! as String;
    final expiresInSeconds = (json['expiresInSeconds']! as num).toInt();

    // Reject anything that is not a usable HTTPS URL rather than handing a
    // plaintext or malformed URL to the image loader.
    final parsed = Uri.tryParse(imageUrl);
    if (parsed == null || parsed.scheme != 'https' || !parsed.hasAuthority) {
      throw const FormatException('Signed profile image URL must be HTTPS.');
    }
    if (expiresInSeconds <= 0) {
      throw const FormatException(
        'Signed profile image URL expiry must be positive.',
      );
    }

    return ProfileImageSignedUrlData(
      imageUrl: imageUrl,
      expiresInSeconds: expiresInSeconds,
    );
  }

  final String imageUrl;
  final int expiresInSeconds;

  /// When this URL was received, used to compute expiry locally.
  final DateTime fetchedAtUtc;

  /// Treated as expired slightly early so an image load does not start against
  /// a URL that lapses mid-request.
  static const _safetyMargin = Duration(seconds: 30);

  DateTime get expiresAtUtc =>
      fetchedAtUtc.add(Duration(seconds: expiresInSeconds));

  bool get isExpired =>
      DateTime.now().toUtc().isAfter(expiresAtUtc.subtract(_safetyMargin));

  @override
  List<Object?> get props => [imageUrl, expiresInSeconds, fetchedAtUtc];
}
