import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../view_type.dart';

class CartPage extends StatefulWidget {
  final void Function(
    ViewType view, {
    Map<String, dynamic>? orderData,
    String? userType,
  })
  onSelectView;

  const CartPage({super.key, required this.onSelectView});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage>
    with SingleTickerProviderStateMixin {
  // ── Animation ────────────────────────────────────────────────
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Services & State ─────────────────────────────────────────
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  // ── Customer coordinates (from default address) ──────────────
  // Used for Haversine distance calculation against vendor warehouse
  double? _customerLat;
  double? _customerLng;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadCart();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // LOAD CART
  // Fetches cart items + customer default address in parallel.
  // Customer lat/lng is used to calculate distance to each vendor.
  // Vendor lat/lng comes from listing.seller.warehouse_lat/lng
  // which is populated from vendor's default address in CartItemResource.
  // ═══════════════════════════════════════════════════════════════
  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Fetch both simultaneously for better performance
      final results = await Future.wait([
        _api.getCart(),
        _api.getDefaultAddress(),
      ]);

      final cartResult = results[0];
      final addressResult = results[1];

      // Extract customer coordinates from their default address
      // These are set when user saves/updates their address via Nominatim geocoding
      if (addressResult["success"] == true) {
        final addr = addressResult["data"];
        _customerLat = double.tryParse(addr["latitude"]?.toString() ?? '');
        _customerLng = double.tryParse(addr["longitude"]?.toString() ?? '');
      }

      if (cartResult["success"] == true) {
        final List items = cartResult["data"] ?? [];

        setState(() {
          _cartItems = items.map<Map<String, dynamic>>((item) {
            final listing = item["listing"];
            final product = listing?["product"];
            final seller = listing?["seller"];

            // Vendor warehouse coordinates — populated from vendor's
            // default address in CartItemResource → seller.addresses
            final vendorLat = double.tryParse(
              seller?["warehouse_lat"]?.toString() ?? '',
            );
            final vendorLng = double.tryParse(
              seller?["warehouse_lng"]?.toString() ?? '',
            );

            // Auto-calculate real distance using Haversine formula
            // Falls back to 5.0 km if either party has no coordinates
            final distance =
                (_customerLat != null &&
                    _customerLng != null &&
                    vendorLat != null &&
                    vendorLng != null)
                ? _calculateDistance(
                    _customerLat!,
                    _customerLng!,
                    vendorLat,
                    vendorLng,
                  )
                : 5.0;

            return {
              // Cart item ID — used for update/delete API calls
              "id": item["id"],
              "listing_id": item["listing_id"],

              // quantity_bags is saved in DB when user adds to cart
              // from CustomerHomePage → api.addToCart(listingId, quantityBags)
              "quantity":
                  double.tryParse(item["quantity_bags"]?.toString() ?? "1") ??
                  1.0,

              // Product display info
              "name": product?["name"] ?? "Product",
              "seller": seller?["name"] ?? "Seller",
              "unit": product?["unit"] ?? "per bag",
              "image_url": product?["image_url"],

              // Pricing
              "price":
                  double.tryParse(
                    listing?["price_per_bag"]?.toString() ?? "0",
                  ) ??
                  0.0,
              "deliveryCharge":
                  double.tryParse(
                    listing?["delivery_charge_per_ton"]?.toString() ?? "0",
                  ) ??
                  0.0,

              // Stock limit — used to cap quantity stepper in UI
              "stock": listing?["available_stock_bags"] ?? 0,

              // Whether current quantity is still fulfillable
              // Backend calculates this live in CartItemResource
              "in_stock": item["in_stock"] ?? true,

              // Auto-calculated distance in km (Haversine)
              "distance": distance,
            };
          }).toList();

          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = cartResult["message"] ?? "Failed to load cart";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = "Something went wrong. Please try again.";
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HAVERSINE DISTANCE FORMULA
  // Calculates straight-line distance in km between two coordinates.
  // Used to estimate delivery distance between customer and vendor.
  // ═══════════════════════════════════════════════════════════════
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371.0; // Earth radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return double.parse((R * c).toStringAsFixed(1));
  }

  double _toRad(double deg) => deg * (pi / 180);

  // ═══════════════════════════════════════════════════════════════
  // COMPUTED TOTALS
  // Subtotal  = sum of (price × quantity) for all items
  // Delivery  = sum of (deliveryCharge × distance) for all items
  // Grand     = subtotal + delivery
  // ═══════════════════════════════════════════════════════════════
  double get _subtotal => _cartItems.fold(
    0,
    (sum, item) =>
        sum + (item["price"] as double) * (item["quantity"] as double),
  );

  double get _deliveryTotal => _cartItems.fold(
    0,
    (sum, item) =>
        sum + (item["deliveryCharge"] as double) * (item["distance"] as double),
  );

  double get _grandTotal => _subtotal + _deliveryTotal;

  // ═══════════════════════════════════════════════════════════════
  // REMOVE ITEM
  // Uses optimistic UI — removes from screen immediately,
  // rolls back if API call fails.
  // Calls DELETE /api/cart/{id}
  // ═══════════════════════════════════════════════════════════════
  Future<void> _removeItem(int index) async {
    final id = _cartItems[index]["id"] as int;
    final name = _cartItems[index]["name"] as String;
    final removed = _cartItems[index]; // save for rollback

    // Optimistic: remove from UI immediately
    setState(() => _cartItems.removeAt(index));

    final success = await _api.removeCartItem(id);

    if (!success) {
      // Rollback if API failed
      setState(() => _cartItems.insert(index, removed));
      _showSnack("Failed to remove item", isSuccess: false);
    } else {
      _showSnack("$name removed", isSuccess: false, icon: Icons.delete_outline);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UPDATE QUANTITY
  // Validates against stock limit before calling API.
  // Uses optimistic UI — updates immediately, rolls back on failure.
  // Removes item if quantity reaches 0.
  // Calls PUT /api/cart/{id} with new quantity_bags
  // ═══════════════════════════════════════════════════════════════
  Future<void> _updateQuantity(int index, double newQty) async {
    // Remove item if quantity drops to 0
    if (newQty <= 0) {
      _removeItem(index);
      return;
    }

    final id = _cartItems[index]["id"] as int;
    final oldQty = _cartItems[index]["quantity"] as double;
    final maxStock = _cartItems[index]["stock"] as int;

    // Cap at available stock
    if (newQty > maxStock) {
      _showSnack("Only $maxStock bags available", isSuccess: false);
      return;
    }

    // Optimistic: update UI immediately
    setState(() => _cartItems[index]["quantity"] = newQty);

    // Sync with backend
    final result = await _api.updateCartItem(id, newQty.toInt());

    if (result["success"] != true) {
      // Rollback on failure
      setState(() => _cartItems[index]["quantity"] = oldQty);
      _showSnack(result["message"] ?? "Update failed", isSuccess: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CLEAR CART
  // Calls DELETE /api/cart/clear — removes all items for this user.
  // ═══════════════════════════════════════════════════════════════
  Future<void> _clearCart() async {
    final success = await _api.clearCart();
    if (success) {
      setState(() => _cartItems.clear());
    } else {
      _showSnack("Failed to clear cart", isSuccess: false);
    }
  }

  // ── Checkout ─────────────────────────────────────────────────
  void _checkout() {
    if (_cartItems.isEmpty) {
      _showSnack("Your cart is empty", isSuccess: false);
      return;
    }
    // TODO: Navigate to order confirmation page
    // widget.onSelectView(ViewType.checkout, orderData: {...})
    _showSnack(
      "Proceeding to checkout...",
      isSuccess: true,
      icon: Icons.check_circle_rounded,
    );
  }

  // ── Snackbar helper ──────────────────────────────────────────
  void _showSnack(
    String msg, {
    required bool isSuccess,
    IconData icon = Icons.info_outline,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomSheet: (!_isLoading && !_hasError && _cartItems.isNotEmpty)
          ? _buildCheckoutBar()
          : null,
    );
  }

  // ── Body switcher ────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_hasError) return _buildErrorState();
    if (_cartItems.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadCart,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warn user if no default address — distance will be estimated
            if (_customerLat == null) _buildNoAddressBanner(),

            _buildCountBadge(),
            const SizedBox(height: 16),

            // Render each cart item card
            ..._cartItems.asMap().entries.map(
              (e) => _cartItemCard(e.key, e.value),
            ),

            const SizedBox(height: 20),
            _buildSummaryCard(),
          ],
        ),
      ),
    );
  }

  // ── Loading shimmer ──────────────────────────────────────────
  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (_, i) => _shimmerCard(),
    );
  }

  Widget _shimmerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _shimmerBox(52, 52, radius: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _shimmerBox(12, double.infinity),
                  const SizedBox(height: 8),
                  _shimmerBox(10, 140),
                  const SizedBox(height: 8),
                  _shimmerBox(10, 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double h, double w, {double radius = 8}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 0.9),
      duration: const Duration(milliseconds: 900),
      builder: (_, v, __) => Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: AppColors.border.withOpacity(v),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  // ── Error state ──────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Couldn't load cart",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.titleText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadCart,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Try Again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Your cart is empty",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.titleText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Browse the marketplace and add\nitems to get started",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.bodyText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => widget.onSelectView(ViewType.customerHome),
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text(
                "Browse Marketplace",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── No address warning banner ────────────────────────────────
  Widget _buildNoAddressBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_off_outlined,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "No default address set. Delivery distance is estimated.",
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
          GestureDetector(
            onTap: () => widget.onSelectView(ViewType.cutomerProfile),
            child: const Text(
              "Add",
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Item count badge ─────────────────────────────────────────
  Widget _buildCountBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "${_cartItems.length} item${_cartItems.length == 1 ? '' : 's'} in cart",
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(color: AppColors.primary),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Row(
            children: [
              _headerIconBtn(
                Icons.arrow_back_ios_new_rounded,
                () => widget.onSelectView(ViewType.customerHome),
              ),
              const Spacer(),
              const Text(
                "My Cart",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (_cartItems.isNotEmpty)
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text(
                        "Clear Cart",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      content: const Text("Remove all items from your cart?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _clearCart();
                          },
                          child: Text(
                            "Clear All",
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  child: _headerIconBtn(Icons.delete_sweep_outlined, () {}),
                )
              else
                const SizedBox(width: 38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  // ── Cart item card ───────────────────────────────────────────
  Widget _cartItemCard(int index, Map<String, dynamic> item) {
    final qty = item["quantity"] as double;
    final dist = item["distance"] as double;
    final price = item["price"] as double;
    final charge = item["deliveryCharge"] as double;
    final stock = item["stock"] as int;
    final inStock = item["in_stock"] as bool;

    // Item total = (price × qty) + (delivery charge × distance)
    final itemTotal = price * qty + charge * dist;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          // Red border if stock is insufficient for this quantity
          color: inStock ? AppColors.border : AppColors.error.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: image, name, seller, price, delete ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _productAvatar(item["image_url"]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item["name"] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.titleText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item["seller"] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.bodyText,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        children: [
                          _chip(
                            "₹${price.toStringAsFixed(0)} / ${item["unit"]}",
                            AppColors.primaryMuted,
                            AppColors.primary,
                          ),
                          _chip(
                            "₹${charge.toStringAsFixed(0)}/ton delivery",
                            AppColors.primaryMuted,
                            AppColors.primary,
                          ),
                        ],
                      ),
                      // Out of stock warning chip
                      if (!inStock) ...[
                        const SizedBox(height: 4),
                        _chip(
                          "Insufficient stock",
                          AppColors.error.withOpacity(0.1),
                          AppColors.error,
                        ),
                      ],
                    ],
                  ),
                ),
                // Delete button — calls DELETE /api/cart/{id}
                GestureDetector(
                  onTap: () => _removeItem(index),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.border.withOpacity(0.6)),

          // ── Quantity stepper + Distance display ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                // Quantity stepper
                // +/- calls PUT /api/cart/{id} with updated quantity_bags
                // This quantity is the SAME as what was set in CustomerHomePage
                // Both read/write to Cart.quantity_bags in the database
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Quantity",
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.bodyText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "(max $stock)",
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.bodyText.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            // Decrease
                            GestureDetector(
                              onTap: () => _updateQuantity(index, qty - 1),
                              child: Container(
                                width: 38,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryMuted,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(11),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.remove_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            // Current quantity value
                            Expanded(
                              child: Text(
                                qty % 1 == 0
                                    ? qty.toInt().toString()
                                    : qty.toStringAsFixed(1),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.titleText,
                                ),
                              ),
                            ),
                            // Increase
                            GestureDetector(
                              onTap: () => _updateQuantity(index, qty + 1),
                              child: Container(
                                width: 38,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(11),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Distance display — READ ONLY
                // Auto-calculated via Haversine using:
                //   customer lat/lng (from their default address)
                //   vendor lat/lng (from vendor's default address via CartItemResource)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Distance",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.bodyText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              // Green pin if real coords, orange if estimated
                              _customerLat != null
                                  ? Icons.location_on_rounded
                                  : Icons.location_off_outlined,
                              size: 14,
                              color: _customerLat != null
                                  ? AppColors.primary
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "${dist.toStringAsFixed(1)} km",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.titleText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_customerLat == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            "Estimated",
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.orange.withOpacity(0.8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Item total footer ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryMuted,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "qty: ${qty % 1 == 0 ? qty.toInt() : qty}  ·  ${dist.toStringAsFixed(1)} km",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.bodyText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "₹${itemTotal.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Product image with fallback ──────────────────────────────
  Widget _productAvatar(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          imageUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(),
        ),
      );
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: Text("🧱", style: TextStyle(fontSize: 26))),
    );
  }

  // ── Order summary card ───────────────────────────────────────
  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ORDER SUMMARY",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.bodyText,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          _summaryRow("Products subtotal", "₹${_subtotal.toStringAsFixed(2)}"),
          const SizedBox(height: 10),
          _summaryRow(
            "Delivery charges",
            "₹${_deliveryTotal.toStringAsFixed(2)}",
          ),

          // Disclaimer if delivery distance is estimated
          if (_customerLat == null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 12,
                  color: Colors.orange.withOpacity(0.8),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "Delivery is estimated (no default address set)",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border.withOpacity(0.7)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Grand Total",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.titleText,
                ),
              ),
              Text(
                "₹${_grandTotal.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Inclusive of all applicable charges",
            style: TextStyle(
              fontSize: 11,
              color: AppColors.bodyText.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.titleText,
          ),
        ),
      ],
    );
  }

  // ── Checkout bar ─────────────────────────────────────────────
  Widget _buildCheckoutBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Total",
                style: TextStyle(fontSize: 12, color: AppColors.bodyText),
              ),
              Text(
                "₹${_grandTotal.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.titleText,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _checkout,
                icon: const Icon(
                  Icons.shopping_cart_checkout_rounded,
                  size: 18,
                ),
                label: Text(
                  "Checkout  (${_cartItems.length} item${_cartItems.length == 1 ? '' : 's'})",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chip helper ──────────────────────────────────────────────
  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
