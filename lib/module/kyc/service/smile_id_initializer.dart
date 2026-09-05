import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smile_id/smile_id.dart';
import 'package:smile_id/generated/smileid_messages.g.dart';

import '../../../app/services.dart';

/// Path of the Smile ID partner configuration bundled at build time.
///
/// The file is Git-ignored and injected per environment; see
/// `assets/json/README.md`.
const kSmileConfigAssetPath = 'assets/json/smile_config.json';

/// Strict parser for the Smile ID portal configuration.
///
/// The portal ships a superset of what the SDK needs and uses snake_case keys.
/// Parsing it here keeps the JSON shape out of the SDK boundary and lets the
/// mapping be tested without a platform channel.
class SmileIdAssetConfig {
  const SmileIdAssetConfig({
    required this.partnerId,
    required this.authToken,
    required this.productionBaseUrl,
    required this.sandboxBaseUrl,
  });

  factory SmileIdAssetConfig.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid Smile ID config.');
    final json = Map<String, Object?>.from(value);

    String requiredText(String key) {
      final result = json[key];
      if (result is! String || result.trim().isEmpty) {
        throw const FormatException('Invalid Smile ID config.');
      }
      return result.trim();
    }

    Uri requiredHttpsUrl(String primaryKey, String fallbackKey) {
      final primary = json[primaryKey];
      final raw = primary is String && primary.trim().isNotEmpty
          ? primary.trim()
          : requiredText(fallbackKey);
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException('Invalid Smile ID config.');
      }
      return uri;
    }

    return SmileIdAssetConfig(
      partnerId: requiredText('partner_id'),
      authToken: requiredText('auth_token'),
      productionBaseUrl: requiredHttpsUrl('prod_lambda_url', 'prod_url'),
      sandboxBaseUrl: requiredHttpsUrl('test_lambda_url', 'test_url'),
    );
  }

  final String partnerId;
  final String authToken;
  final Uri productionBaseUrl;
  final Uri sandboxBaseUrl;

  FlutterConfig toFlutterConfig() => FlutterConfig(
    partnerId: partnerId,
    authToken: authToken,
    prodBaseUrl: productionBaseUrl.toString(),
    sandboxBaseUrl: sandboxBaseUrl.toString(),
  );
}

/// Boundary for Smile ID SDK initialization, so tests and the later v12
/// migration can replace it without touching call sites.
abstract interface class SmileIdInitializer {
  Future<void> ensureInitialized();
  void resetInitialization();
}

final smileIdInitializerProvider = Provider<SmileIdInitializer>(
  (ref) =>
      SmileIdV11Initializer(assetBundle: rootBundle, useSandbox: Env.isStaging),
);

class SmileIdV11Initializer implements SmileIdInitializer {
  SmileIdV11Initializer({required this.assetBundle, required this.useSandbox});

  final AssetBundle assetBundle;
  final bool useSandbox;
  Future<void>? _initialization;

  @override
  Future<void> ensureInitialized() async {
    final current = _initialization;
    if (current != null) return current;

    final attempt = _initialize();
    _initialization = attempt;
    try {
      await attempt;
    } catch (_) {
      if (identical(_initialization, attempt)) _initialization = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    final source = await assetBundle.loadString(kSmileConfigAssetPath);
    final config = SmileIdAssetConfig.fromJson(jsonDecode(source));
    await SmileID.initializeWithConfig(
      config: config.toFlutterConfig(),
      useSandbox: useSandbox,
      enableCrashReporting: Env.isProd,
    );
  }

  @override
  void resetInitialization() => _initialization = null;
}
