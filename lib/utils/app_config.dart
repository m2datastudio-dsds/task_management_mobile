// ============================================================
// LOCAL DEVELOPMENT
// flutter run
//
// PRODUCTION APK
// flutter build apk --dart-define=API_BASE_URL=https://<cloud-run-url>/api
//
// Never hardcode the Cloud Run URL in this file.
// ============================================================

import 'package:flutter/foundation.dart';

class AppConfig {
  /// Build-time override.
  ///
  /// Example:
  /// flutter run --dart-define=API_BASE_URL=http://192.168.1.4:5000/api
  ///
  /// flutter build apk --dart-define=API_BASE_URL=https://your-cloud-run-url.run.app/api
  static const String _overrideApiBaseUrl =
      String.fromEnvironment('API_BASE_URL');

  /// Local backend URLs
  static const String _localhostApi =
      'http://localhost:5000/api';

  /// Real Android phone connected to same Wi-Fi as your PC
  static const String _androidPhoneApi =
      'http://192.168.1.6:5000/api';

  /// Android Emulator
  static const String _androidEmulatorApi =
      'http://10.0.2.2:5000/api';

  /// Production backend
  ///
  /// Optional.
  /// Keep this empty if you always use --dart-define.
  static const String _productionApi =
      'https://taskmanagement-backend-628026864230.asia-south1.run.app/api';

  static String get apiBaseUrl {

    // Highest Priority
    // Passed during flutter build/run
    if (_overrideApiBaseUrl.isNotEmpty) {
      return _overrideApiBaseUrl;
    }

    // Optional production fallback
    if (_productionApi.isNotEmpty) {
      return _productionApi;
    }

    // Local development
    if (kIsWeb) {
      return _localhostApi;
    }

    switch (defaultTargetPlatform) {

      case TargetPlatform.android:
        // Real Android phone
        return _androidPhoneApi;

        // If using Android Emulator instead,
        // change the above line to:
        // return _androidEmulatorApi;

      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return _localhostApi;
    }
  }

  static String get apiBaseUrlHint {

    if (_overrideApiBaseUrl.isNotEmpty) {
      return 'Using Build Override: $_overrideApiBaseUrl';
    }

    if (_productionApi.isNotEmpty) {
      return 'Using Production API: $_productionApi';
    }

    return 'Using Local Development API: $apiBaseUrl';
  }

  static String get platformSetupHint {

    if (_overrideApiBaseUrl.isNotEmpty) {
      return '''
Build Override Enabled

API:
$_overrideApiBaseUrl
''';
    }

    return '''
Local Development

Web:
$_localhostApi

Windows/macOS/Linux:
$_localhostApi

Android Phone:
$_androidPhoneApi

Android Emulator:
$_androidEmulatorApi

Production:
Use:

flutter build apk --dart-define=API_BASE_URL=https://your-cloud-run-url.run.app/api
''';
  }
}
