import 'dart:convert';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/helper/notification_navigator.dart';
import 'package:boctrust_savings_loan/helper/notification_payload.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

RemoteMessage _message({
  String? messageId = 'msg-1',
  Map<String, dynamic> data = const {},
  RemoteNotification? notification,
  DateTime? sentTime,
}) => RemoteMessage(
  messageId: messageId,
  data: data,
  notification: notification,
  sentTime: sentTime,
);

void main() {
  group('NotificationPayload.fromRemoteMessage', () {
    test('keeps only bounded route and id strings', () {
      final payload = NotificationPayload.fromRemoteMessage(
        _message(
          data: {
            'route': AppRoutes.notifications,
            'id': 'txn-42',
            'balance': '₦1,000,000',
            'name': 'Ada Obi',
          },
        ),
      );
      expect(payload.isDisplayable, isTrue);
      expect(jsonDecode(payload.toLocalPayload()!), {
        'route': AppRoutes.notifications,
        'id': 'txn-42',
      });
    });

    test('keeps an unknown route for the navigator to fall back from', () {
      final payload = NotificationPayload.fromRemoteMessage(
        _message(data: {'route': '/not-a-route'}),
      );
      expect(payload.isDisplayable, isTrue);
      expect(
        NotificationNavigator.parse(
          NotificationPayload.decodeLocalPayload(payload.toLocalPayload())!,
        ).routeName,
        AppRoutes.notifications,
      );
    });

    test('drops non-string and oversized fields', () {
      final payload = NotificationPayload.fromRemoteMessage(
        _message(
          data: {
            'route': 42,
            'id': 'x' * (NotificationPayload.maxFieldLength + 1),
          },
        ),
      );
      expect(payload.route, isNull);
      expect(payload.id, isNull);
      expect(payload.isDisplayable, isFalse);
      expect(payload.toLocalPayload(), isNull);
    });

    test('drops empty strings', () {
      final payload = NotificationPayload.fromRemoteMessage(
        _message(data: {'route': '', 'id': '  '}),
      );
      expect(payload.isDisplayable, isFalse);
    });

    test('notification content alone is displayable with no tap payload', () {
      final payload = NotificationPayload.fromRemoteMessage(
        _message(
          notification: const RemoteNotification(
            title: 'Your balance is ₦50,000',
            body: 'Ada, you received ₦10,000',
          ),
        ),
      );
      expect(payload.isDisplayable, isTrue);
      expect(payload.toLocalPayload(), isNull);
    });

    test('an empty notification block is not displayable', () {
      final payload = NotificationPayload.fromRemoteMessage(
        _message(notification: const RemoteNotification()),
      );
      expect(payload.isDisplayable, isFalse);
    });

    test('an empty message is not displayable', () {
      expect(
        NotificationPayload.fromRemoteMessage(_message()).isDisplayable,
        isFalse,
      );
    });

    test('visible copy is always generic', () {
      expect(NotificationPayload.title, 'Cheetah');
      expect(NotificationPayload.body, 'You have a new notification.');
    });
  });

  group('notificationId', () {
    test('is a deterministic positive hash of the message id', () {
      final a = NotificationPayload.fromRemoteMessage(_message());
      final b = NotificationPayload.fromRemoteMessage(_message());
      final c = NotificationPayload.fromRemoteMessage(
        _message(messageId: 'msg-2'),
      );
      expect(a.notificationId, b.notificationId);
      expect(a.notificationId, isNot(c.notificationId));
      expect(a.notificationId, inInclusiveRange(1, 0x7fffffff));
      // FNV-1a 32-bit of "msg-1", masked to 31 bits.
      expect(a.notificationId, NotificationPayload.stableId('msg-1'));
      expect(NotificationPayload.stableId(''), 0x811c9dc5 & 0x7fffffff);
    });

    test('falls back to the sent time when there is no message id', () {
      final sent = DateTime.fromMillisecondsSinceEpoch(1759500000123);
      final payload = NotificationPayload.fromRemoteMessage(
        _message(messageId: null, sentTime: sent),
      );
      expect(payload.notificationId, sent.millisecondsSinceEpoch & 0x7fffffff);
    });

    test('falls back to the current time with no id or sent time', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1759500000999);
      final payload = NotificationPayload.fromRemoteMessage(
        _message(messageId: null),
        now: () => now,
      );
      expect(payload.notificationId, now.millisecondsSinceEpoch & 0x7fffffff);
    });

    test('is never zero', () {
      final payload = NotificationPayload.fromRemoteMessage(
        _message(
          messageId: null,
          sentTime: DateTime.fromMillisecondsSinceEpoch(0x80000000),
        ),
      );
      expect(payload.notificationId, 1);
    });
  });

  group('decodeLocalPayload', () {
    test('round-trips route and id', () {
      expect(
        NotificationPayload.decodeLocalPayload(
          '{"route":"/notifications","id":"7"}',
        ),
        {'route': '/notifications', 'id': '7'},
      );
    });

    test('rejects null, empty, malformed, non-map and oversized input', () {
      for (final raw in [
        null,
        '',
        '{not json',
        '[1,2]',
        '"text"',
        jsonEncode({
          'route': '/notifications',
          'id': 'x' * NotificationPayload.maxSerializedLength,
        }),
      ]) {
        expect(
          NotificationPayload.decodeLocalPayload(raw),
          isNull,
          reason: raw,
        );
      }
    });

    test('ignores unknown keys and non-string values', () {
      expect(
        NotificationPayload.decodeLocalPayload(
          '{"route":5,"id":"9","balance":"100"}',
        ),
        {'id': '9'},
      );
    });
  });

  group('NotificationNavigator.parse', () {
    test('falls back for non-string or oversized fields without throwing', () {
      expect(
        NotificationNavigator.parse({'route': 7, 'id': 9}).routeName,
        AppRoutes.notifications,
      );
      final intent = NotificationNavigator.parse({
        'route': AppRoutes.notifications,
        'id': 'x' * (NotificationPayload.maxFieldLength + 1),
      });
      expect(intent.routeName, AppRoutes.notifications);
      expect(intent.entityId, isNull);
    });

    test('keeps a whitelisted route and bounded id', () {
      final intent = NotificationNavigator.parse({
        'route': AppRoutes.notifications,
        'id': 'n-1',
      });
      expect(intent.routeName, AppRoutes.notifications);
      expect(intent.entityId, 'n-1');
    });
  });
}
