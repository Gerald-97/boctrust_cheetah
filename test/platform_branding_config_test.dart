import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:yaml/yaml.dart';

const _res = 'android/app/src/main/res';
const _appIcon = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const _densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

YamlMap _yaml(String path, String key) =>
    (loadYaml(File(path).readAsStringSync()) as YamlMap)[key] as YamlMap;

img.Image _png(String path) {
  final image = img.decodePng(File(path).readAsBytesSync());
  expect(image, isNotNull, reason: '$path must be a valid PNG');
  return image!;
}

bool _isApprovedBlue(img.Pixel p) =>
    (p.r - 0x4F).abs() <= 6 &&
    (p.g - 0x7E).abs() <= 6 &&
    (p.b - 0xB4).abs() <= 6;

void main() {
  group('launcher icon configuration', () {
    late YamlMap config;
    setUpAll(
      () => config = _yaml(
        'flutter_launcher_icons.yaml',
        'flutter_launcher_icons',
      ),
    );

    test('uses the approved masters and blue adaptive background', () {
      expect(config['android'], isTrue);
      expect(config['ios'], isTrue);
      expect(
        config['image_path_android'],
        'assets/branding/cheetah_app_icon.png',
      );
      expect(
        config['image_path_ios'],
        'assets/branding/generated/cheetah_app_icon_opaque.png',
      );
      expect(config['remove_alpha_ios'], isTrue);
      expect(config['background_color_ios'], '#4F7EB4');
      expect(config['adaptive_icon_background'], '#4F7EB4');
      expect(
        config['adaptive_icon_foreground'],
        'assets/branding/generated/cheetah_adaptive_foreground.png',
      );
    });

    test('has no improvised monochrome icon before design sign-off', () {
      final monochrome = config['adaptive_icon_monochrome'];
      if (monochrome != null) {
        expect(monochrome, 'assets/branding/cheetah_monochrome.svg');
      }
    });
  });

  group('native splash configuration', () {
    late YamlMap config;
    setUpAll(
      () =>
          config = _yaml('flutter_native_splash.yaml', 'flutter_native_splash'),
    );

    test('is an icon-only splash on white in light and dark modes', () {
      expect(config['color'], '#FFFFFF');
      expect(config['color_dark'], '#FFFFFF');
      expect(config['image'], 'assets/branding/generated/cheetah_splash.png');
      expect(
        config['image_dark'],
        'assets/branding/generated/cheetah_splash.png',
      );
      expect(config.containsKey('branding'), isFalse);
      expect(config['android'], isTrue);
      expect(config['ios'], isTrue);
    });

    test('Android 12 uses the circle-safe image and no icon background', () {
      final android12 = config['android_12'] as YamlMap;
      const image = 'assets/branding/generated/cheetah_splash_android12.png';
      expect(android12['image'], image);
      expect(android12['image_dark'], image);
      expect(android12['color'], '#FFFFFF');
      expect(android12['color_dark'], '#FFFFFF');
      expect(android12.containsKey('icon_background_color'), isFalse);
      expect(android12.containsKey('icon_background_color_dark'), isFalse);
    });
  });

  group('generated Android resources', () {
    test('legacy launcher icons show the Cheetah at every density', () {
      for (final density in _densities) {
        final icon = _png('$_res/mipmap-$density/ic_launcher.png');
        // The approved field colour sits just inside the rounded corner.
        final p = icon.getPixel(icon.width ~/ 8, icon.height ~/ 8);
        expect(_isApprovedBlue(p), isTrue, reason: 'mipmap-$density');
      }
    });

    test('adaptive icon layers the white foreground over the blue field', () {
      final xml = File(
        '$_res/mipmap-anydpi-v26/ic_launcher.xml',
      ).readAsStringSync();
      expect(xml, contains('@color/ic_launcher_background'));
      expect(xml, contains('@drawable/ic_launcher_foreground'));
      final colors = File('$_res/values/colors.xml').readAsStringSync();
      expect(colors.toUpperCase(), contains('#4F7EB4'));
      for (final density in _densities) {
        expect(
          File(
            '$_res/drawable-$density/ic_launcher_foreground.png',
          ).existsSync(),
          isTrue,
          reason: density,
        );
      }
    });

    test('Android 12+ splash is explicit, white, and uses the icon', () {
      for (final dir in ['values-v31', 'values-night-v31']) {
        final styles = File('$_res/$dir/styles.xml').readAsStringSync();
        expect(styles, contains('android:windowSplashScreenAnimatedIcon'));
        expect(styles, contains('@drawable/android12splash'));
        expect(styles, contains('android:windowSplashScreenBackground'));
      }
      for (final density in _densities) {
        expect(
          File('$_res/drawable-$density/android12splash.png').existsSync(),
          isTrue,
          reason: density,
        );
      }
    });

    test('pre-Android-12 launch background centres the splash image', () {
      for (final dir in ['drawable', 'drawable-v21']) {
        final xml = File('$_res/$dir/launch_background.xml').readAsStringSync();
        expect(xml, contains('@drawable/splash'));
        expect(xml, isNot(contains('@mipmap/ic_launcher')));
      }
    });
  });

  group('generated iOS resources', () {
    test('every AppIcon slot is an opaque Cheetah icon', () {
      final contents =
          jsonDecode(File('$_appIcon/Contents.json').readAsStringSync())
              as Map<String, dynamic>;
      final images = (contents['images'] as List).cast<Map<String, dynamic>>();
      expect(images.where((i) => i['idiom'] == 'ios-marketing'), isNotEmpty);
      for (final entry in images) {
        final name = entry['filename'] as String?;
        expect(name, isNotNull, reason: 'slot ${entry['size']} has no file');
        final icon = _png('$_appIcon/$name');
        expect(icon.hasAlpha, isFalse, reason: name);
        expect(_isApprovedBlue(icon.getPixel(0, 0)), isTrue, reason: name);
      }
    });

    test('launch screen shows the splash image on white', () {
      final storyboard = File(
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
      ).readAsStringSync();
      expect(storyboard, contains('image="LaunchImage"'));
      final launch = _png(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png',
      );
      final centre = launch.getPixel(launch.width ~/ 2, launch.height ~/ 4);
      expect(_isApprovedBlue(centre), isTrue);
      final background = File(
        'ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png',
      );
      expect(background.existsSync(), isTrue);
      final pixel = _png(background.path).getPixel(0, 0);
      expect([pixel.r, pixel.g, pixel.b], [255, 255, 255]);
    });
  });

  group('Android notification configuration', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    const iconKey = 'com.google.firebase.messaging.default_notification_icon';
    final smallIcons = {
      for (final (density, size) in [
        ('mdpi', 24),
        ('hdpi', 36),
        ('xhdpi', 48),
        ('xxhdpi', 72),
        ('xxxhdpi', 96),
      ])
        '$_res/drawable-$density/ic_stat_boctrust.png': size,
    };

    test('keeps the notification permission', () {
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    });

    test('routes OS-rendered messages to the BOCTRUST channel', () {
      expect(
        manifest,
        matches(
          RegExp(
            r'android:name="com\.google\.firebase\.messaging\.'
            r'default_notification_channel_id"\s+'
            r'android:value="boctrust_general"',
          ),
        ),
      );
    });

    // The small icon waits for the designer-approved monochrome silhouette;
    // until then neither the drawables nor the Firebase default icon exist.
    test('small icon and its Firebase default ship together', () {
      final present = smallIcons.keys.where((p) => File(p).existsSync());
      if (present.isEmpty) {
        expect(manifest, isNot(contains(iconKey)));
        return;
      }
      expect(present, hasLength(smallIcons.length));
      expect(
        manifest,
        matches(
          RegExp(
            '${RegExp.escape(iconKey)}"\\s+'
            'android:resource="@drawable/ic_stat_boctrust"',
          ),
        ),
      );
      for (final MapEntry(key: path, value: size) in smallIcons.entries) {
        final icon = _png(path);
        expect([icon.width, icon.height], [size, size], reason: path);
        expect(icon.hasAlpha, isTrue, reason: path);
        for (final p in icon) {
          if (p.a == 0) continue;
          expect(
            [p.r, p.g, p.b],
            [255, 255, 255],
            reason: '$path ${p.x},${p.y}',
          );
        }
      }
    });
  });

  group('iOS notification configuration', () {
    test('enables remote-notification background delivery', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        plist,
        matches(
          RegExp(
            r'<key>UIBackgroundModes</key>\s*<array>[^]*?'
            r'<string>remote-notification</string>[^]*?</array>',
          ),
        ),
      );
    });

    test('signs the Runner target with the push entitlement', () {
      final entitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      expect(entitlements, contains('<key>aps-environment</key>'));
      final project = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      final runnerConfigs = RegExp(
        r'INFOPLIST_FILE = Runner/Info\.plist;',
      ).allMatches(project).length;
      expect(runnerConfigs, 3);
      expect(
        RegExp(
          r'CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;',
        ).allMatches(project).length,
        runnerConfigs,
      );
    });

    test('AppDelegate serves the notification-center delegate', () {
      final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(delegate, contains('UNUserNotificationCenter.current().delegate'));
      expect(
        delegate,
        contains('FlutterLocalNotificationsPlugin.setPluginRegistrantCallback'),
      );
      // Overriding these without super would starve firebase_messaging.
      expect(delegate, isNot(contains('didReceive response')));
      expect(delegate, isNot(contains('willPresent')));
    });

    test('Firebase foreground presentation stays off', () {
      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in sources) {
        expect(
          file.readAsStringSync(),
          isNot(contains('setForegroundNotificationPresentationOptions')),
          reason: file.path,
        );
      }
    });
  });
}
