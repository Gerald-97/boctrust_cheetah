import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';

/// A remote message reduced to what is safe to display and route.
///
/// Remote title, body and arbitrary data are never retained: the visible copy
/// is always [title] and [body], and only bounded `route`/`id` strings survive.
class NotificationPayload {
  const NotificationPayload._({
    required this.notificationId,
    required this.hasNotificationContent,
    this.route,
    this.id,
  });

  factory NotificationPayload.fromRemoteMessage(
    RemoteMessage message, {
    DateTime Function() now = DateTime.now,
  }) {
    final notification = message.notification;
    final messageId = message.messageId;
    return NotificationPayload._(
      notificationId: messageId != null && messageId.isNotEmpty
          ? stableId(messageId)
          : _positive(
              (message.sentTime ?? now()).millisecondsSinceEpoch & _mask,
            ),
      hasNotificationContent:
          notification != null &&
          ((notification.title?.trim().isNotEmpty ?? false) ||
              (notification.body?.trim().isNotEmpty ?? false)),
      route: _field(message.data['route']),
      id: _field(message.data['id']),
    );
  }

  static const title = 'BOCTRUST';
  static const body = 'You have a new notification.';
  static const maxFieldLength = 128;
  static const maxSerializedLength = 512;
  static const _mask = 0x7fffffff;

  final int notificationId;
  final bool hasNotificationContent;
  final String? route;
  final String? id;

  bool get isDisplayable =>
      hasNotificationContent || route != null || id != null;

  /// The local-notification tap payload, or null when there is nothing to
  /// route.
  String? toLocalPayload() {
    if (route == null && id == null) return null;
    return jsonEncode({'route': ?route, 'id': ?id});
  }

  /// Decodes a local-notification tap payload into the normalized
  /// `route`/`id` map, or null when it is absent, malformed or oversized.
  static Map<String, String>? decodeLocalPayload(String? raw) {
    if (raw == null || raw.isEmpty || raw.length > maxSerializedLength) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final route = _field(decoded['route']);
    final id = _field(decoded['id']);
    return {'route': ?route, 'id': ?id};
  }

  /// 32-bit FNV-1a of [value], masked to a positive non-zero int.
  static int stableId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return _positive(hash & _mask);
  }

  static int _positive(int value) => value == 0 ? 1 : value;

  static String? _field(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maxFieldLength) return null;
    return trimmed;
  }
}
