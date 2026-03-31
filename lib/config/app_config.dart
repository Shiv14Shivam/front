import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class AppConfig {
  static const String razorpayKey = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: 'rzp_test_SV1gqQoQWT8PqR',
  );

  static String get _host {
    const isProd = bool.fromEnvironment('PRODUCTION', defaultValue: true);
    if (isProd) return 'sand-here-server-main-0xw3qp.free.laravel.cloud';

    const envHost = String.fromEnvironment('BACKEND_HOST');
    if (envHost.isNotEmpty) return envHost;

    if (kIsWeb) {
      return 'sandbackend.test';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'localhost';
    }
    return 'localhost';
  }

  static String get _port {
    const envPort = String.fromEnvironment('BACKEND_PORT');
    if (envPort.isNotEmpty) return ':$envPort';
    return '';
  }

  static String get baseUrl {
    const isProd = bool.fromEnvironment('PRODUCTION', defaultValue: true);
    if (isProd) {
      return 'https://sand-here-server-main-0xw3qp.free.laravel.cloud/api'; // ✅ fixed
    }
    return 'http://$_host$_port/api';
  }
}
