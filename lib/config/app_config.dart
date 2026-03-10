import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  static String get baseUrl {
    // Flutter Web
    if (kIsWeb) {
      return "http://localhost:8000/api";
    }

    // Android
    if (Platform.isAndroid) {
      // Emulator
      return "http://10.0.2.2/api";
      //return "http://192.168.137.1/api";
      // return "http://10.22.38.234:8000/api";
    }

    // Windows / macOS
    return "http://sandbackend.test/api";
  }
}
