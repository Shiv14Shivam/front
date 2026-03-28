import 'package:flutter/foundation.dart';

class AppConfig {
  static const String razorpayKey = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: 'rzp_test_SV1gqQoQWT8PqR',
  );

  static String get baseUrl {
    if (kIsWeb) {
      return "https://sand-backend-production.up.railway.app/api";
    }
    return "http://localhost:8000/api"; // Local dev fallback
  }
}
