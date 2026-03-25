import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class AppConfig {
  static const String razorpayKey = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: 'rzp_test_SV1gqQoQWT8PqR',
  );

  static String get baseUrl {
    // Flutter Web

    if (kIsWeb) {
      return "http://sandbackend.test/api"; // Herd domain works in browser too!
    }
    if (Platform.isAndroid) {
      return "http://10.0.2.2:8000/api";
    }
    return "http://sandbackend.test/api"; // native desktop/iOS
  }
}
