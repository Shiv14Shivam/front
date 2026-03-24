// lib/session_manager.dart
//
// Uses SharedPreferences — the SAME storage ApiService already uses.
// No more dual-storage conflict. Works on web + mobile.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:front/view_type.dart';

class SessionManager {
  static const _keyToken = 'auth_token'; // ← same key ApiService uses
  static const _keyUserType = 'user_type';
  static const _keyView = 'current_view';
  static const _keyExpiry = 'token_expiry';

  // ── Save session after login ───────────────────────────────────────────────
  static Future<void> saveSession({
    required String token,
    required String userType,
    int expiryHours = 24,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now()
        .add(Duration(hours: expiryHours))
        .millisecondsSinceEpoch;

    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUserType, userType);
    await prefs.setInt(_keyExpiry, expiry);

    // Default home view
    final home = userType == 'vendor'
        ? ViewType.vendorHome
        : ViewType.customerHome;
    await saveCurrentView(home);
  }

  // ── Persist active view so refresh restores it ────────────────────────────
  static Future<void> saveCurrentView(ViewType view) async {
    const skip = {
      ViewType.landing,
      ViewType.login,
      ViewType.signup,
      ViewType.forgotPassword,
      ViewType.resetPassword,
      ViewType.primary,
    };
    if (skip.contains(view)) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyView, view.name);
  }

  // ── Is the stored session still valid? ────────────────────────────────────
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token == null || token.isEmpty) return false;

    final expiry = prefs.getInt(_keyExpiry);
    if (expiry == null) return false;

    return DateTime.now().millisecondsSinceEpoch < expiry;
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<String> getStoredUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserType) ?? 'customer';
  }

  static Future<ViewType> getStoredView() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyView);
    final userType = prefs.getString(_keyUserType) ?? 'customer';
    final home = userType == 'vendor'
        ? ViewType.vendorHome
        : ViewType.customerHome;

    if (raw == null) return home;

    return ViewType.values.firstWhere((v) => v.name == raw, orElse: () => home);
  }

  // ── Clear everything on logout ────────────────────────────────────────────
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserType);
    await prefs.remove(_keyView);
    await prefs.remove(_keyExpiry);
  }
}
