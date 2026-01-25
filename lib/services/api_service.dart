import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:front/config/app_config.dart';

class ApiService {
  // ================= SINGLETON =================
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    print('🚀 ApiService initialized');
    printConfig();
  }

  // ================= CONFIG =================
  String get _baseUrl => AppConfig.baseUrl;

  void printConfig() {
    print('''
════════════════════════════════
API CONFIG
Platform : ${kIsWeb ? 'Web' : Platform.operatingSystem}
Base URL : $_baseUrl
════════════════════════════════
''');
  }

  Map<String, String> get _headers => {
    "Content-Type": "application/json",
    "Accept": "application/json",
    "Host": "sandbackend.test", // REQUIRED for Herd
  };

  // ================= LOGIN =================
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/login"),
            headers: _headers,
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        final token =
            data["token"] ??
            data["access_token"] ??
            data["authorisation"]?["token"];

        if (token != null) {
          await _saveToken(token);
        }

        if (data["user"] != null) {
          await _saveUser(data["user"]);
        }

        return {
          "success": true,
          "message": data["message"] ?? "Login successful",
          "data": data,
        };
      }

      return {
        "success": false,
        "message": jsonDecode(response.body)["message"] ?? "Login failed",
        "statusCode": response.statusCode,
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= STORAGE =================
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_token", token);
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user_data", jsonEncode(user));
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("auth_token");
  }

  Future<bool> isLoggedIn() async {
    return (await getToken()) != null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ================= Register =================
  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/register"),
            headers: _headers,
            body: jsonEncode({
              "name": name,
              "email": email,
              "password": password,
              "role": role,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        final token =
            data["token"] ??
            data["access_token"] ??
            data["authorisation"]?["token"];

        if (token != null) {
          await _saveToken(token);
        }

        if (data["user"] != null) {
          await _saveUser(data["user"]);
        }

        return {
          "success": true,
          "message": data["message"] ?? "Registration successful",
          "data": data,
        };
      }

      return {
        "success": false,
        "message":
            jsonDecode(response.body)["message"] ?? "Registration failed",
        "statusCode": response.statusCode,
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }
}
