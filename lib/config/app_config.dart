import 'package:flutter/foundation.dart';

class AppConfig {
  static const String razorpayKey = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: 'rzp_test_SV1gqQoQWT8PqR',
  );

  /// Backend host - set via --dart-define=BACKEND_HOST=sandbackend.test
  /// Fallbacks: Web/Herd → sandbackend.test, Android emulator → 10.0.2.2
  static String get _host {
    const envHost = String.fromEnvironment('BACKEND_HOST');
    if (envHost.isNotEmpty) return envHost;

    if (kIsWeb) {
      return 'sandbackend.test'; // Herd domain for web
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2'; // Emulator
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'localhost'; // iOS simulator
    }
    // Physical device: use dart-define with your PC IP e.g. 192.168.1.100
    return 'localhost';
  }

  /// Backend port - set via --dart-define=BACKEND_PORT=80
  static String get _port {
    const envPort = String.fromEnvironment('BACKEND_PORT');
    if (envPort.isNotEmpty) return ':$envPort';
    return ''; // default 80
  }

  static String get baseUrl => 'http://$_host$_port/api';
}
