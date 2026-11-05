import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'storage_adapter.dart';

class DeviceCredentials {
  final String accessKey;
  final String createdAtIso;

  const DeviceCredentials({
    required this.accessKey,
    required this.createdAtIso,
  });

  /// Single key displayed in the UI for cross-platform copy/paste.
  String get accountKey => accessKey;
  String get secretKey => accessKey;
  String get userId => accessKey.length >= 16
      ? accessKey.substring(0, 16)
      : accessKey;

  Map<String, dynamic> toJson() => {
        'access_key': accessKey,
        'created_at': createdAtIso,
      };

  factory DeviceCredentials.fromJson(Map<String, dynamic> json) {
    final directKey = json['access_key']?.toString().trim() ?? '';
    final legacySecret = json['secret_key']?.toString().trim() ?? '';
    final resolvedKey = directKey.isNotEmpty ? directKey : legacySecret;
    return DeviceCredentials(
      accessKey: resolvedKey,
      createdAtIso: json['created_at']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
    );
  }

  static DeviceCredentials? tryParseAccountKey(String rawInput) {
    final clean = rawInput.trim();
    if (clean.isEmpty) return null;
    // Support both new single-key (`omnispex_<hex>`) and legacy `usr_...:sec_...` input
    if (clean.contains(':')) {
      final parts = clean.split(':');
      if (parts.length == 2 && parts[1].trim().length >= 16) {
        return DeviceCredentials(
          accessKey: parts[1].trim(),
          createdAtIso: DateTime.now().toUtc().toIso8601String(),
        );
      }
      return null;
    }
    if (clean.length >= 16 && RegExp(r'^[A-Za-z0-9_\-]+$').hasMatch(clean)) {
      return DeviceCredentials(
        accessKey: clean,
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
      );
    }
    return null;
  }
}

class AuthService {
  static const String defaultEndpoint =
      'https://omnispex-cloud.kamilsuhak.workers.dev';
  static DeviceCredentials? _cachedCredentials;

  static String _generateSecureHex(int bytesCount) {
    final rng = Random.secure();
    final bytes = List<int>.generate(bytesCount, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<DeviceCredentials> getOrCreateCredentials({
    String endpoint = defaultEndpoint,
  }) async {
    if (_cachedCredentials != null) {
      return _cachedCredentials!;
    }

    final raw = await readCredentialsRaw();
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final creds = DeviceCredentials.fromJson(decoded);
          if (creds.accessKey.length >= 16) {
            _cachedCredentials = creds;
            return creds;
          }
        }
      } catch (_) {}
    }

    // Generate a unique 256-bit cryptographic key on first app launch
    final freshKey = 'omnispex_${_generateSecureHex(32)}';
    final creds = DeviceCredentials(
      accessKey: freshKey,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
    );

    await writeCredentialsRaw(jsonEncode(creds.toJson()));
    _cachedCredentials = creds;

    try {
      await verifyKeyWithCloud(creds, endpoint: endpoint);
    } catch (_) {}

    return creds;
  }

  static Future<bool> verifyKeyWithCloud(
    DeviceCredentials credentials, {
    String endpoint = defaultEndpoint,
  }) async {
    try {
      final uri = Uri.parse('$endpoint/api/auth/verify');
      final res = await http
          .post(
            uri,
            headers: getAuthHeaders(credentials),
          )
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> importCredentials(
    String accountKey, {
    String endpoint = defaultEndpoint,
  }) async {
    final parsed = DeviceCredentials.tryParseAccountKey(accountKey);
    if (parsed == null) return false;

    await writeCredentialsRaw(jsonEncode(parsed.toJson()));
    _cachedCredentials = parsed;

    // Best-effort touch against cloud worker (still succeeds offline if key format is valid)
    await verifyKeyWithCloud(parsed, endpoint: endpoint);
    return true;
  }

  static Map<String, String> getAuthHeaders(DeviceCredentials credentials) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${credentials.accessKey}',
    };
  }
}
