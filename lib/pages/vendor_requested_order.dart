// lib/pages/vendor_requested_order.dart
//
// STATUS FLOW
// ═══════════════════════════════════════════════════════════════════════════
// pending    → Vendor must Accept or Decline
// accepted   → Vendor accepted; customer choosing Pay Now / Pay Later
// processing → Payment confirmed OR vendor approved pay-later
// delivered  → Fully paid & delivered
// declined   → Vendor or system cancelled
//
// FILTERS: All | Pending | Accepted | Processing | Delivered | Declined
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../view_type.dart';
import '../widgets/web_scaffold.dart';

class VendorRequestedOrder extends StatefulWidget {
  final void Function(
    ViewType view, {
    Map<String, dynamic>? orderData,
    String? userType,
  })
  onSelectView;

  const VendorRequestedOrder({super.key, required this.onSelectView});

  @override
  State<VendorRequestedOrder> createState() => _VendorRequestedOrderState();
}

class _VendorRequestedOrderState extends State<VendorRequestedOrder>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMsg = '';

  final Map<int, String> _loadingStates = {};

  double? _vendorLat;
  double? _vendorLng;

  int _tab = 0;
  static const _tabs = [
    "All",
    "Pending",
    "Accepted",
    "Processing",
    "Delivered",
    "Declined",
  ];
  static const _tabStatuses = [
    "",
    "pending",
    "accepted",
    "processing",
    "delivered",
    "declined",
  ];

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

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
    _loadVendorAddressAndOrders();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadVendorAddressAndOrders() async {
    final defaultAddr = await _api.getDefaultAddress();
    if (defaultAddr["success"] == true) {
      final data = defaultAddr["data"] as Map<String, dynamic>? ?? {};
      _vendorLat = double.tryParse(data["latitude"]?.toString() ?? "");
      _vendorLng = double.tryParse(data["longitude"]?.toString() ?? "");
    }
    if (_vendorLat == null || _vendorLng == null) {
      final profile = await _api.getProfile();
      if (profile["success"] == true) {
        final user = profile["user"] as Map<String, dynamic>? ?? {};
        _vendorLat = double.tryParse(user["warehouse_lat"]?.toString() ?? "");
        _vendorLng = double.tryParse(user["warehouse_lng"]?.toString() ?? "");
      }
    }
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final result = await _api.getVendorOrders();
    if (result["success"] == true) {
      final List raw = result["data"] ?? [];
      setState(() {
        _entries = raw
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMsg = result["message"] ?? "Failed to load orders";
      });
    }
  }

  Future<void> _accept(int orderItemId) async {
    setState(() => _loadingStates[orderItemId] = 'accepting');
    final result = await _api.acceptVendorOrder(orderItemId);
    setState(() => _loadingStates.remove(orderItemId));
    if (result["success"] == true) {
      _snack("Order accepted successfully!", isSuccess: true);
      _loadOrders();
    } else {
      _snack(result["message"] ?? "Failed to accept order", isSuccess: false);
    }
  }

  Future<void> _decline(int orderItemId) async {
    final reason = await _showDeclineDialog();
    if (reason == null) return;
    setState(() => _loadingStates[orderItemId] = 'declining');
    final result = await _api.declineVendorOrder(orderItemId, reason: reason);
    setState(() => _loadingStates.remove(orderItemId));
    if (result["success"] == true) {
      _snack("Order declined.", isSuccess: false);
      _loadOrders();
    } else {
      _snack(result["message"] ?? "Failed to decline order", isSuccess: false);
    }
  }

  Future<String?> _showDeclineDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Reason for Declining",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Provide a reason so the customer understands.",
              style: TextStyle(fontSize: 13, color: AppColors.bodyText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "e.g. Out of stock, not delivering to this area...",
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.subtleText,
                ),
                filled: true,
                fillColor: AppColors.background,
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final r = controller.text.trim();
              Navigator.pop(context, r.isEmpty ? "No reason provided" : r);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Decline"),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: Colors.white,
              size: 18,
            ),
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

  int get _pendingCount => _entries
      .where(
        (e) =>
            ((e["order_item"] ?? {})["status"] ?? "")
                .toString()
                .toLowerCase() ==
            "pending",
      )
      .length;

  String _displayDistance(Map<String, dynamic> entry) {
    final item = entry["order_item"] as Map<String, dynamic>? ?? {};
    final stored = double.tryParse(item["distance_km"]?.toString() ?? "");
    if (stored != null && stored > 0) return "${stored.toStringAsFixed(1)} km";
    final address = entry["delivery_address"] as Map<String, dynamic>?;
    final custLat = double.tryParse(address?["latitude"]?.toString() ?? "");
    final custLng = double.tryParse(address?["longitude"]?.toString() ?? "");
    if (_vendorLat != null &&
        _vendorLng != null &&
        custLat != null &&
        custLng != null) {
      return "${_haversine(_vendorLat!, _vendorLng!, custLat, custLng).toStringAsFixed(1)} km";
    }
    return "—";
  }

  List<Map<String, dynamic>> get _filteredEntries {
    if (_tab == 0) return _entries;
    final target = _tabStatuses[_tab];
    return _entries
        .where(
          (e) =>
              ((e["order_item"] ?? {})["status"] ?? "")
                  .toString()
                  .toLowerCase() ==
              target,
        )
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COLOR HELPERS — all 5 statuses mapped
  // ═══════════════════════════════════════════════════════════════════════════

  Color _textColor(String s) {
    switch (s) {
      case 'accepted':
        return AppColors.success;
      case 'declined':
        return AppColors.error;
      case 'processing':
        return const Color(0xFF0284C7);
      case 'delivered':
        return AppColors.success;
      default:
        return Colors.orange;
    }
  }

  Color _borderColor(String s) {
    switch (s) {
      case 'accepted':
        return AppColors.success.withOpacity(0.3);
      case 'declined':
        return AppColors.error.withOpacity(0.3);
      case 'processing':
        return const Color(0xFF0284C7).withOpacity(0.3);
      case 'delivered':
        return AppColors.success.withOpacity(0.3);
      default:
        return AppColors.border;
    }
  }

  Color _bgColor(String s) {
    switch (s) {
      case 'pending':
        return const Color(0xFFFFF3E0);
      case 'accepted':
        return const Color(0xFFF0FAF0);
      case 'declined':
        return AppColors.error.withOpacity(0.08);
      case 'processing':
        return const Color(0xFFE0F2FE);
      case 'delivered':
        return const Color(0xFFE8F5E9);
      default:
        return const Color(0xFFFFF3E0);
    }
  }

  Color _tabAccentColor(int i) {
    switch (i) {
      case 1:
        return Colors.orange;
      case 2:
        return AppColors.success;
      case 3:
        return const Color(0xFF0284C7);
      case 4:
        return AppColors.success;
      case 5:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return WebScaffold(
      isVendor: true,
      onSelectView: widget.onSelectView,
      selectedIndex: 1,
      body: Scaffold(
        backgroundColor: AppColors.background,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildFilters(),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: _buildBody(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    color: Colors.white,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => widget.onSelectView(ViewType.vendorHome),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppColors.titleText,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Requested Orders",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.titleText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (!_isLoading && !_hasError)
                    Text(
                      "$_pendingCount pending order${_pendingCount == 1 ? '' : 's'}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.bodyText,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _loadOrders,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildFilters() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final active = _tab == i;
          final accentColor = _tabAccentColor(i);
          int? count;
          if (i > 0) {
            final target = _tabStatuses[i];
            count = _entries
                .where(
                  (e) =>
                      ((e["order_item"] ?? {})["status"] ?? "")
                          .toString()
                          .toLowerCase() ==
                      target,
                )
                .length;
          }
          return GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? accentColor : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? accentColor : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tabs[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.titleText,
                    ),
                  ),
                  if (count != null && count > 0 && !active) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    ),
  );

  Widget _buildBody() {
    if (_isLoading) return _buildShimmer();
    if (_hasError) return _buildError();
    if (_filteredEntries.isEmpty) return _buildEmpty();
    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          if (!isWide) {
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: _filteredEntries.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildCard(_filteredEntries[i]),
              ),
            );
          }
          final items = _filteredEntries;
          final rowCount = (items.length / 2).ceil();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: rowCount,
            itemBuilder: (_, rowIndex) {
              final l = rowIndex * 2;
              final r = l + 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildCard(items[l])),
                      const SizedBox(width: 16),
                      Expanded(
                        child: r < items.length
                            ? _buildCard(items[r])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> entry) {
    final item = (entry["order_item"] as Map<String, dynamic>? ?? {});
    final customer = (entry["customer"] as Map<String, dynamic>? ?? {});
    final address = (entry["delivery_address"] as Map<String, dynamic>?);
    final product = (item["product"] as Map<String, dynamic>? ?? {});

    final int itemId = item["id"] ?? 0;
    final String status = (item["status"] ?? "pending")
        .toString()
        .toLowerCase();
    final String payStatus = (item["payment_status"] ?? "unpaid").toString();
    final int orderId = entry["order_id"] ?? 0;
    final String customerName = customer["name"] ?? "Customer";
    final String customerPhone = customer["phone"] ?? "";
    final String productName = product["name"] ?? "Product";
    final int qty = item["quantity_unit"] ?? 0;
    final double subtotal =
        double.tryParse(item["subtotal"]?.toString() ?? "0") ?? 0.0;
    final double delivery =
        double.tryParse(item["delivery_charge"]?.toString() ?? "0") ?? 0.0;
    final double total = subtotal + delivery;
    final String rejReason = item["rejection_reason"] as String? ?? '';

    final String deliveryAddr = address != null
        ? "${address["address_line_1"] ?? ""}, ${address["city"] ?? ""}, ${address["state"] ?? ""} - ${address["pincode"] ?? ""}"
        : "Address not provided";

    final bool isPending = status == "pending";
    final bool isAccepting = _loadingStates[itemId] == 'accepting';
    final bool isDeclining = _loadingStates[itemId] == 'declining';
    final bool isBusy = isAccepting || isDeclining;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(status)),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Order #$orderId",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.titleText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              customerName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.bodyText,
                              ),
                            ),
                          ),
                          if (customerPhone.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: AppColors.subtleText,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.phone_outlined,
                              size: 11,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                customerPhone,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(status),
              ],
            ),
          ),

          // ── Payment badge (non-pending only) ──────────────────────────────
          if (!isPending)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: _paymentStatusBadge(payStatus),
            ),

          Divider(height: 1, color: AppColors.border.withOpacity(0.5)),

          // ── Product block ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primaryMuted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.titleText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _chip(
                          "Quantity",
                          "$qty unit",
                          Icons.shopping_bag_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _chip(
                          "Distance",
                          _displayDistance(entry),
                          Icons.route_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Delivery address ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Delivery Address",
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.bodyText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          deliveryAddr,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.titleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Total ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Amount",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                      if (delivery > 0)
                        Text(
                          "₹${subtotal.toStringAsFixed(0)} + ₹${delivery.toStringAsFixed(0)} delivery",
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.bodyText,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    "₹${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Action area ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: isPending
                ? _acceptDeclineButtons(
                    itemId,
                    isAccepting,
                    isDeclining,
                    isBusy,
                  )
                : _statusBanner(status, payStatus, rejReason),
          ),
        ],
      ),
    );
  }

  Widget _acceptDeclineButtons(
    int itemId,
    bool isAccepting,
    bool isDeclining,
    bool isBusy,
  ) => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isBusy ? null : () => _accept(itemId),
            icon: isAccepting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(
              isAccepting ? "Accepting..." : "Accept Order",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isBusy ? null : () => _decline(itemId),
            icon: isDeclining
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.close_rounded, size: 18),
            label: Text(
              isDeclining ? "Declining..." : "Reject",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _statusBanner(String status, String payStatus, String rejReason) {
    String emoji, text;
    Color fg, bg;

    switch (status) {
      case 'accepted':
        emoji = "✅";
        if (payStatus == 'pay_later') {
          text =
              "Accepted — pay-later request is pending your decision in Notifications";
        } else {
          text = "Accepted — awaiting customer payment";
        }
        fg = AppColors.success;
        bg = const Color(0xFFF0FAF0);
        break;

      case 'processing':
        emoji = "⚙️";
        if (payStatus == 'pay_later') {
          text =
              "Processing — pay-later approved, customer will pay by due date";
        } else {
          text = "Processing — payment received, order in progress";
        }
        fg = const Color(0xFF0284C7);
        bg = const Color(0xFFE0F2FE);
        break;

      case 'delivered':
        emoji = "🎉";
        text = "Delivered & payment confirmed!";
        fg = AppColors.success;
        bg = const Color(0xFFE8F5E9);
        break;

      case 'declined':
        emoji = "❌";
        text = rejReason.isNotEmpty ? "Declined: $rejReason" : "Order declined";
        fg = AppColors.error;
        bg = AppColors.error.withOpacity(0.08);
        break;

      default:
        emoji = "⏳";
        text = "Status: $status";
        fg = Colors.orange;
        bg = const Color(0xFFFFF3E0);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentStatusBadge(String payStatus) {
    String label;
    Color fg, bg;
    switch (payStatus) {
      case 'paid':
        label = "💰 Paid";
        fg = AppColors.success;
        bg = const Color(0xFFE8F5E9);
        break;
      case 'pay_later':
        label = "⏰ Pay Later";
        fg = const Color(0xFFB45309);
        bg = const Color(0xFFFFF8E1);
        break;
      default:
        label = "Unpaid";
        fg = AppColors.bodyText;
        bg = AppColors.surfaceAlt;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _chip(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.bodyText),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.titleText,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _statusBadge(String status) {
    String label;
    switch (status) {
      case 'accepted':
        label = 'Accepted';
        break;
      case 'declined':
        label = 'Declined';
        break;
      case 'processing':
        label = 'Processing';
        break;
      case 'delivered':
        label = 'Delivered';
        break;
      default:
        label = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bgColor(status),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _textColor(status).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _textColor(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textColor(status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 3,
    itemBuilder: (_, __) => Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_sh(14, 160), _sh(14, 70, r: 20)],
            ),
            const SizedBox(height: 6),
            _sh(10, 100),
            const SizedBox(height: 20),
            _sh(90, double.infinity, r: 12),
            const SizedBox(height: 10),
            _sh(50, double.infinity, r: 12),
            const SizedBox(height: 10),
            _sh(50, double.infinity, r: 12),
            const SizedBox(height: 16),
            _sh(50, double.infinity, r: 13),
          ],
        ),
      ),
    ),
  );

  Widget _sh(double h, double w, {double r = 8}) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.3, end: 0.8),
        duration: const Duration(milliseconds: 900),
        builder: (_, v, __) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: AppColors.border.withOpacity(v),
            borderRadius: BorderRadius.circular(r),
          ),
        ),
      );

  Widget _buildError() => Center(
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
            "Couldn't load orders",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.titleText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMsg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Try Again"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
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
            Icons.inbox_outlined,
            size: 48,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _tab == 0
              ? "No orders yet"
              : "No ${_tabs[_tab].toLowerCase()} orders",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.titleText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _tab == 0
              ? "When customers place orders\nthey will appear here"
              : "Switch to 'All' to see every order",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.bodyText,
            height: 1.5,
          ),
        ),
      ],
    ),
  );
}
