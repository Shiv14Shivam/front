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

  // ================= LOGIN =================
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
              "role": role,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final user = data["user"];
        final returnedRole = user?["role"];

        if (returnedRole != role) {
          return {"success": false, "message": "Invalid Credentials"};
        }

        final token =
            data["token"] ??
            data["access_token"] ??
            data["authorisation"]?["token"];

        if (token != null) await _saveToken(token);
        if (user != null) await _saveUser(user);

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
    String phone, {
    String? firmName,
    String? businessType,
    String? gstNumber,
    String? gst,
  }) async {
    try {
      final Map<String, dynamic> body = {
        "name": name,
        "email": email,
        "password": password,
        "password_confirmation": password,
        "role": role,
        "phone": phone,
      };

      if (role == "vendor") {
        body["firm_name"] = firmName;
        body["business_type"] = businessType;
        body["gst_number"] = gstNumber;
      }

      final response = await http
          .post(
            Uri.parse("$_baseUrl/register"),
            headers: _headers,
            body: jsonEncode(body),
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
        return {"success": true, "user": data["user"] ?? data};
      }

      return {
        "success": false,
        "message": data["message"] ?? "Failed to fetch profile",
      };
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= UPDATE PROFILE =================
  Future<Map<String, dynamic>> updateProfile(
    String name,
    String email,
    String phone, {
    String? firmName,
    String? businessType,
    String? gstNumber,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {"success": false, "message": "Not authenticated"};
      }

      final Map<String, dynamic> body = {
        "name": name,
        "email": email,
        "phone": phone,
      };

      if (firmName != null) body["firm_name"] = firmName;
      if (businessType != null) body["business_type"] = businessType;
      if (gstNumber != null) body["gst_number"] = gstNumber;

      final response = await http
          .post(
            Uri.parse("$_baseUrl/update-profile"),
            headers: _authHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data["message"],
          "user": data["user"],
        };
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

  // ================= UPDATE ADDRESS =================
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
      if (token == null) {
        return {"success": false, "message": "Not authenticated"};
      }

      final response = await http.put(
        Uri.parse("$_baseUrl/addresses/$id"),
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

      if (response.statusCode == 200) return {"success": true};
      return {"success": false};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= DELETE ADDRESS =================
  Future<bool> deleteAddress(int id) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse("$_baseUrl/addresses/$id"),
        headers: _authHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ================= SET DEFAULT ADDRESS =================
  Future<bool> setDefaultAddress(int id) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse("$_baseUrl/addresses/$id/default"),
        headers: _authHeaders(token),
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

      if (response.body.isEmpty) return {"success": true, "data": []};

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        List<dynamic> list;
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map && decoded.containsKey("data")) {
          list = decoded["data"] as List<dynamic>;
        } else {
          list = [];
        }
        return {"success": true, "data": list};
      }

      final msg = (decoded is Map)
          ? (decoded["message"] ?? "Failed to fetch addresses")
          : "Failed to fetch addresses";
      return {"success": false, "message": msg};
    } catch (e) {
      return {"success": false, "message": "Network error: $e"};
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

      if (response.body.isEmpty) {
        return {"success": false, "message": "Empty response from server"};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": data};
      }

      return {
        "success": false,
        "message": data["message"] ?? "Failed to add address",
      };
    } catch (e) {
      return {"success": false, "message": "Network error: $e"};
    }
  }

  // ================= GET DEFAULT ADDRESS =================
  Future<Map<String, dynamic>> getDefaultAddress() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {"success": false, "message": "Not authenticated"};
      }

      print("🔑 Token: $token");

      final response = await http
          .get(
            Uri.parse("$_baseUrl/address/default"),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      print(
        "📍 Default address response: ${response.statusCode} ${response.body}",
      );

      if (response.body.isEmpty) {
        return {"success": false, "message": "No default address found"};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data["latitude"] == null || data["longitude"] == null) {
          return {
            "success": false,
            "message": "Default address has no coordinates. Please re-save it.",
          };
        }
        return {"success": true, "data": data};
      }

      return {
        "success": false,
        "message": data["message"] ?? "No default address found",
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error: $e"};
    }
  }

  // ================= GET CATEGORIES =================
  Future<List<dynamic>> getCategories() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/categories"),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["data"];
    }

    throw Exception("Failed to load categories");
  }

  // ================= GET BRANDS =================
  Future<List<dynamic>> getBrands(int categoryId) async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse("$_baseUrl/categories/$categoryId/brands"),
      headers: _authHeaders(token!),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["data"];
    }

    print("Brand error: ${response.statusCode} ${response.body}");
    throw Exception("Failed to load brands");
  }

  // ================= GET PRODUCTS =================
  Future<List<dynamic>> getProducts(int brandId) async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse("$_baseUrl/brands/$brandId/products"),
      headers: _authHeaders(token!),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["data"];
    }

    print("Product error: ${response.statusCode} ${response.body}");
    throw Exception("Failed to load products");
  }

  // ================= CREATE LISTING =================
  Future<Map<String, dynamic>> createListing({
    required int categoryId,
    required int brandId,
    required int productId,
    required double pricePerBag,
    required double deliveryChargePerTon,
    required int stock,
  }) async {
    final token = await getToken();

    final response = await http.post(
      Uri.parse("$_baseUrl/seller/listings"),
      headers: _authHeaders(token!),
      body: jsonEncode({
        "category_id": categoryId,
        "brand_id": brandId,
        "product_id": productId,
        "price_per_bag": pricePerBag,
        "delivery_charge_per_ton": deliveryChargePerTon,
        "available_stock_bags": stock,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return {"success": true, "data": data};
    }

    return {
      "success": false,
      "message": data["message"] ?? "Failed to create listing",
    };
  }

  // ================= GET MARKETPLACE LISTINGS =================
  Future<List<dynamic>> getMarketplaceListings() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/marketplace"),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded["data"];
    }

    throw Exception("Failed to load marketplace listings");
  }

  // ================= GET CART =================
  // Called by:
  //   CartPage._loadCart()        → loads all cart items on page open
  //   CustomerHomePage._loadCartCount() → gets total_items for badge count
  Future<Map<String, dynamic>> getCart() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {"success": false, "message": "Not authenticated"};
      }

      final response = await http
          .get(Uri.parse("$_baseUrl/cart"), headers: _authHeaders(token))
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {"success": false, "message": "Empty response from server"};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": data["data"], // list of CartItemResource
          "summary": data["summary"], // {total_items, subtotal}
        };
      }

      return {
        "success": false,
        "message": data["message"] ?? "Failed to load cart",
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= ADD TO CART =================
  // Sends listing_id + quantity_bags to POST /api/cart.
  // Backend uses updateOrCreate — same listing won't be duplicated.
  // Returns 201 if new item, 200 if quantity was updated.
  //
  // Called by: CustomerHomePage._addToCart()
  // The quantity_bags saved here is the SAME value CartPage reads back.
  Future<Map<String, dynamic>> addToCart({
    required int listingId,
    required int quantityBags,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {"success": false, "message": "Not authenticated"};
      }

      final response = await http
          .post(
            Uri.parse("$_baseUrl/cart"),
            headers: _authHeaders(token),
            body: jsonEncode({
              "listing_id": listingId,
              "quantity_bags": quantityBags,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {"success": false, "message": "Empty response from server"};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          "success": true,
          "message": data["message"],
          "data": data["data"],
        };
      }

      return {
        "success": false,
        "message": data["message"] ?? "Failed to add to cart",
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= UPDATE CART ITEM =================
  // Updates quantity_bags for an existing cart item.
  // Called by CartPage when user taps + or - on a cart item.
  // Uses optimistic UI — Flutter updates first, rolls back on failure.
  Future<Map<String, dynamic>> updateCartItem(int id, int quantityBags) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {"success": false, "message": "Not authenticated"};
      }

      final response = await http
          .put(
            Uri.parse("$_baseUrl/cart/$id"),
            headers: _authHeaders(token),
            body: jsonEncode({"quantity_bags": quantityBags}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {"success": false, "message": "Empty response from server"};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "data": data["data"]};
      }

      return {"success": false, "message": data["message"] ?? "Update failed"};
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= REMOVE CART ITEM =================
  // Removes a single item from cart by cart item ID.
  // Called by CartPage when user taps delete on an item.
  // Uses optimistic UI — Flutter removes first, rolls back on failure.
  Future<bool> removeCartItem(int id) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http
          .delete(Uri.parse("$_baseUrl/cart/$id"), headers: _authHeaders(token))
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    } catch (e) {
      return false;
    }
  }

  // ================= CLEAR CART =================
  // Removes ALL items from the cart in one call.
  // Called by CartPage when user confirms "Clear All" in the dialog.
  Future<bool> clearCart() async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http
          .delete(
            Uri.parse("$_baseUrl/cart/clear"),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } on TimeoutException {
      return false;
    } catch (e) {
      return false;
    }
  }
}
