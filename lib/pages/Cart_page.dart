import 'package:flutter/material.dart';
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
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Hardcoded demo items — replace with API after backend ready ──
  final List<Map<String, dynamic>> _cartItems = [
    {
      "name": "53 Grade OPC Cement",
      "seller": "Ram Cement Depot",
      "unit": "per bag",
      "price": 380.0,
      "deliveryPerKm": 6.0,
      "emoji": "🧱",
      "quantity": 10.0,
      "distance": 5.0,
    },
    {
      "name": "M-Sand (River Sand)",
      "seller": "Krishna Sand Works",
      "unit": "per ton",
      "price": 1200.0,
      "deliveryPerKm": 8.0,
      "emoji": "⛏️",
      "quantity": 3.0,
      "distance": 8.0,
    },
    {
      "name": "TMT Steel Bars",
      "seller": "Shree Steel Mart",
      "unit": "per kg",
      "price": 65.0,
      "deliveryPerKm": 10.0,
      "emoji": "🔩",
      "quantity": 50.0,
      "distance": 12.0,
    },
  ];

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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Computed totals ──────────────────────────────────────────
  double get _subtotal => _cartItems.fold(
    0,
    (sum, item) =>
        sum + (item["price"] as double) * (item["quantity"] as double),
  );

  double get _deliveryTotal => _cartItems.fold(
    0,
    (sum, item) =>
        sum + (item["deliveryPerKm"] as double) * (item["distance"] as double),
  );

  double get _grandTotal => _subtotal + _deliveryTotal;

  // ── Actions ──────────────────────────────────────────────────
  void _removeItem(int index) {
    setState(() => _cartItems.removeAt(index));
    _showSnack("Item removed", isSuccess: false, icon: Icons.delete_outline);
  }

  void _updateQuantity(int index, double newQty) {
    if (newQty <= 0) {
      _removeItem(index);
      return;
    }
    setState(() => _cartItems[index]["quantity"] = newQty);
  }

  void _checkout() {
    if (_cartItems.isEmpty) {
      _showSnack("Your cart is empty", isSuccess: false);
      return;
    }
    _showSnack(
      "Checkout coming after backend!",
      isSuccess: true,
      icon: Icons.check_circle_rounded,
    );
  }

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

  // ─────────────────────── BUILD ───────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _cartItems.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item count badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
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
                          ),
                          const SizedBox(height: 16),

                          // Cart item cards
                          ..._cartItems.asMap().entries.map(
                            (e) => _cartItemCard(e.key, e.value),
                          ),

                          const SizedBox(height: 20),
                          _buildSummaryCard(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomSheet: _cartItems.isEmpty ? null : _buildCheckoutBar(),
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
                          onPressed: () {
                            setState(() => _cartItems.clear());
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Clear All",
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
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

  // ── Empty state ───────────────────────────────────────────────
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

  // ── Cart item card ────────────────────────────────────────────
  Widget _cartItemCard(int index, Map<String, dynamic> item) {
    final qty = item["quantity"] as double;
    final dist = item["distance"] as double;
    final price = item["price"] as double;
    final charge = item["deliveryPerKm"] as double;
    final itemTotal = price * qty + charge * dist;
    final distCtrl = TextEditingController(text: dist.toStringAsFixed(0));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
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
          // ── Top row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emoji avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(
                      item["emoji"] as String,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
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
                            "₹${price.toStringAsFixed(0)} ${item["unit"]}",
                            AppColors.primaryMuted,
                            AppColors.primary,
                          ),
                          _chip(
                            "₹${charge.toStringAsFixed(0)}/km delivery",
                            AppColors.primaryMuted,
                            AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Remove button
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

          // ── Quantity stepper + Distance input ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                // Quantity stepper
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Quantity",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.bodyText,
                          fontWeight: FontWeight.w500,
                        ),
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
                // Distance input
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Distance (km)",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.bodyText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: distCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final d = double.tryParse(v);
                            if (d != null) {
                              setState(() => _cartItems[index]["distance"] = d);
                            }
                          },
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.titleText,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: "km",
                            hintStyle: const TextStyle(
                              color: AppColors.subtleText,
                              fontSize: 13,
                            ),
                            prefixIcon: const Icon(
                              Icons.swap_vert,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
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
                  "qty: ${qty % 1 == 0 ? qty.toInt() : qty}  ·  ${dist.toStringAsFixed(0)} km",
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

  // ── Order summary card ────────────────────────────────────────
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

  // ── Chip helper ───────────────────────────────────────────────
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
