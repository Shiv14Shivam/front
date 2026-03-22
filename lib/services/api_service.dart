import 'dart:async';
import 'dart:convert';
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
Platform : ${kIsWeb ? 'Web' : 'Native'}
Base URL : $_baseUrl
════════════════════════════════
''');
  }

  Map<String, String> get _headers => {
    "Content-Type": "application/json",
    "Accept": "application/json",
    if (!kIsWeb) "Host": "sandbackend.test",
  };

  Map<String, String> _authHeaders(String token) {
    return {..._headers, "Authorization": "Bearer $token"};
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
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

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
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

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
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

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

  // ================= ADDRESSES =================
  Future<Map<String, dynamic>> getAddresses() async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

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

  // ── addAddress — lat/lng from map pin ──────────────────────────────────────
  Future<Map<String, dynamic>> addAddress({
    required String label,
    required String line1,
    String? line2,
    required String city,
    required String state,
    required String pincode,
    required bool isDefault,
    double? latitude, // ← from map pin
    double? longitude, // ← from map pin
  }) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final Map<String, dynamic> body = {
        "label": label,
        "address_line_1": line1,
        "address_line_2": line2,
        "city": city,
        "state": state,
        "pincode": pincode,
        "is_default": isDefault,
      };

      // Only include coords when the user actually pinned a location
      if (latitude != null) body["latitude"] = latitude;
      if (longitude != null) body["longitude"] = longitude;

      final response = await http.post(
        Uri.parse("$_baseUrl/addresses"),
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response from server"};

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

  // ── updateAddress — lat/lng from map pin ───────────────────────────────────
  Future<Map<String, dynamic>> updateAddress(
    int id, {
    required String label,
    required String line1,
    String? line2,
    required String city,
    required String state,
    required String pincode,
    required bool isDefault,
    double? latitude, // ← from map pin (null = keep existing coords on server)
    double? longitude, // ← from map pin (null = keep existing coords on server)
  }) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final Map<String, dynamic> body = {
        "label": label,
        "address_line_1": line1,
        "address_line_2": line2,
        "city": city,
        "state": state,
        "pincode": pincode,
        "is_default": isDefault,
      };

      // Only send new coords if the user re-pinned; backend keeps old ones otherwise
      if (latitude != null) body["latitude"] = latitude;
      if (longitude != null) body["longitude"] = longitude;

      final response = await http.put(
        Uri.parse("$_baseUrl/addresses/$id"),
        headers: _authHeaders(token),
        body: jsonEncode(body),
      );

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response"};

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) return {"success": true, "data": data};

      return {
        "success": false,
        "message": data["message"] ?? "Failed to update address",
      };
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

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

  Future<Map<String, dynamic>> getDefaultAddress() async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .get(
            Uri.parse("$_baseUrl/address/default"),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty)
        return {"success": false, "message": "No default address found"};

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

  // ================= CATEGORIES / BRANDS / PRODUCTS =================
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
    throw Exception("Failed to load brands");
  }

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
    throw Exception("Failed to load products");
  }

  Future<List<dynamic>> getProductsByCategory(int categoryId) async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse("$_baseUrl/products?category_id=$categoryId"),
      headers: _authHeaders(token!),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      print("FULL RESPONSE: $data");

      return data["data"];
    }

    throw Exception("Failed to load products");
  }

  // ================= LISTINGS =================
  // ================= LISTINGS =================
  Future<Map<String, dynamic>> createListing({
    required int categoryId,
    int? brandId, // nullable — Sand has no brand
    required int productId,
    required double pricePerunit,
    required double deliveryChargePerTon,
    required int stock,
    String? riverSource, // optional river source
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      // Build body — only include brand_id when it exists
      final Map<String, dynamic> body = {
        'category_id': categoryId,
        'product_id': productId,
        'price_per_unit': pricePerunit,
        'delivery_charge_per_km': deliveryChargePerTon,
        'available_stock_unit': stock,
      };

      if (brandId != null) body['brand_id'] = brandId;
      if (riverSource != null && riverSource.isNotEmpty) {
        body['river_source'] = riverSource;
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/seller/listings'),
            headers: _authHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Failed to create listing',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Server timeout'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

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

  // ================= CART =================
  Future<Map<String, dynamic>> getCart() async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .get(Uri.parse("$_baseUrl/cart"), headers: _authHeaders(token))
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response from server"};

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": data["data"],
          "summary": data["summary"],
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

  Future<Map<String, dynamic>> addToCart({
    required int listingId,
    required int quantityunit,
  }) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .post(
            Uri.parse("$_baseUrl/cart"),
            headers: _authHeaders(token),
            body: jsonEncode({
              "listing_id": listingId,
              "quantity_unit": quantityunit,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response from server"};

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

  Future<Map<String, dynamic>> updateCartItem(int id, int quantityunit) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .put(
            Uri.parse("$_baseUrl/cart/$id"),
            headers: _authHeaders(token),
            body: jsonEncode({"quantity_unit": quantityunit}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response from server"};

      final data = jsonDecode(response.body);

      if (response.statusCode == 200)
        return {"success": true, "data": data["data"]};

      return {"success": false, "message": data["message"] ?? "Update failed"};
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  Future<bool> removeCartItem(int id) async {
    try {
      final token = await getToken();
      if (token == null) return false;
      final response = await http
          .delete(Uri.parse("$_baseUrl/cart/$id"), headers: _authHeaders(token))
          .timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

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
    } catch (e) {
      return false;
    }
  }

  // ================= VENDOR ORDERS =================
  Future<Map<String, dynamic>> getVendorOrders() async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .get(
            Uri.parse("$_baseUrl/vendor/orders"),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response"};

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "data": data["data"] ?? data};
      }
      return {
        "success": false,
        "message": data["message"] ?? "Failed to load orders",
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  Future<Map<String, dynamic>> acceptVendorOrder(int orderId) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .post(
            Uri.parse("$_baseUrl/vendor/orders/$orderId/accept"),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200)
        return {"success": true, "message": data["message"]};
      return {
        "success": false,
        "message": data["message"] ?? "Failed to accept",
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  Future<Map<String, dynamic>> declineVendorOrder(
    int orderId, {
    String? reason,
  }) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .post(
            Uri.parse("$_baseUrl/vendor/orders/$orderId/decline"),
            headers: _authHeaders(token),
            body: jsonEncode({
              "rejection_reason": reason ?? "No reason provided",
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200)
        return {"success": true, "message": data["message"]};
      return {
        "success": false,
        "message": data["message"] ?? "Failed to decline",
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= DIRECT ORDER =================
  Future<Map<String, dynamic>> placeDirectOrder({
    required int listingId,
    required int quantityunit,
    required int deliveryAddressId,
    String? notes,
  }) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .post(
            Uri.parse("$_baseUrl/orders/direct"),
            headers: _authHeaders(token),
            body: jsonEncode({
              "listing_id": listingId,
              "quantity_unit": quantityunit,
              "delivery_address_id": deliveryAddressId,
              "notes": notes ?? "",
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) return {"success": true, "data": data};

      return {
        "success": false,
        "message": data["message"] ?? "Failed to place order",
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= VENDOR INVENTORY =================
  Future<Map<String, dynamic>> getVendorInventory({String? status}) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final uri = Uri.parse(
        '$_baseUrl/vendor/inventory',
      ).replace(queryParameters: status != null ? {'status': status} : null);

      final response = await http
          .get(uri, headers: _authHeaders(token))
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response"};

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": data["data"],
          "meta": data["meta"],
          "stock_summary": data["stock_summary"],
        };
      }
      return {
        "success": false,
        "message": data["message"] ?? "Failed",
        "statusCode": response.statusCode,
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  Future<Map<String, dynamic>> restockListing(
    int listingId,
    int addunit,
  ) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .patch(
            Uri.parse('$_baseUrl/vendor/inventory/$listingId/restock'),
            headers: _authHeaders(token),
            body: jsonEncode({"add_unit": addunit}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response"};

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data["message"],
          "new_stock_unit": data["new_stock_unit"],
        };
      }
      return {"success": false, "message": data["message"] ?? "Restock failed"};
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  Future<Map<String, dynamic>> updateListingPrices(
    int listingId, {
    required double pricePerunit,
    required double deliveryChargePerTon,
  }) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .patch(
            Uri.parse('$_baseUrl/vendor/inventory/$listingId/prices'),
            headers: _authHeaders(token),
            body: jsonEncode({
              "price_per_unit": pricePerunit,
              "delivery_charge_per_km": deliveryChargePerTon,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response"};

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data["message"],
          "price_per_unit": data["price_per_unit"],
          "delivery_charge_per_km": data["delivery_charge_per_km"],
        };
      }
      return {
        "success": false,
        "message": data["message"] ?? "Price update failed",
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  // ================= NOTIFICATIONS =================
  Future<Map<String, dynamic>> getNotifications() async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .get(
            Uri.parse('$_baseUrl/notifications'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response"};

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final list = (decoded is Map && decoded.containsKey('data'))
            ? decoded['data'] as List
            : (decoded is List ? decoded : []);
        return {"success": true, "data": list};
      }

      return {
        "success": false,
        "message": (decoded as Map)['message'] ?? 'Failed',
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      final token = await getToken();
      if (token == null) return;
      await http
          .post(
            Uri.parse('$_baseUrl/notifications/$notificationId/read'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead() async {
    try {
      final token = await getToken();
      if (token == null) return;
      await http
          .post(
            Uri.parse('$_baseUrl/notifications/read-all'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final token = await getToken();
      if (token == null) return 0;

      final response = await http
          .get(
            Uri.parse('$_baseUrl/notifications/unread-count'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['count'] as int?) ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  // ================= PAYMENT =================
  Future<Map<String, dynamic>> payNow(int orderItemId) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .post(
            Uri.parse('$_baseUrl/orders/$orderItemId/pay-now'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response"};

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data["message"] ?? "Payment successful!",
          "data": data["data"],
        };
      }

      return {"success": false, "message": data["message"] ?? "Payment failed"};
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  Future<Map<String, dynamic>> payLater(int orderItemId) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .post(
            Uri.parse('$_baseUrl/orders/$orderItemId/pay-later'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response"};

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": data["message"] ?? "Pay later set.",
          "data": data["data"],
        };
      }

      return {
        "success": false,
        "message": data["message"] ?? "Failed to set pay later",
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }

  Future<Map<String, dynamic>> getPaymentStatus(int orderItemId) async {
    try {
      final token = await getToken();
      if (token == null)
        return {"success": false, "message": "Not authenticated"};

      final response = await http
          .get(
            Uri.parse('$_baseUrl/orders/$orderItemId/payment-status'),
            headers: _authHeaders(token),
          )
          .timeout(const Duration(seconds: 10));

      if (response.body.isEmpty)
        return {"success": false, "message": "Empty response"};

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {"success": true, "data": data["data"]};
      }

      return {
        "success": false,
        "message": data["message"] ?? "Failed to get payment status",
      };
    } on TimeoutException {
      return {"success": false, "message": "Server timeout"};
    } catch (e) {
      return {"success": false, "message": "Network error"};
    }
  }
}
