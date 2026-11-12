import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voice_docs/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'iOS initializes Darwin settings and requests notification permission explicitly',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final service = NotificationService();
      await service.initialize();
      expect(calls.any((c) => c.method == 'initialize'), isTrue);
      expect(await service.requestPermission(), isTrue);
      expect(calls.any((c) => c.method == 'requestPermissions'), isTrue);
    },
  );
}
