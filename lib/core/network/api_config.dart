import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const String accessTokenKey = 'nexor.access_token';

  /// Override when running against a deployed API:
  /// flutter run -d chrome --dart-define=NEXOR_API_URL=https://api.example.com/api/v1
  static String get baseUrl {
    const override = String.fromEnvironment('NEXOR_API_URL');
    if (override.isNotEmpty) return override;

    if (kIsWeb) return 'http://localhost:3000/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }
}
