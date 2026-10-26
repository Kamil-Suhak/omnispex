import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'storage_adapter.dart';

class DeviceCredentials {
  final String userId;
  final String secretKey;
  final String createdAtIso;

  const DeviceCredentials({
    required this.userId,
    required this.secretKey,
    required this.createdAtIso,
  });

  String get accountKey => '$userId:$secretKey';

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'secret_key': secretKey,
        'created_at': createdAtIso,
      };

  factory DeviceCredentials.fromJson(Map<String, dynamic> json) {
    return DeviceCredentials(
      userId: json['user_id']?.toString() ?? '',
      secretKey: json['secret_key']?.toString() ?? '',
      createdAtIso: json['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
    );
  }

  static DeviceCredentials? tryParseAccountKey(String key) {
    final clean = key.trim();
    final parts = clean.split(':');
    if (parts.length == 2 && parts[0].isNotEmpty && parts[1].length >= 8) {
      return DeviceCredentials(
        userId: parts[0],
        secretKey: parts[1],
        createdAtIso: DateTime.now().toUtc().toIso8601String(),
      );
    }
    return null;
  }
}

class AuthService {
  static const String defaultEndpoint = 'https://omnispex-cloud.kamilsuhak.workers.dev';
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
          if (creds.userId.isNotEmpty && creds.secretKey.length >= 8) {
            _cachedCredentials = creds;
            return creds;
          }
        }
      } catch (_) {}
    }

    // Generate fresh credentials
    final newUserId = 'usr_${_generateSecureHex(8)}';
    final newSecret = 'sec_${_generateSecureHex(16)}';
    final creds = DeviceCredentials(
      userId: newUserId,
      secretKey: newSecret,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
    );

    // Save locally
    await writeCredentialsRaw(jsonEncode(creds.toJson()));
    _cachedCredentials = creds;

    // Register with Cloudflare D1
    try {
      await registerDeviceWithCloud(creds, endpoint: endpoint);
    } catch (_) {}

    return creds;
  }

  static Future<bool> registerDeviceWithCloud(
    DeviceCredentials credentials, {
    String endpoint = defaultEndpoint,
  }) async {
    try {
      final uri = Uri.parse('$endpoint/api/auth/register');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': credentials.userId,
          'secret_key': credentials.secretKey,
        }),
      );
      if (res.statusCode == 200) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> importCredentials(
    String accountKey, {
    String endpoint = defaultEndpoint,
  }) async {
    final parsed = DeviceCredentials.tryParseAccountKey(accountKey);
    if (parsed == null) return false;

    // Verify against cloud
    final verified = await registerDeviceWithCloud(parsed, endpoint: endpoint);
    if (!verified) {
      // Test GET /api/sync/:userId with Bearer token
      try {
        final testUri = Uri.parse('$endpoint/api/sync/${parsed.userId}');
        final res = await http.get(
          testUri,
          headers: {'Authorization': 'Bearer ${parsed.secretKey}'},
        );
        if (res.statusCode != 200) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }

    await writeCredentialsRaw(jsonEncode(parsed.toJson()));
    _cachedCredentials = parsed;
    return true;
  }

  static Map<String, String> getAuthHeaders(DeviceCredentials credentials) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${credentials.secretKey}',
    };
  }
}
