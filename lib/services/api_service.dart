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

  Map<String, String> _authHeaders(String token) {
    return {..._headers, "Authorization": "Bearer $token"};
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
    "Host": "sandbackend.test",
  };

  // ================= LOGIN (FIXED) =================
  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    required String role,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/login"),
            headers: _headers,
            body: jsonEncode({
              "email": email,
              "password": password,
              "role": role, // sent to backend
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final user = data["user"];
        final returnedRole = user?["role"];

        // 🔐 ROLE CHECK (CRITICAL FIX)
        if (returnedRole != role) {
          return {"success": false, "message": "Invalid Credentials"};
        }

        final token =
            data["token"] ??
            data["access_token"] ??
            data["authorisation"]?["token"];

        if (token != null) {
          await _saveToken(token);
        }

        if (user != null) {
          await _saveUser(user);
        }

        return {
          "success": true,
          "message": data["message"] ?? "Login successful",
          "role": returnedRole,
          "data": data,
        };
      }

      return {
        "success": false,
        "message": data["message"] ?? "Login failed",
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

  // ================= REGISTER =================
  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String role,
    String phone,
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
              "password_confirmation": password,
              "role": role,
              "phone": phone,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          "success": true,
          "message":
              data["message"] ??
              "Registered successfully. Please verify your email.",
        };
      }

      return {
        "success": false,
        "message": data["message"] ?? "Registration failed",
        "statusCode": response.statusCode,
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= GET PROFILE =================
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {"success": false, "message": "Not authenticated"};
      }

      final response = await http
          .get(Uri.parse("$_baseUrl/profile"), headers: _authHeaders(token))
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "user": data["user"]};
      }

      return {
        "success": false,
        "message": data["message"] ?? "Failed to fetch profile",
        "statusCode": response.statusCode,
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= UPDATE PROFILE =================
  Future<Map<String, dynamic>> updateProfile(
    String name,
    String email,
    String phone,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {"success": false, "message": "Not authenticated"};
      }

      final response = await http
          .post(
            Uri.parse("$_baseUrl/update-profile"),
            headers: _authHeaders(token),
            body: jsonEncode({"name": name, "email": email, "phone": phone}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "message": data["message"], "data": data};
      }

      return {
        "success": false,
        "message": data["message"] ?? "Profile update failed",
        "statusCode": response.statusCode,
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= LOGOUT =================
  Future<Map<String, dynamic>> logout() async {
    try {
      final token = await getToken();

      if (token == null) {
        return {"success": false, "message": "Not authenticated"};
      }

      final response = await http
          .post(Uri.parse("$_baseUrl/logout"), headers: _authHeaders(token))
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        return {
          "success": true,
          "message": data["message"] ?? "Logged out successfully",
        };
      }

      return {"success": false, "message": data["message"] ?? "Logout failed"};
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  Future<Map<String, dynamic>> updateAddress(
    int id, {
    required String label,
    required String line1,
    String? line2,
    required String city,
    required String state,
    required String pincode,
    required bool isDefault,
  }) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse("$_baseUrl/addresses/$id"),
        headers: _authHeaders(token!),
        body: jsonEncode({
          "label": label,
          "address_line_1": line1,
          "address_line_2": line2,
          "city": city,
          "state": state,
          "pincode": pincode,
          "is_default": isDefault,
        }),
      );

      if (response.statusCode == 200) {
        return {"success": true};
      }

      return {"success": false};
    } catch (e) {
      return {"success": false};
    }
  }

  Future<bool> deleteAddress(int id) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse("$_baseUrl/addresses/$id"),
        headers: _authHeaders(token!),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setDefaultAddress(int id) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse("$_baseUrl/addresses/$id/default"),
        headers: _authHeaders(token!),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ================= GET ADDRESSES =================
  Future<Map<String, dynamic>> getAddresses() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {"success": false, "message": "Not authenticated"};
      }

      final response = await http.get(
        Uri.parse("$_baseUrl/addresses"),
        headers: _authHeaders(token),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "data": data};
      }

      return {
        "success": false,
        "message": data["message"] ?? "Failed to fetch addresses",
      };
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= ADD ADDRESS =================
  Future<Map<String, dynamic>> addAddress({
    required String label,
    required String line1,
    String? line2,
    required String city,
    required String state,
    required String pincode,
    required bool isDefault,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {"success": false, "message": "Not authenticated"};
      }

      final response = await http.post(
        Uri.parse("$_baseUrl/addresses"),
        headers: _authHeaders(token),
        body: jsonEncode({
          "label": label,
          "address_line_1": line1,
          "address_line_2": line2,
          "city": city,
          "state": state,
          "pincode": pincode,
          "is_default": isDefault,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": data};
      }

      return {
        "success": false,
        "message": data["message"] ?? "Failed to add address",
      };
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }
}
